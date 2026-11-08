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
  Timeline? _timeline;
  String? _error;
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

  Future<void> _sendImage() async {
    if (_sending) return;
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
      );
      _input.clear();
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
      await widget.room.sendTextEvent(text);
      _input.clear();
    } catch (exc) {
      _error = 'Senden abgelehnt: $exc';
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final verified = identityVerified(room.client, room);
    final label = securityLabel(encrypted: room.encrypted, identityVerified: verified);
    final scheme = Theme.of(context).colorScheme;
    final events = (_timeline?.events ?? const <Event>[])
        .where((event) => event.type == EventTypes.Message || event.type == EventTypes.Encrypted)
        .toList()
        .reversed
        .toList();
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
            child: _timeline == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final mine = event.senderId == room.client.userID;
                      final undecrypted =
                          event.type == EventTypes.Encrypted ||
                          event.messageType == MessageTypes.BadEncrypted;
                      final text = undecrypted
                          ? 'Verschlüsselt · Schlüssel auf diesem Gerät nicht vorhanden'
                          : event.body;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: mine ? scheme.primary.withValues(alpha: 0.22) : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(text),
                        ),
                      );
                    },
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
                  onPressed: _sending ? null : _sendImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Nachricht'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
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
