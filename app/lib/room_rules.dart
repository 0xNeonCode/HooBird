// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

/// Room admin is power 50 or more. Toggling takes that away or grants it.
bool isRoomAdmin(int level) => level >= 50;

int toggledAdminPower(int level) => isRoomAdmin(level) ? 0 : 50;

String powerLabel(int level) {
  if (level > 100) return 'Ersteller';
  if (level >= 50) return 'Verwaltung';
  return 'Stufe $level';
}

/// Contacts whose effective approval is on. A parent block sets effective off
/// and therefore drops the contact, even if another parent had approved them.
Set<String> approvedContactIds(Object? contacts) {
  final allowed = <String>{};
  if (contacts is List) {
    for (final row in contacts.whereType<Map>()) {
      if (row['effective'] == true) allowed.add('${row['user_id']}');
    }
  }
  return allowed;
}

/// Null when the invite may proceed. A child may invite only an approved contact.
String? childInviteBlock({
  required bool isChild,
  required Set<String> approved,
  required String userId,
}) {
  if (!isChild) return null;
  if (approved.contains(userId)) return null;
  return 'Ein Kinderkonto lädt nur freigegebene Kontakte ein.';
}

/// Mention text inserted into the composer. The user id is the plaintext token
/// inside the encrypted message. The server does not see it as a mention field.
String mentionInsertion({required String current, required String userId}) {
  if (current.isEmpty) return '$userId ';
  return '$current $userId ';
}
