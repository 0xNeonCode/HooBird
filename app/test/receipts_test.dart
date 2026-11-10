// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/receipts.dart';
import 'package:hoobird/ui/delivery.dart';
import 'package:matrix/matrix.dart';

void main() {
  test('Öffentlich ist m.read, privat ist m.read.private', () {
    expect(publicReceiptType, 'm.read');
    expect(privateReceiptType, 'm.read.private');
    expect(publicReceiptType.contains('private'), isFalse);

    final off = receiptPlan(sendReceipts: false);
    expect(off.publicRead, isFalse);
    expect(off.privateRead, isTrue);

    final on = receiptPlan(sendReceipts: true);
    expect(on.publicRead, isTrue);
    expect(on.privateRead, isTrue);
  });

  test('Aus blendet den Lesestand, an listet Leser und Wartende', () {
    expect(
      readerLines(sendReceipts: false, readers: const ['@a:example'], waiting: const ['@b:example']).map((line) => line.kind),
      [ReaderLineKind.off],
    );
    final on = readerLines(
      sendReceipts: true,
      readers: const ['@a:example'],
      waiting: const ['@b:example'],
    );
    expect(on.map((line) => line.kind), [ReaderLineKind.read, ReaderLineKind.waiting]);
    expect(on.map((line) => line.userId), ['@a:example', '@b:example']);
    expect(
      readerLines(sendReceipts: true, readers: const [], waiting: const ['@b:example']).first.kind,
      ReaderLineKind.none,
    );
  });

  test('Die Eule braucht die Anzeige und dass alle gelesen haben', () {
    expect(outboundDelivery(status: EventStatus.synced, showRead: false), OutboundDelivery.sent);
    expect(outboundDelivery(status: EventStatus.synced, showRead: true), OutboundDelivery.read);
    const members = ['@a:example', '@b:example'];
    expect(
      everyoneJoinedHasRead(
        messageIndex: 2,
        receiptIndexByMember: const {'@a:example': 1, '@b:example': null},
        otherJoinedMemberIds: members,
      ),
      isFalse,
    );
    expect(
      everyoneJoinedHasRead(
        messageIndex: 2,
        receiptIndexByMember: const {'@a:example': 1, '@b:example': 2},
        otherJoinedMemberIds: members,
      ),
      isTrue,
    );
  });
}
