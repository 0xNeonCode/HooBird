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

class ChatList extends StatelessWidget {
  const ChatList({super.key, required this.controller});

  final HoobirdController controller;

  @override
  Widget build(BuildContext context) {
    final client = controller.client;
    if (client == null) {
      return const Center(child: Text('Kein Matrix-Client.'));
    }
    return StreamBuilder(
      stream: client.onSync.stream,
      builder: (context, _) {
        final rooms = client.rooms.where((room) => room.membership == Membership.join).toList()
          ..sort((a, b) {
            final left = a.lastEvent?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.lastEvent?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
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
            Expanded(
              child: rooms.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Noch keine Unterhaltungen. Über Kontakte kannst du eine Einladung in einen verschlüsselten Raum senden. Ob der Server sie annimmt, hängt von der Kinderrichtlinie ab.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: rooms.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return Card(
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            title: Text(room.getLocalizedDisplayname()),
                            subtitle: Text(_preview(room)),
                            trailing: Icon(
                              room.encrypted ? Icons.lock_outline : Icons.lock_open,
                              color: room.encrypted
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ConversationPage(room: room),
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
      MessageTypes.Text || MessageTypes.Notice || MessageTypes.Emote => event.body,
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
