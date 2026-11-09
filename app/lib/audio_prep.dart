// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:convert';
import 'dart:typed_data';

class AudioPrepException implements Exception {
  AudioPrepException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _dropBoxes = {'udta', 'meta', 'uuid', 'free', 'skip', 'ilst'};
const _containerBoxes = {'moov', 'trak', 'mdia', 'minf', 'stbl', 'edts', 'dinf', 'mvex', 'moof', 'traf'};

/// Remove MP4 boxes that can carry a tool name, a cover, or location.
///
/// The audio samples in `mdat` stay as MediaRecorder wrote them. This does not
/// re-encode. A file that is not an `ftyp` MP4 is rejected.
Uint8List stripMp4Metadata(Uint8List data) {
  if (data.length < 12) {
    throw AudioPrepException('Die Aufnahme ist kein gültiges AAC. Sie wurde nicht gesendet.');
  }
  final type = ascii.decode(data.sublist(4, 8), allowInvalid: true);
  if (type != 'ftyp') {
    throw AudioPrepException('Die Aufnahme ist kein gültiges AAC. Sie wurde nicht gesendet.');
  }
  final stripped = _rewrite(data);
  if (stripped.length < 8 || ascii.decode(stripped.sublist(4, 8)) != 'ftyp') {
    throw AudioPrepException('Die Aufnahme ist beschädigt. Sie wurde nicht gesendet.');
  }
  return stripped;
}

Uint8List _rewrite(Uint8List data) {
  final out = BytesBuilder(copy: false);
  var index = 0;
  while (index + 8 <= data.length) {
    final size32 = _u32(data, index);
    var header = 8;
    var size = size32;
    if (size32 == 1) {
      if (index + 16 > data.length) {
        throw AudioPrepException('Die Aufnahme ist beschädigt. Sie wurde nicht gesendet.');
      }
      size = _u64(data, index + 8);
      header = 16;
    } else if (size32 == 0) {
      size = data.length - index;
    }
    if (size < header || index + size > data.length) {
      throw AudioPrepException('Die Aufnahme ist beschädigt. Sie wurde nicht gesendet.');
    }
    final boxType = ascii.decode(data.sublist(index + 4, index + 8), allowInvalid: true);
    if (_dropBoxes.contains(boxType)) {
      index += size;
      continue;
    }
    var body = data.sublist(index + header, index + size);
    if (_containerBoxes.contains(boxType)) {
      body = _rewrite(body);
    }
    final rewritten = 8 + body.length;
    out.add(_u32bytes(rewritten));
    out.add(ascii.encode(boxType));
    out.add(body);
    index += size;
  }
  if (index != data.length) {
    throw AudioPrepException('Die Aufnahme ist beschädigt. Sie wurde nicht gesendet.');
  }
  return out.toBytes();
}

int _u32(Uint8List data, int offset) {
  return (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
}

int _u64(Uint8List data, int offset) {
  var value = 0;
  for (var i = 0; i < 8; i++) {
    value = (value << 8) | data[offset + i];
  }
  return value;
}

/// Under a second is a slip. A tiny file has no audio payload.
const voiceMinimumMs = 1000;

/// AAC at 64 kbit/s is several kilobytes per second. Under this is not a take.
const voiceMinimumBytes = 1024;

/// Full-scale RMS. Encoder noise of a muted mic stays under this. Speech does not.
/// The UI peak is not used: HyperOS often reports amplitude 0 while the file has audio.
const voiceSilenceRms = 0.01;

String? voiceTakeRejection({
  required int byteLength,
  required int elapsedMs,
  required double rms,
  required bool decoded,
}) {
  if (elapsedMs < voiceMinimumMs) return 'too_short';
  if (byteLength < voiceMinimumBytes) return 'empty';
  if (decoded && rms < voiceSilenceRms) return 'silent';
  return null;
}

/// A short hold is a slip. An empty or decoded-silent file is a blocked mic.
/// A file that could not be decoded is sent when it is long enough, so a
/// decoder failure does not swallow a real message.
String voiceTakeHint(String reason) {
  if (reason == 'too_short') return 'Zu kurz. Halte die Taste etwas länger.';
  return 'Mikrofon blockiert. Nichts wurde gesendet.';
}

Uint8List _u32bytes(int value) {
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}
