// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../owl_mark.dart';
import '../security_label.dart';
import '../session.dart';
import 'contacts.dart';
import 'conversation.dart';
import 'settings.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final HoobirdController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.refreshMe();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChatList(controller: widget.controller),
      ContactsPage(controller: widget.controller),
      SettingsPage(controller: widget.controller),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Kontakte'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Einstellungen'),
        ],
      ),
    );
  }
}

class ChatList extends StatefulWidget {
  const ChatList({super.key, required this.controller});

  final HoobirdController controller;

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final _query = TextEditingController();
  String? _error;
  var _showArchive = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (exc) {
      if (mounted) setState(() => _error = 'Die Raumaktion wurde abgelehnt: $exc');
    }
  }

  Future<void> _roomActions(Room room) async {
    final muted = room.pushRuleState == PushRuleState.dontNotify;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(room.isFavourite ? 'Nicht mehr anheften' : 'Anheften'),
              onTap: () {
                Navigator.pop(context);
                _run(() => room.setFavourite(!room.isFavourite));
              },
            ),
            ListTile(
              title: Text(room.isLowPriority ? 'Aus dem Archiv holen' : 'Archivieren'),
              onTap: () {
                Navigator.pop(context);
                _run(() => room.setLowPriority(!room.isLowPriority));
              },
            ),
            ListTile(
              title: Text(muted ? 'Ton wieder an' : 'Stummschalten'),
              subtitle: const Text('Gilt für Hinweise dieses Raums. Der Inhalt bleibt verschlüsselt.'),
              onTap: () {
                Navigator.pop(context);
                _run(
                  () => room.setPushRuleState(muted ? PushRuleState.notify : PushRuleState.dontNotify),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.controller.client;
    if (client == null) {
      return const Center(child: Text('Kein Matrix-Client.'));
    }
    return StreamBuilder(
      stream: client.onSync.stream,
      builder: (context, _) {
        final query = _query.text.trim().toLowerCase();
        bool matches(Room room) =>
            query.isEmpty || room.getLocalizedDisplayname().toLowerCase().contains(query);
        final joined = client.rooms.where((room) => room.membership == Membership.join).toList();
        int byRecent(Room a, Room b) {
          if (a.isFavourite != b.isFavourite) return a.isFavourite ? -1 : 1;
          final left = a.lastEvent?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.lastEvent?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        }

        final active = joined.where((room) => !room.isLowPriority && matches(room)).toList()..sort(byRecent);
        final archived = joined.where((room) => room.isLowPriority && matches(room)).toList()..sort(byRecent);
        final visible = [...active, if (_showArchive) ...archived];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const OwlMark(size: 32),
                  const SizedBox(width: 10),
                  Text(
                    'HooBird',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _query,
                decoration: const InputDecoration(
                  hintText: 'Chats durchsuchen',
                  helperText: 'Sucht in den Namen der geladenen Räume, nicht im verschlüsselten Text.',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Expanded(
              child: active.isEmpty && archived.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Noch keine Unterhaltungen. Über Kontakte kannst du eine Einladung in einen verschlüsselten Raum senden. Ob der Server sie annimmt, hängt von der Kinderrichtlinie ab.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: visible.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == visible.length) {
                          return TextButton(
                            onPressed: archived.isEmpty ? null : () => setState(() => _showArchive = !_showArchive),
                            child: Text(_showArchive ? 'Archiv ausblenden' : 'Archiv (${archived.length})'),
                          );
                        }
                        final room = visible[index];
                        final muted = room.pushRuleState == PushRuleState.dontNotify;
                        return Card(
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            title: Text(room.getLocalizedDisplayname()),
                            subtitle: Text(_preview(room)),
                            trailing: Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (room.isFavourite) const Icon(Icons.push_pin_outlined, size: 18),
                                if (room.isLowPriority) const Icon(Icons.archive_outlined, size: 18),
                                if (muted) const Icon(Icons.notifications_off_outlined, size: 18),
                                Icon(
                                  room.encrypted ? Icons.lock_outline : Icons.lock_open,
                                  color: room.encrypted
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ],
                            ),
                            onLongPress: () => _roomActions(room),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ConversationPage(room: room, controller: widget.controller),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

String _plainPreview(String body) {
  final text = body.split('\n').where((line) => !line.startsWith('>')).join(' ').trim();
  return text.isEmpty ? 'Nachricht' : text;
}

String _preview(Room room) {
  final event = room.lastEvent;
  if (event == null) return 'Noch keine Nachricht';
  if (event.type == EventTypes.Encrypted || event.messageType == MessageTypes.BadEncrypted) {
    return 'Verschlüsselt · auf diesem Gerät nicht lesbar';
  }
  if (event.type == EventTypes.Message) {
    return switch (event.messageType) {
      MessageTypes.Image => 'Foto',
      MessageTypes.Audio => 'Sprachnachricht',
      MessageTypes.Text || MessageTypes.Notice || MessageTypes.Emote => _plainPreview(event.body),
      _ => 'Nachricht',
    };
  }
  if (event.type == EventTypes.Encryption) {
    return securityLabel(encrypted: true, identityVerified: false);
  }
  return 'Ereignis';
}

bool identityVerified(Client client, Room room) {
  final other = room.directChatMatrixID;
  if (other == null) return false;
  return client.userDeviceKeys[other]?.verified == UserVerifiedStatus.verified;
}
