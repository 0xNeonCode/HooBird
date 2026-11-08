// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';

import '../media_prep.dart';
import '../security_label.dart';
import 'shell.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.room});

  final Room room;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _input = TextEditingController();
  final _anchors = <String, GlobalKey>{};
  final _images = <String, Future<Uint8List?>>{};
  Timeline? _timeline;
  String? _error;
  Event? _reply;
  Event? _editing;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final timeline = await widget.room.getTimeline(
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() => _timeline = timeline);
  }

  @override
  void dispose() {
    _timeline?.cancelSubscriptions();
    _input.dispose();
    super.dispose();
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
    if (_sending || _editing != null) return;
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
    try {
      await widget.room.sendReaction(event.eventId, emoji);
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
    final events = _messages;
    final timeline = _timeline;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.getLocalizedDisplayname()),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
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
                      final reactions = original.aggregatedEvents(timeline, RelationshipTypes.reaction);
                      return Align(
                        key: _anchor(original.eventId),
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _actions(original),
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
                                          : 'Antwort auf: ${reply.getDisplayEvent(timeline).body}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (original.redacted)
                                  const Text(
                                    'Gelöscht. Eine schon gesehene oder abfotografierte Kopie bleibt bei den anderen.',
                                  )
                                else if (undecrypted)
                                  const Text('Verschlüsselt · Schlüssel auf diesem Gerät nicht vorhanden')
                                else if (event.messageType == MessageTypes.Image)
                                  _ImageBubble(bytes: _imageBytes(event), caption: event.body)
                                else
                                  Text(event.body),
                                if (edited && !original.redacted)
                                  Text('Bearbeitet', style: Theme.of(context).textTheme.labelSmall),
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Bild senden. GPS wird vor dem Senden entfernt. Text im Feld wird zur Beschriftung.',
                  onPressed: _sending || _editing != null ? null : _sendImage,
                  icon: const Icon(Icons.image_outlined),
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
