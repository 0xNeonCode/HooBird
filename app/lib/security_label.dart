// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

/// Wording for the two states the product must not collapse into one.
/// Callers pass values taken from the Matrix SDK, not a decorative flag.
String securityLabel({
  required bool encrypted,
  required bool identityVerified,
}) {
  if (!encrypted) {
    return 'Nicht verschlüsselt';
  }
  if (identityVerified) {
    return 'Verschlüsselt · Identität verifiziert';
  }
  return 'Verschlüsselt · Identität nicht verifiziert';
}
