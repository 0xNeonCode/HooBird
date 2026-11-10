// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/room_rules.dart';

void main() {
  test('Verwaltung wird gegeben und entzogen', () {
    expect(isRoomAdmin(0), isFalse);
    expect(isRoomAdmin(50), isTrue);
    expect(toggledAdminPower(0), 50);
    expect(toggledAdminPower(100), 0);
    expect(powerLabel(50), 'Verwaltung');
    expect(powerLabel(0), 'Stufe 0');
  });

  test('Ein Kind lädt nur frei, und eine Elternsperre gewinnt', () {
    final approved = approvedContactIds([
      {'user_id': '@ok:example', 'effective': true},
      {'user_id': '@blocked:example', 'effective': false},
    ]);
    expect(approved, {'@ok:example'});
    expect(childInviteBlock(isChild: false, approved: approved, userId: '@blocked:example'), isNull);
    expect(childInviteBlock(isChild: true, approved: approved, userId: '@ok:example'), isNull);
    expect(
      childInviteBlock(isChild: true, approved: approved, userId: '@blocked:example'),
      'Ein Kinderkonto lädt nur freigegebene Kontakte ein.',
    );
  });

  test('Eine Erwähnung hängt die Kennung an den Text', () {
    expect(mentionInsertion(current: '', userId: '@ada:example'), '@ada:example ');
    expect(mentionInsertion(current: 'Hallo', userId: '@ada:example'), 'Hallo @ada:example ');
  });
}
