// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/theme.dart';
import 'package:hoobird/ui/delivery.dart';
import 'package:matrix/matrix.dart';

void main() {
  test('Gesendet bleibt ein Haken, auch nach dem Sync', () {
    expect(outboundDelivery(status: EventStatus.sending, showRead: false), OutboundDelivery.sending);
    expect(outboundDelivery(status: EventStatus.sent, showRead: false), OutboundDelivery.sent);
    expect(outboundDelivery(status: EventStatus.synced, showRead: false), OutboundDelivery.sent);
    expect(outboundDelivery(status: EventStatus.synced, showRead: true), OutboundDelivery.read);
    expect(outboundDelivery(status: EventStatus.error, showRead: true), OutboundDelivery.failed);
    expect(deliveryLabel(OutboundDelivery.sent), 'Gesendet');
    expect(deliveryLabel(OutboundDelivery.read), 'Gelesen');
  });

  test('Gelesen gilt nur, wenn die Quittung im Ausschnitt liegt und neuer oder gleich ist', () {
    expect(receiptCoversMessage(messageIndex: 4, receiptIndex: 4), isTrue);
    expect(receiptCoversMessage(messageIndex: 4, receiptIndex: 1), isTrue);
    expect(receiptCoversMessage(messageIndex: 1, receiptIndex: 4), isFalse);
    expect(receiptCoversMessage(messageIndex: 1, receiptIndex: null), isFalse);

    const members = ['@a:example', '@b:example'];
    final partial = {'@a:example': 1, '@b:example': 6};
    expect(
      membersWhoRead(messageIndex: 3, receiptIndexByMember: partial, otherJoinedMemberIds: members),
      ['@a:example'],
    );
    expect(
      everyoneJoinedHasRead(messageIndex: 3, receiptIndexByMember: partial, otherJoinedMemberIds: members),
      isFalse,
    );
    expect(
      everyoneJoinedHasRead(
        messageIndex: 3,
        receiptIndexByMember: {'@a:example': 2, '@b:example': 3},
        otherJoinedMemberIds: members,
      ),
      isTrue,
    );
    expect(
      everyoneJoinedHasRead(messageIndex: 0, receiptIndexByMember: const {}, otherJoinedMemberIds: const []),
      isFalse,
    );
  });

  testWidgets('Zustände zeigen Uhr, einen Haken, Eulen und den Fehler', (tester) async {
    Future<void> show(OutboundDelivery state, {bool blink = false, VoidCallback? onRetry}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: hoobirdTheme(Brightness.light),
          darkTheme: hoobirdTheme(Brightness.dark),
          home: Scaffold(body: DeliveryMark(state: state, blink: blink, onRetry: onRetry)),
        ),
      );
    }

    await show(OutboundDelivery.sending);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.bySemanticsLabel('Wird gesendet'), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);

    await show(OutboundDelivery.sent);
    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.bySemanticsLabel('Gesendet'), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);

    await show(OutboundDelivery.read);
    expect(find.byKey(const Key('owl-eyes')), findsOneWidget);
    expect(find.bySemanticsLabel('Gelesen'), findsOneWidget);
    expect(find.byIcon(Icons.done), findsNothing);

    var retried = 0;
    await show(OutboundDelivery.failed, onRetry: () => retried++);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.bySemanticsLabel('Senden fehlgeschlagen'), findsOneWidget);
    expect(find.byTooltip('Erneut senden'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.error_outline));
    expect(retried, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: hoobirdTheme(Brightness.dark),
        home: const Scaffold(body: DeliveryMark(state: OutboundDelivery.read)),
      ),
    );
    expect(find.byKey(const Key('owl-eyes')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Die Eule blinzelt einmal, wenn der Zustand auf gelesen wechselt', (tester) async {
    var blink = false;
    var state = OutboundDelivery.sent;
    await tester.pumpWidget(
      MaterialApp(
        theme: hoobirdTheme(Brightness.light),
        home: Scaffold(
          body: DeliveryMark(state: state, blink: blink),
        ),
      ),
    );
    blink = true;
    state = OutboundDelivery.read;
    await tester.pumpWidget(
      MaterialApp(
        theme: hoobirdTheme(Brightness.light),
        home: Scaffold(body: DeliveryMark(state: state, blink: blink)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('owl-eyes')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('owl-eyes')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
