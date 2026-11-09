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
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:path_provider/path_provider.dart';

import '../audio_prep.dart';
import '../media_prep.dart';
import '../policy_api.dart';
import '../receipts.dart';
import '../room_rules.dart';
import '../security_label.dart';
import '../session.dart';
import '../voice_io.dart';
import '../voice_meter.dart';
import 'delivery.dart';
import 'image_view.dart';
import 'shell.dart';
import 'voice_hold.dart';

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
  final _items = ItemScrollController();
  List<String> _shownIds = const [];
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
  String? _previewPath;
  final _levels = <double>[];
  final _meter = VoiceMeter();
  String? _playingPath;
  var _playing = false;
  var _playPos = 0;
  var _playDur = 0;
  var _speed = 1.0;
  var _wasTyping = false;
  var _markedEventId = '';
  var _searching = false;
  var _finishing = false;
  final _deliverySeen = <String>{};
  final _deliveryRead = <String>{};
  @override
  void initState() {
    super.initState();
    _open();
    _input.addListener(_onComposerChanged);
    VoiceIo.addListener(_onVoiceEvent);
    if (VoiceIo.supported) unawaited(VoiceIo.ensureListening());
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
    VoiceIo.removeListener(_onVoiceEvent);
    if (_recording) {
      unawaited(VoiceIo.stop().then<void>((_) {}, onError: (_, _) {}));
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
    final typing = _input.text.trim().isNotEmpty && _editing == null && !_recording;
    if (typing == _wasTyping) return;
    _wasTyping = typing;
    widget.room.setTyping(typing);
  }

  void _onVoiceEvent(Map<String, Object?> event) {
    if (!mounted) return;
    if (event['kind'] == 'recording') {
      _meter.recording = _recording;
      _meter.apply(event);
      if (!_recording) return;
      setState(() {
        _elapsedMs = _meter.elapsedMs;
        _levels
          ..clear()
          ..addAll(_meter.levels);
      });
      if (_meter.elapsedMs >= 180000) _releaseSend();
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
      final plan = receiptPlan(sendReceipts: widget.controller.sendReceipts);
      await _timeline?.setReadMarker(
        eventId: latest.eventId,
        public: plan.publicRead,
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

  Future<void> _sendImage(ImageSource source) async {
    if (_sending || _editing != null || _recording) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: source);
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
      await VoiceIo.permission();
    }
  }

  void _voiceHint(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _beginVoice() async {
    if (!VoiceIo.supported || _sending || _recording || _editing != null) return false;
    try {
      final status = await VoiceIo.permission();
      if (!mounted) return false;
      if (status != 'granted') {
        await _explainMic(status);
        return false;
      }
      final directory = await getTemporaryDirectory();
      final path = p.join(directory.path, 'hoobird-voice-${DateTime.now().microsecondsSinceEpoch}.m4a');
      // Mark recording before start so the first amplitude tick is not dropped.
      _meter.recording = true;
      _meter.reset();
      setState(() {
        _recording = true;
        _locked = false;
        _elapsedMs = 0;
        _levels.clear();
        _error = null;
        _previewPath = path;
      });
      await VoiceIo.start(path);
      if (!mounted) {
        await VoiceIo.stop();
        return false;
      }
      return true;
    } on PlatformException catch (exc) {
      _voiceHint(exc.message ?? 'Die Aufnahme konnte nicht starten.');
      return false;
    }
  }

  Future<void> _discardVoice({String? hint}) async {
    try {
      if (_recording) await VoiceIo.stop();
    } catch (_) {}
    final path = _previewPath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _locked = false;
      _previewPath = null;
      _elapsedMs = 0;
      _levels.clear();
      _playing = false;
      if (hint != null) _error = hint;
    });
    if (hint != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
    }
  }

  Future<void> _releaseSend() async {
    if (!_recording || _finishing) return;
    _finishing = true;
    final path = _previewPath;
    try {
      late final VoiceTake take;
      try {
        take = await VoiceIo.stop();
      } on PlatformException catch (exc) {
        if (path != null && File(path).existsSync()) File(path).deleteSync();
        final message = exc.code == 'record_stop_failed'
            ? 'Zu kurz. Halte die Taste etwas länger.'
            : 'Aufnahme abgebrochen. ${exc.message ?? exc.code}';
        if (mounted) {
          setState(() {
            _recording = false;
            _locked = false;
            _previewPath = null;
            _error = message;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }
      if (path == null) return;
      final file = File(path);
      final length = file.existsSync() ? file.lengthSync() : take.bytes;
      final elapsed = take.elapsedMs;
      final reason = voiceTakeRejection(
        byteLength: length,
        elapsedMs: elapsed,
        rms: take.rms,
        decoded: take.decoded,
      );
      unawaited(
        VoiceIo.log(
          'take reason=${reason ?? 'accept'} bytes=$length elapsed=$elapsed rms=${take.rms} decoded=${take.decoded}',
        ),
      );
      if (reason != null) {
        if (file.existsSync()) file.deleteSync();
        final message = voiceTakeHint(reason);
        if (mounted) {
          setState(() {
            _recording = false;
            _locked = false;
            _previewPath = null;
            _error = message;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }
      final stripped = stripMp4Metadata(await file.readAsBytes());
      if (!mounted) return;
      setState(() {
        _recording = false;
        _locked = false;
        _sending = true;
        _error = null;
      });
      await widget.room.sendFileEvent(
        MatrixAudioFile(
          bytes: stripped,
          name: 'sprachnachricht.m4a',
          mimeType: 'audio/mp4',
          duration: elapsed,
        ),
        extraContent: {'org.matrix.msc3245.voice': <String, dynamic>{}},
        inReplyTo: _reply,
      );
      if (file.existsSync()) file.deleteSync();
      if (!mounted) return;
      setState(() {
        _previewPath = null;
        _reply = null;
        _elapsedMs = 0;
        _levels.clear();
      });
    } on AudioPrepException catch (exc) {
      if (path != null && File(path).existsSync()) File(path).deleteSync();
      if (mounted) {
        setState(() {
          _recording = false;
          _locked = false;
          _previewPath = null;
          _error = exc.message;
        });
      }
    } catch (exc) {
      if (mounted) setState(() => _error = 'Sprachnachricht abgelehnt: $exc');
    } finally {
      _finishing = false;
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
      if (display.messageType == MessageTypes.Text && !display.redacted) {
        final text = _visibleText(display);
        if (text.isNotEmpty) texts.add(text);
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

  Future<void> _mention() async {
    final members = widget.room
        .getParticipants()
        .where((user) => user.id != widget.room.client.userID && user.membership == Membership.join)
        .toList();
    if (!mounted || members.isEmpty) return;
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Erwähnen'),
              subtitle: Text('Der Name steht im verschlüsselten Text. Der Server sieht ihn nicht im Klartext.'),
            ),
            for (final user in members)
              ListTile(
                title: Text(user.displayName ?? user.id),
                subtitle: Text(user.id),
                onTap: () => Navigator.pop(context, user.id),
              ),
          ],
        ),
      ),
    );
    if (id == null) return;
    final next = mentionInsertion(current: _input.text, userId: id);
    _input.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
  }

  Future<void> _report() async {
    final timeline = _timeline;
    final events = <Event>[];
    final chosen = <String, bool>{};
    for (final id in _selected) {
      final event = _eventById(id);
      if (event == null || event.redacted) continue;
      final display = timeline == null ? event : event.getDisplayEvent(timeline);
      if (display.messageType != MessageTypes.Text) continue;
      events.add(display);
      chosen[display.eventId] = false;
    }
    final note = TextEditingController();
    if (!mounted) return;
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Melden'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nichts ist vorausgewählt. Nur angehakte Texte werden gespeichert. Der Server liest die Ereignisse nicht selbst nach. Eltern sehen diese Meldung nicht.',
                ),
                for (final event in events)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: chosen[event.eventId] ?? false,
                    onChanged: (value) => setLocal(() => chosen[event.eventId] = value ?? false),
                    title: Text(_visibleText(event), maxLines: 4, overflow: TextOverflow.ellipsis),
                  ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Hinweis, ohne Nachrichtentext'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Meldung senden')),
          ],
        ),
      ),
    );
    final text = note.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => note.dispose());
    if (send != true) return;
    final token = widget.controller.accessToken;
    if (token == null) return;
    try {
      await widget.controller.api.fileReport(
        token,
        roomId: widget.room.id,
        note: text,
        items: [
          for (final event in events)
            {
              'event_id': event.eventId,
              'disclose': chosen[event.eventId] == true,
              if (chosen[event.eventId] == true) 'body': _visibleText(event),
            },
        ],
      );
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meldung gespeichert. Eltern sehen sie nicht.')),
      );
    } on PolicyException catch (exc) {
      if (mounted) setState(() => _error = exc.message);
    }
  }

  Future<void> _manage() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _RoomTools(
        room: widget.room,
        controller: widget.controller,
        onLeft: () {
          if (mounted) Navigator.of(this.context).pop();
        },
      ),
    );
  }

  bool _armReadBlink(String eventId, bool read) {
    final seen = _deliverySeen.contains(eventId);
    final wasRead = _deliveryRead.contains(eventId);
    _deliverySeen.add(eventId);
    if (read) {
      _deliveryRead.add(eventId);
    } else {
      _deliveryRead.remove(eventId);
    }
    return seen && read && !wasRead;
  }

  int? _receiptIndex(String userId) {
    final timeline = _timeline;
    if (timeline == null) return null;
    final global = widget.room.receiptState.global.otherUsers[userId]?.eventId;
    final threaded = widget.room.receiptState.mainThread?.otherUsers[userId]?.eventId;
    int? indexOf(String? eventId) {
      if (eventId == null) return null;
      final index = timeline.events.indexWhere((event) => event.eventId == eventId);
      return index < 0 ? null : index;
    }

    final unthreaded = indexOf(global);
    final main = indexOf(threaded);
    if (unthreaded == null) return main;
    if (main == null) return unthreaded;
    return unthreaded < main ? unthreaded : main;
  }

  ({List<String> readers, List<String> waiting, bool everyone}) _readCoverage(Event event) {
    final timeline = _timeline;
    final room = widget.room;
    if (timeline == null) {
      return (readers: const <String>[], waiting: const <String>[], everyone: false);
    }
    final messageIndex = timeline.events.indexWhere((item) => item.eventId == event.eventId);
    final others = room
        .getParticipants()
        .where((user) => user.membership == Membership.join && user.id != room.client.userID)
        .map((user) => user.id)
        .toList();
    final indexes = <String, int?>{for (final id in others) id: _receiptIndex(id)};
    final readers = membersWhoRead(
      messageIndex: messageIndex,
      receiptIndexByMember: indexes,
      otherJoinedMemberIds: others,
    );
    return (
      readers: readers,
      waiting: [for (final id in others) if (!readers.contains(id)) id],
      everyone: everyoneJoinedHasRead(
        messageIndex: messageIndex,
        receiptIndexByMember: indexes,
        otherJoinedMemberIds: others,
      ),
    );
  }

  String _memberName(String userId) {
    final user = widget.room.unsafeGetUserFromMemoryOrFallback(userId);
    final name = user.calcDisplayname();
    if (name.isEmpty) return userId;
    return name;
  }

  String _stamp(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _retrySend(Event event) async {
    try {
      await event.sendAgain();
    } catch (exc) {
      if (mounted) setState(() => _error = 'Erneut senden ist fehlgeschlagen: $exc');
    }
  }

  Future<void> _messageInfo(Event event) async {
    final mine = event.senderId == widget.room.client.userID;
    final coverage = _readCoverage(event);
    final state = outboundDelivery(
      status: event.status,
      showRead: widget.controller.sendReceipts && coverage.everyone,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: const Text('Nachricht'), subtitle: Text(_stamp(event.originServerTs))),
            if (mine) ListTile(title: Text(deliveryLabel(state))),
            if (mine)
              for (final line in readerLines(
                sendReceipts: widget.controller.sendReceipts,
                readers: coverage.readers,
                waiting: coverage.waiting,
              ))
                ListTile(
                  title: Text(switch (line.kind) {
                    ReaderLineKind.off => 'Lesebestätigungen sind aus',
                    ReaderLineKind.none => 'Gelesen von niemandem sonst',
                    ReaderLineKind.read => _memberName(line.userId ?? ''),
                    ReaderLineKind.waiting => _memberName(line.userId ?? ''),
                  }),
                  subtitle: Text(switch (line.kind) {
                    ReaderLineKind.off => 'Du sendest keine öffentliche Quittung m.read und siehst nicht, wer gelesen hat.',
                    ReaderLineKind.none => 'Noch keine öffentliche Quittung m.read.',
                    ReaderLineKind.read => 'Gelesen',
                    ReaderLineKind.waiting => 'Noch nicht',
                  }),
                ),
          ],
        ),
      ),
    );
  }

  void _jump(String eventId) {
    final index = _shownIds.indexOf(eventId);
    if (index < 0 || !_items.isAttached) {
      setState(() => _error = 'Die ursprüngliche Nachricht ist in diesem Ausschnitt nicht geladen.');
      return;
    }
    setState(() => _error = null);
    _items.scrollTo(index: index, alignment: 0.3, duration: const Duration(milliseconds: 250));
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
              title: const Text('Info'),
              onTap: () {
                Navigator.pop(context);
                _messageInfo(event);
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
    _shownIds = [for (final event in events) event.eventId];
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
          if (_selected.isNotEmpty) ...[
            IconButton(
              tooltip: 'Auswahl weiterleiten',
              onPressed: _forward,
              icon: const Icon(Icons.forward),
            ),
            IconButton(
              tooltip: 'Auswahl melden',
              onPressed: _report,
              icon: const Icon(Icons.flag_outlined),
            ),
          ],
          IconButton(
            tooltip: room.isDirectChat ? 'Kontakt blockieren' : 'Gruppe',
            onPressed: _manage,
            icon: Icon(room.isDirectChat ? Icons.block : Icons.group_outlined),
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
                : ScrollablePositionedList.builder(
                    itemScrollController: _items,
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
                                  _ImageBubble(
                                    bytes: _imageBytes(event),
                                    caption: event.body,
                                    onOpen: _selected.isEmpty
                                        ? (data) {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (context) => ImageViewerPage(
                                                  bytes: data,
                                                  allowExport: !widget.controller.hideNotificationContent,
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                  )
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
                                if (!original.redacted)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _stamp(original.originServerTs),
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                        if (mine) ...[
                                          const SizedBox(width: 4),
                                          DeliveryMark(
                                            key: ValueKey('delivery-${original.eventId}'),
                                            state: outboundDelivery(
                                              status: original.status,
                                              showRead: widget.controller.sendReceipts && _readCoverage(original).everyone,
                                            ),
                                            blink: _armReadBlink(
                                              original.eventId,
                                              widget.controller.sendReceipts &&
                                                  _readCoverage(original).everyone &&
                                                  (original.status == EventStatus.sent ||
                                                      original.status == EventStatus.synced),
                                            ),
                                            onRetry: () => _retrySend(original),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
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
                  _visibleText((_editing ?? _reply)!.getDisplayEvent(timeline)),
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
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  if (_recording && !_locked)
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 4, bottom: 2),
                        child: Column(
                          children: [
                            Icon(Icons.lock_outline, size: 18),
                            Icon(Icons.keyboard_arrow_up, size: 18),
                          ],
                        ),
                      ),
                    ),
                  Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!_recording) ...[
                    IconButton(
                      tooltip: 'Mitglied erwähnen',
                      onPressed: _sending || _editing != null ? null : _mention,
                      icon: const Icon(Icons.alternate_email),
                    ),
                    IconButton(
                      tooltip: 'Bild aus der Galerie. GPS wird vor dem Senden entfernt. Text im Feld wird zur Beschriftung.',
                      onPressed: _sending || _editing != null ? null : () => _sendImage(ImageSource.gallery),
                      icon: const Icon(Icons.image_outlined),
                    ),
                    IconButton(
                      tooltip: 'Foto aufnehmen. GPS wird vor dem Senden entfernt. Text im Feld wird zur Beschriftung.',
                      onPressed: _sending || _editing != null ? null : () => _sendImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                  ],
                  if (_recording)
                    Expanded(
                      child: VoiceRecordingChrome(
                        clock: _clock(_elapsedMs),
                        levels: List<double>.from(_levels),
                        locked: _locked,
                      ),
                    )
                  else
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
                  if (_recording && _locked) ...[
                    IconButton(
                      tooltip: 'Aufnahme verwerfen',
                      onPressed: _sending ? null : () => _discardVoice(),
                      icon: const Icon(Icons.delete_outline),
                    ),
                    FilledButton(
                      onPressed: _sending ? null : _releaseSend,
                      child: Text(_sending ? 'Senden…' : 'Senden'),
                    ),
                  ] else if (VoiceIo.supported)
                    VoiceMicButton(
                      key: const ValueKey('voice-mic'),
                      enabled: !_sending && _editing == null,
                      elapsedMs: () => _elapsedMs,
                      onStart: _beginVoice,
                      onLock: () => setState(() => _locked = true),
                      onCancel: _discardVoice,
                      onSend: _releaseSend,
                      onTooShort: () => _discardVoice(hint: 'Zu kurz. Halte die Taste etwas länger.'),
                    ),
                  if (!_recording) ...[
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Senden',
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ],
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
  const _ImageBubble({required this.bytes, required this.caption, required this.onOpen});

  final Future<Uint8List?> bytes;
  final String caption;
  final void Function(Uint8List bytes)? onOpen;

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
              return GestureDetector(
                onTap: onOpen == null ? null : () => onOpen!(data),
                child: Semantics(
                  button: onOpen != null,
                  label: 'Bild vergrößern',
                  child: Image.memory(data, width: 220, fit: BoxFit.cover),
                ),
              );
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

class _RoomTools extends StatefulWidget {
  const _RoomTools({required this.room, required this.controller, required this.onLeft});

  final Room room;
  final HoobirdController controller;
  final VoidCallback onLeft;

  @override
  State<_RoomTools> createState() => _RoomToolsState();
}

class _RoomToolsState extends State<_RoomTools> {
  final _name = TextEditingController();
  final _invite = TextEditingController();
  String? _notice;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.room.name;
  }

  @override
  void dispose() {
    _name.dispose();
    _invite.dispose();
    super.dispose();
  }

  bool get _admin => isRoomAdmin(widget.room.ownPowerLevel.level);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
      if (mounted) setState(() => _notice = null);
    } on PolicyException catch (exc) {
      if (mounted) setState(() => _notice = exc.message);
    } catch (exc) {
      if (mounted) setState(() => _notice = 'Abgelehnt: $exc');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Set<String>?> _childAllowList() async {
    final me = widget.controller.me;
    if (me?['role'] != 'child') return null;
    final token = widget.controller.accessToken;
    final childId = me?['user_id']?.toString();
    if (token == null || childId == null) return {};
    final policy = await widget.controller.api.childPolicy(token, childId);
    return approvedContactIds(policy['contacts']);
  }

  Future<void> _inviteByName() async {
    final token = widget.controller.accessToken;
    if (token == null) return;
    final body = await widget.controller.api.search(token, _invite.text);
    final results = body['results'];
    if (results is! List || results.isEmpty) {
      throw PolicyException(404, 'not_found', 'Nutzername nicht gefunden.');
    }
    final first = results.first;
    if (first is! Map || '${first['username']}'.toLowerCase() != _invite.text.trim().toLowerCase()) {
      throw PolicyException(404, 'not_found', 'Kein eindeutiger Nutzername.');
    }
    final userId = '${first['user_id']}';
    final allowed = await _childAllowList();
    if (allowed != null) {
      final blocked = childInviteBlock(isChild: true, approved: allowed, userId: userId);
      if (blocked != null) throw PolicyException(403, 'not_approved', blocked);
    }
    await widget.room.invite(userId);
    _invite.clear();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final members = room.getParticipants();
    final me = room.client.userID;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(room.isDirectChat ? 'Kontakt' : 'Gruppe'),
              subtitle: const Text(
                'Neue Mitglieder bekommen keine alten Nachrichten. Der Server behält die Historie auf „joined“.',
              ),
            ),
            if (!room.isDirectChat && _admin) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Gruppenname'),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : () => _run(() => room.setName(_name.text.trim())),
                  child: const Text('Umbenennen'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _invite,
                  decoration: const InputDecoration(labelText: 'Nutzername einladen'),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : () => _run(_inviteByName),
                  child: const Text('Einladen'),
                ),
              ),
            ],
            for (final user in members)
              ListTile(
                title: Text(user.displayName ?? user.id),
                subtitle: Text('${user.membership.name} · ${powerLabel(user.powerLevel.level)}'),
                trailing: user.id == me
                    ? null
                    : Wrap(
                        spacing: 4,
                        children: [
                          if (!room.isDirectChat && _admin && user.membership == Membership.join)
                            IconButton(
                              tooltip: isRoomAdmin(user.powerLevel.level) ? 'Verwaltung entziehen' : 'Verwaltung geben',
                              onPressed: _busy
                                  ? null
                                  : () => _run(() => room.setPower(user.id, toggledAdminPower(user.powerLevel.level))),
                              icon: Icon(user.powerLevel.level >= 50 ? Icons.shield_outlined : Icons.admin_panel_settings_outlined),
                            ),
                          if (!room.isDirectChat && _admin)
                            IconButton(
                              tooltip: 'Entfernen',
                              onPressed: _busy ? null : () => _run(() => room.kick(user.id)),
                              icon: const Icon(Icons.person_remove_outlined),
                            ),
                          IconButton(
                            tooltip: 'Blockieren',
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    final token = widget.controller.accessToken;
                                    if (token == null) return;
                                    await widget.controller.api.blockPerson(token, user.id);
                                  }),
                            icon: const Icon(Icons.block),
                          ),
                        ],
                      ),
              ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_notice!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ListTile(
              title: const Text('Raum verlassen'),
              onTap: _busy
                  ? null
                  : () => _run(() async {
                      await room.leave();
                      if (context.mounted) Navigator.pop(context);
                      widget.onLeft();
                    }),
            ),
          ],
        ),
      ),
    );
  }
}
