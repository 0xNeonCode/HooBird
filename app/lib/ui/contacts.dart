// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';

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
  List<Map<String, dynamic>> _results = const [];
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _query.dispose();
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Kontakte', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Die Suche findet HooBird-Nutzernamen. Eine Kinderunterhaltung entsteht nur, wenn die Serverrichtlinie alle Beteiligten erlaubt.',
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
              trailing: const Icon(Icons.chat_bubble_outline),
              onTap: _busy ? null : () => _openChat('${row['user_id']}', '${row['username']}'),
            ),
          ),
      ],
    );
  }
}
