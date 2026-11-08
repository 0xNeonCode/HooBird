// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../policy_api.dart';
import '../session.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final HoobirdController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _notice;
  var _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } on PolicyException catch (exc) {
      _notice = exc.message;
    } catch (exc) {
      _notice = '$exc';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final me = controller.me;
    final role = me?['role']?.toString() ?? 'unbekannt';
    final username = me?['username']?.toString() ?? '';
    final userId = me?['user_id']?.toString() ?? controller.client?.userID ?? '';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Einstellungen', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text('Nutzername $username'),
        const SizedBox(height: 4),
        Text('Matrix-ID $userId'),
        const SizedBox(height: 4),
        Text('Rolle $role · Gerät ${controller.client?.deviceID ?? controller.deviceId}'),
        const SizedBox(height: 8),
        const Text(
          'Die Matrix-ID bleibt stehen, wenn sich der Nutzername ändert. Verschlüsselt ist nicht dasselbe wie identitätsverifiziert. Dieser Prototyp startet keine QR- oder Bluetooth-Prüfung.',
        ),
        const SizedBox(height: 16),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.light, label: Text('Hell')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dunkel')),
          ],
          selected: {controller.themeMode},
          onSelectionChanged: (value) => controller.setTheme(value.first),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : () => _run(controller.ensureRecoveryKey),
          child: const Text('Sicherungsschlüssel anlegen'),
        ),
        if (controller.recoveryKeyShownOnce != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Dieser Schlüssel liegt nur hier. Der Server gibt ihn nicht zurück. Ohne ihn oder ein bereits vertrautes Gerät können alte Nachrichten unlesbar bleiben. Ein Passwort-Reset liefert ihn nicht mit.',
          ),
          const SizedBox(height: 8),
          SelectableText(controller.recoveryKeyShownOnce!),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: controller.recoveryKeyShownOnce!));
              setState(() => _notice = 'In die Zwischenablage kopiert. Das ist nur für den lokalen Prototyp gedacht.');
            },
            child: const Text('Kopieren'),
          ),
        ],
        if (role == 'parent') ...[
          const SizedBox(height: 20),
          Text('Eltern', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Eltern lesen keine Nachrichten und bekommen keine Schlüssel. Eine Freigabe beweist keine Sorgeberechtigung. Ein Sperren durch ein Elternteil hebt das andere nicht durch erneutes Freigeben auf.',
          ),
          const SizedBox(height: 8),
          ParentPanel(controller: controller),
        ],
        if (role == 'child') ...[
          const SizedBox(height: 20),
          const Text(
            'Dieses Kinderkonto spricht nur mit freigegebenen Kontakten. Jedes weitere Gerät braucht eine Freigabe. Die Kennung bindet nicht den Geräteschlüssel.',
          ),
        ],
        if (_notice != null || controller.error != null) ...[
          const SizedBox(height: 12),
          Text(_notice ?? controller.error!),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: controller.busy ? null : controller.logout,
          child: const Text('Abmelden'),
        ),
      ],
    );
  }
}

class ParentPanel extends StatefulWidget {
  const ParentPanel({super.key, required this.controller});

  final HoobirdController controller;

  @override
  State<ParentPanel> createState() => _ParentPanelState();
}

class _ParentPanelState extends State<ParentPanel> {
  final _username = TextEditingController();
  final _device = TextEditingController();
  String? _selectedChild;
  Map<String, dynamic>? _policy;
  String? _notice;

  @override
  void dispose() {
    _username.dispose();
    _device.dispose();
    super.dispose();
  }

  List<String> get _children {
    final raw = widget.controller.me?['children'];
    if (raw is List) return raw.map((item) => '$item').toList();
    return const [];
  }

  Future<void> _load(String childId) async {
    final token = widget.controller.accessToken;
    if (token == null) return;
    final policy = await widget.controller.api.childPolicy(token, childId);
    setState(() {
      _selectedChild = childId;
      _policy = policy;
      _notice = null;
    });
  }

  Future<String?> _lookup() async {
    final token = widget.controller.accessToken;
    if (token == null) return null;
    final body = await widget.controller.api.search(token, _username.text);
    final results = body['results'];
    if (results is! List || results.isEmpty) {
      throw PolicyException(404, 'not_found', 'Nutzername nicht gefunden.');
    }
    final first = results.first;
    if (first is Map && '${first['username']}'.toLowerCase() == _username.text.trim().toLowerCase()) {
      return '${first['user_id']}';
    }
    throw PolicyException(404, 'not_found', 'Kein eindeutiger Nutzername.');
  }

  Future<void> _act(Future<void> Function(String token, String childId) action) async {
    final token = widget.controller.accessToken;
    final childId = _selectedChild;
    if (token == null || childId == null) return;
    try {
      await action(token, childId);
      await _load(childId);
    } on PolicyException catch (exc) {
      setState(() => _notice = exc.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = _children;
    final contacts = _policy?['contacts'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (children.isEmpty) const Text('Keine verknüpften Kinderkonten.'),
        for (final child in children)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(child),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _load(child),
          ),
        if (_policy != null) ...[
          Text('Nachrichten enthalten: ${_policy!['messages_included']} · Schlüssel enthalten: ${_policy!['keys_included']}'),
          const SizedBox(height: 8),
          if (contacts is List)
            for (final row in contacts.whereType<Map>())
              Text(
                '${row['username']} · wirksam ${row['effective']} · gesperrt von ${row['blocked_by']}',
              ),
          const SizedBox(height: 8),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Nutzername für Freigabe oder Sperre'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => _act((token, childId) async {
                  final contact = await _lookup();
                  if (contact == null) return;
                  await widget.controller.api.approve(token, childId, contact);
                }),
                child: const Text('Freigeben'),
              ),
              OutlinedButton(
                onPressed: () => _act((token, childId) async {
                  final contact = await _lookup();
                  if (contact == null) return;
                  await widget.controller.api.revokeApproval(token, childId, contact);
                }),
                child: const Text('Freigabe zurücknehmen'),
              ),
              OutlinedButton(
                onPressed: () => _act((token, childId) async {
                  final contact = await _lookup();
                  if (contact == null) return;
                  await widget.controller.api.block(token, childId, contact);
                }),
                child: const Text('Sperren'),
              ),
              OutlinedButton(
                onPressed: () => _act((token, childId) async {
                  final contact = await _lookup();
                  if (contact == null) return;
                  await widget.controller.api.liftBlock(token, childId, contact);
                }),
                child: const Text('Eigene Sperre aufheben'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _device,
            decoration: const InputDecoration(labelText: 'Gerätekennung freigeben'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _act((token, childId) async {
                  await widget.controller.api.authorizeDevice(token, childId, _device.text.trim());
                }),
                child: const Text('Gerät erlauben'),
              ),
              OutlinedButton(
                onPressed: () => _act((token, childId) async {
                  await widget.controller.api.revokeDevice(token, childId, _device.text.trim());
                }),
                child: const Text('Gerät widerrufen'),
              ),
              OutlinedButton(
                onPressed: () => _act((token, childId) async {
                  final code = await widget.controller.api.linkCode(token, childId);
                  setState(() {
                    _notice =
                        'Code ${code['code']}. Gilt ${code['ttl_seconds']} Sekunden. Beweist nicht: ${code['does_not_prove']}. QR ist nicht umgesetzt.';
                  });
                }),
                child: const Text('Verknüpfungscode'),
              ),
            ],
          ),
        ],
        if (_notice != null) ...[
          const SizedBox(height: 8),
          Text(_notice!),
        ],
      ],
    );
  }
}
