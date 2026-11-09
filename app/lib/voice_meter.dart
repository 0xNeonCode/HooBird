// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

/// Levels for the recording meter. A fake recorder in tests feeds the same
/// events the Android EventChannel sends: kind, elapsedMs, amplitude.
class VoiceMeter {
  var recording = false;
  var elapsedMs = 0;
  final levels = <double>[];
  var peak = 0.0;

  void reset() {
    elapsedMs = 0;
    levels.clear();
    peak = 0;
  }

  void apply(Map<String, Object?> event) {
    if (!recording || event['kind'] != 'recording') return;
    final elapsed = event['elapsedMs'];
    final amplitude = event['amplitude'];
    if (elapsed is num) elapsedMs = elapsed.toInt();
    if (amplitude is num) {
      final level = amplitude.toDouble().clamp(0.0, 1.0);
      levels.add(level);
      if (level > peak) peak = level;
    }
  }
}
