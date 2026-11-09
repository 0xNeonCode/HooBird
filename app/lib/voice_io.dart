// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Android microphone and playback. Other platforms have no recorder here.
class VoiceIo {
  static const _methods = MethodChannel('dev.hoobird.spike.hoobird/voice');
  static const _events = EventChannel('dev.hoobird.spike.hoobird/voice_events');

  static bool get supported => Platform.isAndroid;

  static Stream<Map<String, Object?>> get events {
    return _events.receiveBroadcastStream().map((event) {
      final raw = event as Map;
      return raw.map((key, value) => MapEntry('$key', value));
    });
  }

  static Future<String> permission() async {
    final value = await _methods.invokeMethod<String>('permission');
    return value ?? 'denied';
  }

  static Future<void> openSettings() {
    return _methods.invokeMethod<void>('openSettings');
  }

  static Future<void> start(String path) {
    return _methods.invokeMethod<void>('start', {'path': path});
  }

  static Future<int> stop() async {
    final value = await _methods.invokeMethod<int>('stop');
    return value ?? 0;
  }

  static Future<int> play(String path, double speed) async {
    final value = await _methods.invokeMethod<int>('play', {'path': path, 'speed': speed});
    return value ?? 0;
  }

  static Future<void> pause() => _methods.invokeMethod<void>('pause');

  static Future<void> resume() => _methods.invokeMethod<void>('resume');

  static Future<void> speed(double value) {
    return _methods.invokeMethod<void>('speed', {'speed': value});
  }

  static Future<void> stopPlayback() => _methods.invokeMethod<void>('stopPlayback');
}
