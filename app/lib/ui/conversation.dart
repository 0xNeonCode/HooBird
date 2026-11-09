// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio_prep.dart';
import '../media_prep.dart';
import '../security_label.dart';
import '../session.dart';
import '../voice_io.dart';
import 'shell.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.room, required this.controller});

  final Room room;
  final HoobirdController controller;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _input = TextEditingController();
  final _anchors = <String, GlobalKey>{};
  final _images = <String, Future<Uint8List?>>{};
  final _selected = <String>{};
  final _search = TextEditingController();
  Timeline? _timeline;
  String? _error;
  Event? _reply;
  Event? _editing;
  var _sending = false;
  var _recording = false;
  var _locked = false;
  var _elapsedMs = 0;
  Uint8List? _preview;
  String? _previewPath;
  var _previewMs = 0;
  String? _playingPath;
  var _playing = false;
  var _playPos = 0;
  var _playDur = 0;
  var _speed = 1.0;
  var _wasTyping = false;
  var _markedEventId = '';
  var _searching = false;
  var _finishing = false;
  double _dragDy = 0;
  StreamSubscription<Map<String, Object?>>? _voiceEvents;

  @override
  void initState() {
    super.initState();
    _open();
    _input.addListener(_onComposerChanged);
    if (VoiceIo.supported) {
      _voiceEvents = VoiceIo.events.listen(_onVoiceEvent);
    }
  }

  Future<void> _open() async {
    final timeline = await widget.room.getTimeline(
      onUpdate: () {
        if (mounted) {
          setState(() {});
          _markRead();
        }
      },
    );
    if (mounted) {
      setState(() => _timeline = timeline);
      _markRead();
    }
  }

  @override
  void dispose() {
    _voiceEvents?.cancel();
    if (_recording) {
      VoiceIo.stop().catchError((_) => 0);
    }
    if (VoiceIo.supported) {
      VoiceIo.stopPlayback().catchError((_) {});
    }
    if (_wasTyping) {
      widget.room.setTyping(false);
    }
    _timeline?.cancelSubscriptions();
    _input.dispose();
    _search.dispose();
    final path = _previewPath;
    if (path != null) {
      File(path).delete().catchError((_) => File(path));
    }
    super.dispose();
  }

  void _onComposerChanged() {
    if (!widget.controller.sendTyping) {
      if (_wasTyping) {
        _wasTyping = false;
        widget.room.setTyping(false);
      }
      return;
    }
    final typing = _input.text.trim().isNotEmpty && _editing == null && !_recording && _preview == null;
    if (typing == _wasTyping) return;
    _wasTyping = typing;
    widget.room.setTyping(typing);
  }

  void _onVoiceEvent(Map<String, Object?> event) {
    if (!mounted) return;
    if (event['kind'] == 'recording' && _recording) {
      final elapsed = event['elapsedMs'];
      if (elapsed is int) {
        setState(() => _elapsedMs = elapsed);
        if (elapsed >= 180000) _finishRecording();
      }
    }
    if (event['kind'] == 'playback') {
      setState(() {
        if (event['positionMs'] is int) _playPos = event['positionMs'] as int;
        if (event['durationMs'] is int) _playDur = event['durationMs'] as int;
        if (event['completed'] == true) _playing = false;
      });
    }
  }

  Future<void> _markRead() async {
    final latest = _messages.isEmpty ? null : _messages.last;
    if (latest == null || latest.eventId == _markedEventId) return;
    _markedEventId = latest.eventId;
    try {
      await _timeline?.setReadMarker(
        eventId: latest.eventId,
        public: widget.controller.sendReceipts,
      );
    } catch (_) {}
  }

  GlobalKey _anchor(String eventId) => _anchors.putIfAbsent(eventId, GlobalKey.new);

  Future<Uint8List?> _imageBytes(Event event) {
    return _images.putIfAbsent(event.eventId, () async {
      try {
        final file = await event.downloadAndDecryptAttachment();
        return file.bytes;
      } catch (_) {
        return null;
      }
    });
  }

  List<Event> get _messages {
    final timeline = _timeline;
    if (timeline == null) return const [];
    return timeline.events
        .where((event) {
          if (event.relationshipType == RelationshipTypes.edit) return false;
          if (event.type == EventTypes.Reaction) return false;
          return event.type == EventTypes.Message || event.type == EventTypes.Encrypted;
        })
        .toList()
        .reversed
        .toList();
  }

  Event? _eventById(String eventId) {
    for (final event in _timeline?.events ?? const <Event>[]) {
      if (event.eventId == eventId) return event;
    }
    return null;
  }

  Future<void> _sendImage() async {
    if (_sending || _editing != null || _recording || _preview != null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final raw = await File(picked.path).readAsBytes();
      final stripped = stripJpegMetadata(Uint8List.fromList(raw));
      final caption = _input.text.trim();
      await widget.room.sendFileEvent(
        MatrixImageFile(bytes: stripped, name: 'bild.jpg', mimeType: 'image/jpeg'),
        extraContent: caption.isEmpty ? null : {'body': caption},
        inReplyTo: _reply,
      );
      _input.clear();
      _reply = null;
    } on JpegPrepException catch (exc) {
      _error = exc.message;
    } catch (exc) {
      _error = 'Bild abgelehnt: $exc';
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final editing = _editing;
      if (editing != null) {
        await widget.room.sendTextEvent(text, editEventId: editing.eventId);
      } else {
        await widget.room.sendTextEvent(text, inReplyTo: _reply);
      }
      _input.clear();
      _reply = null;
      _editing = null;
    } catch (exc) {
      _error = 'Senden abgelehnt: $exc';
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _react(Event event, String emoji) async {
    final room = widget.room;
    final encryption = room.client.encryption;
    if (!room.encrypted || encryption == null || !encryption.enabled) {
      if (mounted) {
        setState(() => _error = 'Reaktionen gibt es nur im verschlüsselten Chat.');
      }
      return;
    }
    try {
      // The SDK leaves reaction-only events unencrypted and copies m.relates_to
      // onto the wire event, which would show the emoji to the server. The
      // homeserver rejects that plaintext event. Encrypt the whole relation
      // with the room's existing Megolm session and send m.room.encrypted
      // with no cleartext relation.
      final payload = await _encryptReaction(room, {
        'm.relates_to': {
          'rel_type': RelationshipTypes.reaction,
          'event_id': event.eventId,
          'key': emoji,
        },
      });
      await room.client.sendMessage(
        room.id,
        EventTypes.Encrypted,
        room.client.generateUniqueTransactionId(),
        payload,
      );
    } catch (exc) {
      if (mounted) setState(() => _error = 'Reaktion abgelehnt: $exc');
    }
  }

  Future<void> _redact(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nachricht löschen'),
        content: const Text(
          'Die Löschung geht an die Teilnehmenden, deren Client sie annimmt. Eine schon gesehene oder abfotografierte Kopie kommt dadurch nicht zurück.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await event.redactEvent();
    } catch (exc) {
      if (mounted) setState(() => _error = 'Löschen abgelehnt: $exc');
    }
  }

  String _clock(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  Future<void> _explainMic(String status) async {
    final blocked = status == 'blocked';
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mikrofon'),
        content: Text(
          blocked
              ? 'Das Mikrofon ist für HooBird gesperrt. Ohne diese Berechtigung kann keine Sprachnachricht aufgenommen werden. In den Einstellungen des Systems kann sie erlaubt werden.'
              : 'HooBird braucht das Mikrofon nur für die Aufnahme, die du selbst startest. Die Aufnahme wird verschlüsselt gesendet. Ohne Erlaubnis passiert nichts.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(blocked ? 'Einstellungen' : 'Erneut fragen'),
          ),
        ],
      ),
    );
    if (open != true) return;
    if (blocked) {
      await VoiceIo.openSettings();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!VoiceIo.supported || _sending || _recording || _preview != null || _editing != null) return;
    try {
      final status = await VoiceIo.permission();
      if (!mounted) return;
      if (status != 'granted') {
        await _explainMic(status);
        return;
      }
      final directory = await getTemporaryDirectory();
      final path = p.join(directory.path, 'hoobird-voice.m4a');
      final previous = File(path);
      if (previous.existsSync()) previous.deleteSync();
      await VoiceIo.start(path);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _locked = false;
        _elapsedMs = 0;
        _dragDy = 0;
        _error = null;
        _preview = null;
        _previewPath = path;
      });
    } on PlatformException catch (exc) {
      if (mounted) setState(() => _error = 'Aufnahme nicht gestartet: ${exc.message ?? exc.code}');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      if (_recording) await VoiceIo.stop();
    } catch (_) {}
    await VoiceIo.stopPlayback();
    final path = _previewPath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _locked = false;
      _preview = null;
      _previewPath = null;
      _previewMs = 0;
      _playing = false;
    });
  }

  Future<void> _finishRecording() async {
    if (!_recording || _finishing) return;
    _finishing = true;
    final path = _previewPath;
    try {
      final elapsed = await VoiceIo.stop();
      if (path == null) return;
      final raw = await File(path).readAsBytes();
      final stripped = stripMp4Metadata(raw);
      await File(path).writeAsBytes(stripped, flush: true);
      if (!mounted) return;
      setState(() {
        _recording = false;
        _locked = false;
        _preview = stripped;
        _previewMs = elapsed;
        _error = null;
      });
    } on AudioPrepException catch (exc) {
      if (path != null && File(path).existsSync()) File(path).deleteSync();
      if (mounted) {
        setState(() {
          _recording = false;
          _preview = null;
          _previewPath = null;
          _error = exc.message;
        });
      }
    } on PlatformException catch (exc) {
      if (path != null && File(path).existsSync()) File(path).deleteSync();
      if (mounted) {
        final message = exc.code == 'record_stop_failed'
            ? 'Die Aufnahme ist zu kurz und wurde verworfen.'
            : 'Aufnahme abgebrochen. ${exc.message ?? exc.code}';
        setState(() {
          _recording = false;
          _preview = null;
          _previewPath = null;
          _error = message;
        });
      }
    } finally {
      _finishing = false;
    }
  }

  Future<void> _sendVoice() async {
    final bytes = _preview;
    final path = _previewPath;
    if (bytes == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await VoiceIo.stopPlayback();
      await widget.room.sendFileEvent(
        MatrixAudioFile(
          bytes: bytes,
          name: 'sprachnachricht.m4a',
          mimeType: 'audio/mp4',
          duration: _previewMs,
        ),
        extraContent: {'org.matrix.msc3245.voice': <String, dynamic>{}},
        inReplyTo: _reply,
      );
      if (path != null && File(path).existsSync()) File(path).deleteSync();
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewPath = null;
        _previewMs = 0;
        _reply = null;
        _playing = false;
      });
    } catch (exc) {
      if (mounted) setState(() => _error = 'Sprachnachricht abgelehnt: $exc');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _togglePlay(String path) async {
    try {
      if (_playing && _playingPath == path) {
        await VoiceIo.pause();
        if (mounted) setState(() => _playing = false);
        return;
      }
      if (_playingPath == path && !_playing) {
        await VoiceIo.resume();
        if (mounted) setState(() => _playing = true);
        return;
      }
      final duration = await VoiceIo.play(path, _speed);
      if (!mounted) return;
      setState(() {
        _playingPath = path;
        _playing = true;
        _playDur = duration;
        _playPos = 0;
      });
    } on PlatformException catch (exc) {
      if (mounted) setState(() => _error = 'Wiedergabe nicht möglich: ${exc.message ?? exc.code}');
    }
  }

  Future<void> _cycleSpeed() async {
    final next = _speed == 1 ? 1.5 : _speed == 1.5 ? 2.0 : 1.0;
    setState(() => _speed = next);
    if (_playing) {
      try {
        await VoiceIo.speed(next);
      } on PlatformException catch (exc) {
        if (mounted) setState(() => _error = 'Tempo nicht geändert: ${exc.message ?? exc.code}');
      }
    }
  }

  Future<String?> _materialize(Event event) async {
    final file = await event.downloadAndDecryptAttachment();
    final directory = await getTemporaryDirectory();
    final path = p.join(directory.path, 'hoobird-play-${event.eventId.hashCode}.m4a');
    await File(path).writeAsBytes(file.bytes, flush: true);
    return path;
  }

  Future<void> _pin(Event event) async {
    final current = widget.room.pinnedEventIds.toList();
    if (current.contains(event.eventId)) {
      current.remove(event.eventId);
    } else {
      current.add(event.eventId);
    }
    try {
      await widget.room.setPinnedEvents(current);
    } catch (exc) {
      if (mounted) setState(() => _error = 'Anheften abgelehnt: $exc');
    }
  }

  Future<void> _forward() async {
    final client = widget.room.client;
    final targets = client.rooms
        .where((room) => room.membership == Membership.join && room.id != widget.room.id && room.encrypted)
        .toList();
    if (targets.isEmpty || _selected.isEmpty) {
      setState(() => _error = 'Kein anderer verschlüsselter Raum für die Weiterleitung.');
      return;
    }
    final target = await showModalBottomSheet<Room>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Als neue verschlüsselte Nachricht senden'),
              subtitle: Text('Das ist keine Kopie des Originalereignisses. Bilder und Sprachnachrichten bleiben hier.'),
            ),
            for (final room in targets)
              ListTile(
                title: Text(room.getLocalizedDisplayname()),
                onTap: () => Navigator.pop(context, room),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    final texts = <String>[];
    var skipped = 0;
    for (final id in _selected) {
      final event = _eventById(id);
      if (event == null) continue;
      final display = _timeline == null ? event : event.getDisplayEvent(_timeline!);
      if (display.messageType == MessageTypes.Text) {
        texts.add(display.body);
      } else {
        skipped += 1;
      }
    }
    try {
      for (final text in texts) {
        await target.sendTextEvent('Weitergeleitet: $text');
      }
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _error = skipped == 0 ? null : '$skipped Nachrichten ohne Text wurden nicht weitergeleitet.';
      });
    } catch (exc) {
      if (mounted) setState(() => _error = 'Weiterleiten abgelehnt: $exc');
    }
  }

  void _jump(String eventId) {
    final context = _anchor(eventId).currentContext;
    if (context == null) {
      setState(() => _error = 'Die ursprüngliche Nachricht ist in diesem Ausschnitt nicht geladen.');
      return;
    }
    Scrollable.ensureVisible(context, alignment: 0.3, duration: const Duration(milliseconds: 200));
  }

  Future<void> _actions(Event event) async {
    if (event.redacted) return;
    final mine = event.senderId == widget.room.client.userID;
    final display = _timeline == null ? event : event.getDisplayEvent(_timeline!);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Antworten'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _reply = event;
                  _editing = null;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji in const ['👍', '❤️', '😂'])
                  IconButton(
                    tooltip: 'Reagieren mit $emoji',
                    onPressed: () {
                      Navigator.pop(context);
                      _react(event, emoji);
                    },
                    icon: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
              ],
            ),
            if (mine && display.messageType == MessageTypes.Text)
              ListTile(
                title: const Text('Bearbeiten'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editing = event;
                    _reply = null;
                    _input.text = display.body;
                  });
                },
              ),
            ListTile(
              title: Text(
                widget.room.pinnedEventIds.contains(event.eventId) ? 'Nicht mehr anheften' : 'Anheften',
              ),
              onTap: () {
                Navigator.pop(context);
                _pin(event);
              },
            ),
            ListTile(
              title: const Text('Auswählen'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selected.add(event.eventId));
              },
            ),
            if (mine)
              ListTile(
                title: const Text('Löschen'),
                onTap: () {
                  Navigator.pop(context);
                  _redact(event);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final verified = identityVerified(room.client, room);
    final label = securityLabel(encrypted: room.encrypted, identityVerified: verified);
    final scheme = Theme.of(context).colorScheme;
    final timeline = _timeline;
    final query = _search.text.trim().toLowerCase();
    final events = query.isEmpty
        ? _messages
        : _messages.where((event) {
            final display = timeline == null ? event : event.getDisplayEvent(timeline);
            return display.body.toLowerCase().contains(query);
          }).toList();
    final typing = room.typingUsers.where((user) => user.id != room.client.userID).isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.getLocalizedDisplayname()),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: 'Auswahl weiterleiten',
              onPressed: _forward,
              icon: const Icon(Icons.forward),
            ),
          IconButton(
            tooltip: 'In geladenen Nachrichten suchen',
            onPressed: () => setState(() => _searching = !_searching),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!room.encrypted)
            MaterialBanner(
              content: const Text('Dieser Raum ist nicht verschlüsselt. HooBird erwartet Megolm.'),
              actions: [
                TextButton(onPressed: () {}, child: const Text('Hinweis')),
              ],
            ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Geladene Nachrichten',
                  helperText: 'Nur der bereits geladene Ausschnitt. Ältere verschlüsselte Nachrichten stehen hier nicht.',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          Expanded(
            child: timeline == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final original = events[index];
                      final event = original.getDisplayEvent(timeline);
                      final mine = original.senderId == room.client.userID;
                      final undecrypted =
                          event.type == EventTypes.Encrypted || event.messageType == MessageTypes.BadEncrypted;
                      final edited = original.hasAggregatedEvents(timeline, RelationshipTypes.edit);
                      final replyId = event.inReplyToEventId();
                      final reply = replyId == null ? null : _eventById(replyId);
                      final reactions = original
                          .aggregatedEvents(timeline, RelationshipTypes.reaction)
                          .where((reaction) => reaction.status != EventStatus.error);
                      return Align(
                        key: _anchor(original.eventId),
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _actions(original),
                          onTap: _selected.isEmpty
                              ? null
                              : () => setState(() {
                                  if (!_selected.add(original.eventId)) _selected.remove(original.eventId);
                                }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              color: mine ? scheme.primary.withValues(alpha: 0.22) : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (replyId != null)
                                  TextButton(
                                    onPressed: () => _jump(replyId),
                                    child: Text(
                                      reply == null
                                          ? 'Antwort auf eine Nachricht außerhalb dieses Ausschnitts'
                                          : 'Antwort auf: ${_visibleText(reply.getDisplayEvent(timeline))}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (_selected.contains(original.eventId))
                                  const Text('Ausgewählt'),
                                if (room.pinnedEventIds.contains(original.eventId) && !original.redacted)
                                  Text('Angeheftet', style: Theme.of(context).textTheme.labelSmall),
                                if (original.redacted)
                                  const Text(
                                    'Gelöscht. Eine schon gesehene oder abfotografierte Kopie bleibt bei den anderen.',
                                  )
                                else if (undecrypted)
                                  const Text('Verschlüsselt · Schlüssel auf diesem Gerät nicht vorhanden')
                                else if (event.messageType == MessageTypes.Image)
                                  _ImageBubble(bytes: _imageBytes(event), caption: event.body)
                                else if (event.messageType == MessageTypes.Audio)
                                  _AudioBubble(
                                    label: _clock(event.infoMap.tryGet<int>('duration') ?? 0),
                                    playing: _playing && _playingPath != null && _playingPath!.contains('${event.eventId.hashCode}'),
                                    progress: _playingPath != null && _playingPath!.contains('${event.eventId.hashCode}')
                                        ? '${_clock(_playPos)} / ${_clock(_playDur)} · ${_speed}x'
                                        : 'Tippen zum Abspielen · ${_speed}x',
                                    onPlay: () async {
                                      final path = await _materialize(event);
                                      if (path != null) await _togglePlay(path);
                                    },
                                    onSpeed: _cycleSpeed,
                                  )
                                else
                                  Text(_visibleText(event)),
                                if (edited && !original.redacted)
                                  Text('Bearbeitet', style: Theme.of(context).textTheme.labelSmall),
                                if (mine && !original.redacted)
                                  Text(_delivery(original.status), style: Theme.of(context).textTheme.labelSmall),
                                if (reactions.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      for (final reaction in reactions)
                                        Text(
                                          reaction.content
                                                  .tryGetMap<String, Object?>('m.relates_to')
                                                  ?.tryGet<String>('key') ??
                                              '',
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if ((_reply != null || _editing != null) && timeline != null)
            Material(
              color: scheme.surfaceContainerHigh,
              child: ListTile(
                dense: true,
                title: Text(_editing != null ? 'Bearbeitung' : 'Antwort'),
                subtitle: Text(
                  (_editing ?? _reply)!.getDisplayEvent(timeline).body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Abbrechen',
                  onPressed: () => setState(() {
                    _reply = null;
                    _editing = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          if (widget.controller.sendTyping && typing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: Alignment.centerLeft, child: Text('schreibt…')),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          if (_recording || _preview != null)
            _VoiceBar(
              recording: _recording,
              locked: _locked,
              clock: _clock(_recording ? _elapsedMs : _previewMs),
              sending: _sending,
              playing: _playing && _playingPath == _previewPath,
              speed: _speed,
              progress: _playDur == 0 ? '' : '${_clock(_playPos)} / ${_clock(_playDur)}',
              onDiscard: _cancelRecording,
              onLock: () => setState(() => _locked = true),
              onStop: _finishRecording,
              onPlay: () {
                final path = _previewPath;
                if (path != null) _togglePlay(path);
              },
              onSpeed: _cycleSpeed,
              onSend: _sendVoice,
              onDrag: (delta) {
                _dragDy += delta;
                if (!_locked && _dragDy < -72) setState(() => _locked = true);
              },
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Bild senden. GPS wird vor dem Senden entfernt. Text im Feld wird zur Beschriftung.',
                    onPressed: _sending || _editing != null ? null : _sendImage,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  if (VoiceIo.supported)
                    IconButton(
                      tooltip: 'Sprachnachricht aufnehmen',
                      onPressed: _sending || _editing != null ? null : _startRecording,
                      icon: const Icon(Icons.mic_none),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(hintText: 'Nachricht'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Senden',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<Map<String, Object?>> _encryptReaction(Room room, Map<String, Object?> content) async {
  final encryption = room.client.encryption!;
  final keys = encryption.keyManager;
  if (keys.getOutboundGroupSession(room.id)?.isValid != true) {
    await keys.loadOutboundGroupSession(room.id);
  }
  await keys.clearOrUseOutboundGroupSession(room.id);
  if (keys.getOutboundGroupSession(room.id)?.isValid != true) {
    await keys.createOutboundGroupSession(room.id);
  }
  final session = keys.getOutboundGroupSession(room.id);
  final group = session?.outboundGroupSession;
  final senderKey = encryption.identityKey;
  if (session == null || group == null || senderKey == null || senderKey.isEmpty) {
    throw StateError('Keine Verschlüsselungssitzung für diese Reaktion.');
  }
  final ciphertext = group.encrypt(
    jsonEncode({
      'content': content,
      'type': EventTypes.Reaction,
      'room_id': room.id,
    }),
  );
  await keys.storeOutboundGroupSession(room.id, session);
  return {
    'algorithm': AlgorithmTypes.megolmV1AesSha2,
    'ciphertext': ciphertext,
    'device_id': room.client.deviceID,
    'sender_key': senderKey,
    'session_id': group.sessionId,
  };
}

String _visibleText(Event event) {
  final lines = event.body.split('\n').where((line) => !line.startsWith('>')).join('\n').trim();
  return lines.isEmpty ? event.body : lines;
}

String _delivery(EventStatus status) {
  return switch (status) {
    EventStatus.sending => 'Wird gesendet',
    EventStatus.sent => 'Vom Server angenommen',
    EventStatus.synced => 'Synchronisiert',
    EventStatus.error => 'Nicht gesendet',
  };
}

class _VoiceBar extends StatelessWidget {
  const _VoiceBar({
    required this.recording,
    required this.locked,
    required this.clock,
    required this.sending,
    required this.playing,
    required this.speed,
    required this.progress,
    required this.onDiscard,
    required this.onLock,
    required this.onStop,
    required this.onPlay,
    required this.onSpeed,
    required this.onSend,
    required this.onDrag,
  });

  final bool recording;
  final bool locked;
  final String clock;
  final bool sending;
  final bool playing;
  final double speed;
  final String progress;
  final VoidCallback onDiscard;
  final VoidCallback onLock;
  final VoidCallback onStop;
  final VoidCallback onPlay;
  final VoidCallback onSpeed;
  final VoidCallback onSend;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(recording ? 'Aufnahme $clock' : 'Anhören $clock'),
              if (recording && !locked) const Text('Nach oben schieben sperrt'),
              if (locked) const Text('Gesperrt'),
              if (progress.isNotEmpty) Text(progress),
              TextButton(onPressed: sending ? null : onDiscard, child: const Text('Verwerfen')),
              if (recording && !locked)
                TextButton(onPressed: onLock, child: const Text('Sperren')),
              if (recording)
                TextButton(onPressed: onStop, child: const Text('Anhören')),
              if (!recording) ...[
                TextButton(onPressed: sending ? null : onPlay, child: Text(playing ? 'Pause' : 'Abspielen')),
                TextButton(onPressed: onSpeed, child: Text('Tempo ${speed}x')),
                FilledButton(onPressed: sending ? null : onSend, child: Text(sending ? 'Senden…' : 'Senden')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioBubble extends StatelessWidget {
  const _AudioBubble({
    required this.label,
    required this.playing,
    required this.progress,
    required this.onPlay,
    required this.onSpeed,
  });

  final String label;
  final bool playing;
  final String progress;
  final VoidCallback onPlay;
  final VoidCallback onSpeed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sprachnachricht'),
        Text(label),
        Text(progress),
        Wrap(
          children: [
            TextButton(onPressed: onPlay, child: Text(playing ? 'Pause' : 'Abspielen')),
            TextButton(onPressed: onSpeed, child: const Text('Tempo')),
          ],
        ),
      ],
    );
  }
}

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.bytes, required this.caption});

  final Future<Uint8List?> bytes;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<Uint8List?>(
            future: bytes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 120,
                  width: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data;
              if (data == null) {
                return const Text('Bild nicht lesbar');
              }
              return Image.memory(data, width: 220, fit: BoxFit.cover);
            },
          ),
        ),
        if (caption.isNotEmpty && caption != 'bild.jpg') ...[
          const SizedBox(height: 6),
          Text(caption),
        ],
      ],
    );
  }
}
