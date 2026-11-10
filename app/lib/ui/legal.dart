// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quelltext und Lizenzen')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Quelle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const SelectableText('https://github.com/0xNeonCode/HooBird'),
          const SizedBox(height: 16),
          const Text(
            'Eigener Code dieses Repositorys steht unter AGPL-3.0-or-later. Die ausgelieferte App bindet flutter_vodozemac 0.9.0 ein. Dessen mitgelieferter Lizenztext ist die GNU AGPL Version 3, ohne eine hier geprüfte Erlaubnis für spätere Versionen. Die Kombination bleibt deshalb bei AGPL-3.0. Das ist eine Lesart der vorliegenden Hinweise, keine Rechtsberatung.',
          ),
          const SizedBox(height: 16),
          Text('AGPL §13', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Wenn jemand diese App oder den Policy-Dienst verändert und anderen Personen über ein Netz anbietet, verlangt Abschnitt 13 der GNU AGPL, den entsprechenden Quelltext diesen Personen anzubieten. Ein lokaler Prototyp auf dem eigenen Rechner ist das nicht. Diese Ansicht ersetzt keine rechtliche Prüfung.',
          ),
          const SizedBox(height: 16),
          Text('Meldung', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Ein privater Meldeweg ist nicht eingeschaltet. Diese Seite nennt absichtlich keine E-Mail-Adresse und keine Melde-URL.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Text(
            'Löschen einer Nachricht holt keine Kopie zurück, die jemand schon gesehen, gespeichert oder abfotografiert hat. Verschlüsselt ist nicht dasselbe wie verifiziert. Ein QR-Code für die Elternverknüpfung beweist weder Alter noch Sorgeberechtigung und ist in diesem Meilenstein nicht eingebaut.',
          ),
        ],
      ),
    );
  }
}
