// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../policy_api.dart';
import '../session.dart';
import 'conversation.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.controller});

  final HoobirdController controller;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _query = TextEditingController();
  final _groupName = TextEditingController();
  final _picked = <String, String>{};
  List<Map<String, dynamic>> _results = const [];
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _query.dispose();
    _groupName.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final token = widget.controller.accessToken;
    if (token == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = await widget.controller.api.search(token, _query.text);
      final raw = body['results'];
      _results = raw is List
          ? raw.whereType<Map>().map((row) => row.map((key, value) => MapEntry('$key', value))).toList()
          : const [];
    } on PolicyException catch (exc) {
      _error = exc.message;
      _results = const [];
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openChat(String userId, String username) async {
    final client = widget.controller.client;
    if (client == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final roomId = await client.startDirectChat(userId);
      final room = client.getRoomById(roomId);
      if (!mounted || room == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConversationPage(room: room, controller: widget.controller),
        ),
      );
    } catch (exc) {
      _error = 'Unterhaltung mit $username nicht geöffnet: $exc';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGroup() async {
    final client = widget.controller.client;
    if (client == null || _picked.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var ids = _picked.keys.toList();
      final me = widget.controller.me;
      if (me?['role'] == 'child') {
        final token = widget.controller.accessToken;
        final childId = me?['user_id']?.toString();
        if (token == null || childId == null) {
          throw PolicyException(403, 'forbidden', 'Die Freigaben sind nicht geladen.');
        }
        final policy = await widget.controller.api.childPolicy(token, childId);
        final allowed = <String>{};
        final contacts = policy['contacts'];
        if (contacts is List) {
          for (final row in contacts.whereType<Map>()) {
            if (row['effective'] == true) allowed.add('${row['user_id']}');
          }
        }
        final rejected = ids.where((id) => !allowed.contains(id)).toList();
        if (rejected.isNotEmpty) {
          throw PolicyException(
            403,
            'not_approved',
            'Ein Kinderkonto nimmt nur freigegebene Kontakte in eine Gruppe.',
          );
        }
      }
      final roomId = await client.createGroupChat(
        groupName: _groupName.text.trim().isEmpty ? null : _groupName.text.trim(),
        invite: ids,
        historyVisibility: HistoryVisibility.joined,
        federated: false,
      );
      final room = client.getRoomById(roomId);
      if (!mounted || room == null) return;
      _picked.clear();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConversationPage(room: room, controller: widget.controller),
        ),
      );
    } on PolicyException catch (exc) {
      _error = exc.message;
    } catch (exc) {
      _error = 'Gruppe nicht angelegt: $exc';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Kontakte', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Die Suche findet HooBird-Nutzernamen. Eine Kinderunterhaltung oder Kindergruppe entsteht nur, wenn die Serverrichtlinie jeden anderen Beteiligten erlaubt. Neue Mitglieder sehen keine alten Nachrichten.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          decoration: const InputDecoration(labelText: 'Nutzername suchen'),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _search, child: const Text('Suchen')),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 12),
        for (final row in _results)
          Card(
            child: ListTile(
              title: Text('${row['username']}'),
              subtitle: Text('${row['role']} · ${row['user_id']}'),
              leading: Checkbox(
                value: _picked.containsKey('${row['user_id']}'),
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        final id = '${row['user_id']}';
                        if (value ?? false) {
                          _picked[id] = '${row['username']}';
                        } else {
                          _picked.remove(id);
                        }
                      }),
              ),
              trailing: const Icon(Icons.chat_bubble_outline),
              onTap: _busy ? null : () => _openChat('${row['user_id']}', '${row['username']}'),
            ),
          ),
        if (_picked.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Gruppe aus ${_picked.values.join(', ')}'),
          const SizedBox(height: 8),
          TextField(
            controller: _groupName,
            decoration: const InputDecoration(labelText: 'Gruppenname'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _createGroup,
            child: const Text('Gruppe anlegen'),
          ),
        ],
      ],
    );
  }
}
