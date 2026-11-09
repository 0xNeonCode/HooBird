// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';

import '../owl_mark.dart';
import '../session.dart';

class GatePage extends StatefulWidget {
  const GatePage({super.key, required this.controller});

  final HoobirdController controller;

  @override
  State<GatePage> createState() => _GatePageState();
}

class _GatePageState extends State<GatePage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _device = TextEditingController();
  final _policy = TextEditingController();
  final _server = TextEditingController();
  var _showEndpoints = false;

  @override
  void initState() {
    super.initState();
    _device.text = widget.controller.deviceId;
    _policy.text = widget.controller.policyUrl;
    _server.text = widget.controller.homeserver;
    widget.controller.prepareFingerprint();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _device.dispose();
    _policy.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    widget.controller.setDeviceId(_device.text);
    widget.controller.setEndpoints(policy: _policy.text, server: _server.text);
    await widget.controller.login(_username.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          children: [
            Row(
              children: [
                const OwlMark(size: 48),
                const SizedBox(width: 12),
                Text(
                  'HooBird',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Machbarkeitsprototyp für Familien. Kein fertiges Produkt.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _username,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nutzername',
                hintText: 'Zum Beispiel mara',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passwort'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _device,
              decoration: const InputDecoration(
                labelText: 'Gerätekennung',
                helperText:
                    'Bei einem Kinderkonto muss ein Elternteil diese Kennung und die ed25519-Zeile darunter freigeben, bevor die Anmeldung Schlüssel hochlädt.',
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              'ed25519: ${controller.fingerprintStatus}',
              semanticsLabel: 'ed25519-Kennung dieses Geräts',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showEndpoints = !_showEndpoints),
                child: Text(_showEndpoints ? 'Server ausblenden' : 'Server anzeigen'),
              ),
            ),
            if (_showEndpoints) ...[
              TextField(
                controller: _policy,
                decoration: const InputDecoration(
                  labelText: 'Policy-Adresse',
                  helperText: 'HTTPS. Klartext nur für 127.0.0.1 und localhost.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _server,
                decoration: const InputDecoration(
                  labelText: 'Homeserver',
                  helperText: 'HTTPS. Klartext nur für 127.0.0.1 und localhost.',
                ),
              ),
            ],
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
            const SizedBox(height: 18),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(controller.error!, style: TextStyle(color: scheme.error)),
              ),
            FilledButton(
              onPressed: controller.busy ? null : _submit,
              child: Text(controller.busy ? 'Melde an…' : 'Anmelden'),
            ),
            const SizedBox(height: 16),
            Text(
              'Die E-Mail-Adresse ist optional und wird hier nicht abgefragt. Sie bestätigt nur ein Postfach, nicht Alter oder Identität. QR- und Bluetooth-Abgleich sind in diesem Meilenstein nicht umgesetzt.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
