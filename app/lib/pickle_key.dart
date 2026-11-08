// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:typed_data';

/// Same padding as matrix 16.0.1 `encryption/utils/pickle_key.dart`.
///
/// The SDK unpickles with the user id. This copy exists because that
/// extension is not exported. It does not define a new key algorithm.
Uint8List pickleKeyOf(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final missing = 32 - bytes.length;
  if (missing > 0) {
    return Uint8List.fromList([...bytes, ...List.filled(missing, 0)]);
  }
  return Uint8List.fromList(bytes.getRange(0, 32).toList());
}
