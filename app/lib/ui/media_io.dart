// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/services.dart';

class MediaIo {
  static const _methods = MethodChannel('dev.hoobird.spike.hoobird/media');

  static Future<void> saveJpeg(Uint8List bytes) {
    return _methods.invokeMethod<void>('saveJpeg', {'bytes': bytes});
  }

  static Future<void> shareJpeg(Uint8List bytes) {
    return _methods.invokeMethod<void>('shareJpeg', {'bytes': bytes});
  }
}
