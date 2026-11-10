// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of stopping a take. Silence is [rms] from the decoded file.
class VoiceTake {
  const VoiceTake({
    required this.elapsedMs,
    required this.bytes,
    required this.rms,
    required this.decoded,
    required this.maxAbs,
    this.source = '',
    this.sampleRate = 0,
    this.pcmMaxAbs = 0,
    this.pcmRms = 0,
    this.fileMaxAbs = 0,
    this.fileRms = 0,
    this.fileDecoded = false,
    this.container = '',
    this.mime = '',
    this.path = '',
  });

  final int elapsedMs;
  final int bytes;
  final double rms;
  final bool decoded;
  final int maxAbs;
  final String source;
  final int sampleRate;
  final int pcmMaxAbs;
  final double pcmRms;
  final int fileMaxAbs;
  final double fileRms;
  final bool fileDecoded;
  final String container;
  final String mime;
  final String path;
}

/// Android microphone and playback. Other platforms have no recorder here.
///
/// One EventChannel subscription is kept for the process. Creating a new
/// `receiveBroadcastStream` per listener races listen/cancel and clears the
/// native sink, so amplitude events never arrive and the meter stays empty.
class VoiceIo {
  static const _methods = MethodChannel('dev.hoobird.spike.hoobird/voice');
  static const _events = EventChannel('dev.hoobird.spike.hoobird/voice_events');

  static final _listeners = <void Function(Map<String, Object?>)>{};
  static StreamSubscription<dynamic>? _subscription;
  static Future<void>? _opening;

  static bool get supported => Platform.isAndroid;

  static Map<String, Object?> parseEvent(Object? event) {
    if (event is! Map) return const {'kind': 'ignored'};
    return {for (final entry in event.entries) '${entry.key}': entry.value};
  }

  static void addListener(void Function(Map<String, Object?> event) listener) {
    _listeners.add(listener);
  }

  static void removeListener(void Function(Map<String, Object?> event) listener) {
    _listeners.remove(listener);
  }

  /// Test hook. The widget tests push the same maps the channel would.
  @visibleForTesting
  static void debugDispatch(Object? event) => _dispatch(event);

  @visibleForTesting
  static void debugReset() {
    _listeners.clear();
  }

  static void _dispatch(Object? event) {
    final parsed = parseEvent(event);
    if (parsed['kind'] == 'recording') {
      // ignore: avoid_print
      print(
        'HooBirdVoice tick amp=${parsed['amplitude']} source=${parsed['source']} rate=${parsed['sampleRate']} max=${parsed['maxAbs']} rms=${parsed['rms']} elapsed=${parsed['elapsedMs']}',
      );
    }
    for (final listener in List<void Function(Map<String, Object?>)>.of(_listeners)) {
      try {
        listener(parsed);
      } catch (_) {}
    }
  }

  static Future<void> ensureListening() {
    if (!supported) return Future<void>.value();
    return _opening ??= _listen();
  }

  static Future<void> _listen() async {
    _subscription ??= _events.receiveBroadcastStream().listen(
      _dispatch,
      onError: (Object error) {
        unawaited(log('event stream error $error'));
      },
    );
    if (_subscription == null) return;
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        final ready = await _methods.invokeMethod<bool>('eventsReady');
        if (ready == true) {
          await log('listen ready');
          return;
        }
      } on PlatformException {
        // The activity may still be registering the channel.
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await log('listen not ready, sink stayed null');
  }

  static Future<void> log(String message) async {
    // ignore: avoid_print
    print('HooBirdVoice $message');
    if (!supported) return;
    try {
      await _methods.invokeMethod<void>('log', {'message': message});
    } on PlatformException {
      // Logging must not break a take.
    }
  }

  static Future<String> permission() async {
    final value = await _methods.invokeMethod<String>('permission');
    return value ?? 'denied';
  }

  static Future<void> openSettings() {
    return _methods.invokeMethod<void>('openSettings');
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static double _double(Object? value) => value is num ? value.toDouble() : 0;

  static Future<void> start(String path) async {
    await log('start requested');
    await ensureListening();
    await _methods.invokeMethod<void>('start', {'path': path});
    await log('start returned');
  }

  static Future<VoiceTake> stop() async {
    final value = await _methods.invokeMethod<dynamic>('stop');
    if (value is Map) {
      final take = VoiceTake(
        elapsedMs: _int(value['elapsedMs']),
        bytes: _int(value['bytes']),
        rms: _double(value['rms']),
        decoded: value['decoded'] == true,
        maxAbs: _int(value['maxAbs']),
        source: '${value['source'] ?? ''}',
        sampleRate: _int(value['sampleRate']),
        pcmMaxAbs: _int(value['pcmMaxAbs']),
        pcmRms: _double(value['pcmRms']),
        fileMaxAbs: _int(value['fileMaxAbs']),
        fileRms: _double(value['fileRms']),
        fileDecoded: value['fileDecoded'] == true,
        container: '${value['container'] ?? ''}',
        mime: '${value['mime'] ?? ''}',
        path: '${value['path'] ?? ''}',
      );
      await log(
        'stop source=${take.source} rate=${take.sampleRate} bytes=${take.bytes} elapsed=${take.elapsedMs} pcmMax=${take.pcmMaxAbs} pcmRms=${take.pcmRms} fileMax=${take.fileMaxAbs} fileRms=${take.fileRms} fileDecoded=${take.fileDecoded} container=${take.container} gateMax=${take.maxAbs} gateRms=${take.rms} decoded=${take.decoded}',
      );
      return take;
    }
    if (value is int) {
      return VoiceTake(elapsedMs: value, bytes: 0, rms: 0, decoded: false, maxAbs: 0);
    }
    return const VoiceTake(elapsedMs: 0, bytes: 0, rms: 0, decoded: false, maxAbs: 0);
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
