// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio_prep.dart';
import '../voice_io.dart';

/// Hidden diagnostic. Records three seconds from the same pipeline as a voice
/// note and shows the source, the PCM peak, and whether that take would be sent.
class MicTestPage extends StatefulWidget {
  const MicTestPage({super.key});

  @override
  State<MicTestPage> createState() => _MicTestPageState();
}

class _MicTestPageState extends State<MicTestPage> {
  var _busy = false;
  var _level = 0.0;
  var _source = '';
  var _rate = 0;
  var _maxAbs = 0;
  var _rms = 0.0;
  var _elapsed = 0;
  String? _path;
  String _report = 'Noch keine Aufnahme.';

  @override
  void initState() {
    super.initState();
    VoiceIo.addListener(_onEvent);
  }

  @override
  void dispose() {
    VoiceIo.removeListener(_onEvent);
    if (_busy) unawaited(VoiceIo.stop());
    super.dispose();
  }

  void _onEvent(Map<String, Object?> event) {
    if (!mounted || event['kind'] != 'recording') return;
    final amplitude = event['amplitude'];
    final elapsed = event['elapsedMs'];
    final maxAbs = event['maxAbs'];
    final rms = event['rms'];
    final rate = event['sampleRate'];
    setState(() {
      if (amplitude is num) _level = amplitude.toDouble().clamp(0.0, 1.0);
      if (elapsed is num) _elapsed = elapsed.toInt();
      if (maxAbs is num) _maxAbs = maxAbs.toInt();
      if (rms is num) _rms = rms.toDouble();
      if (rate is num) _rate = rate.toInt();
      _source = '${event['source'] ?? _source}';
    });
  }

  Future<void> _record() async {
    if (_busy || !VoiceIo.supported) return;
    setState(() {
      _busy = true;
      _level = 0;
      _report = 'Aufnahme läuft…';
    });
    try {
      final status = await VoiceIo.permission();
      if (status != 'granted') {
        setState(() => _report = 'Mikrofon nicht erlaubt ($status).');
        return;
      }
      final directory = await getTemporaryDirectory();
      final path = p.join(directory.path, 'hoobird-mic-test.m4a');
      _path = path;
      await VoiceIo.start(path);
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) {
        await VoiceIo.stop();
        return;
      }
      final take = await VoiceIo.stop();
      final file = File(path);
      final length = file.existsSync() ? file.lengthSync() : take.bytes;
      final reason = voiceTakeRejection(
        byteLength: length,
        elapsedMs: take.elapsedMs,
        rms: take.rms,
        decoded: take.decoded,
        maxAbs: take.maxAbs,
      );
      final decision = reason ?? 'accept';
      final report = [
        'HooBird Mikrofontest',
        'decision=$decision',
        'source=${take.source}',
        'sampleRate=${take.sampleRate}',
        'elapsedMs=${take.elapsedMs}',
        'bytes=$length',
        'pcmMax=${take.pcmMaxAbs}',
        'pcmRms=${take.pcmRms}',
        'fileDecoded=${take.fileDecoded}',
        'fileMax=${take.fileMaxAbs}',
        'fileRms=${take.fileRms}',
        'gateMax=${take.maxAbs}',
        'gateRms=${take.rms}',
        'decoded=${take.decoded}',
      ].join('\n');
      await VoiceIo.log('mictest $decision');
      if (!mounted) return;
      setState(() {
        _source = take.source;
        _rate = take.sampleRate;
        _maxAbs = take.pcmMaxAbs;
        _rms = take.pcmRms;
        _elapsed = take.elapsedMs;
        _report = report;
      });
    } catch (exc) {
      if (mounted) setState(() => _report = 'Aufnahme fehlgeschlagen: $exc');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _play() async {
    final path = _path;
    if (path == null || !File(path).existsSync()) return;
    try {
      await VoiceIo.play(path, 1);
    } catch (exc) {
      if (mounted) setState(() => _report = '$_report\nWiedergabe fehlgeschlagen: $exc');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mikrofontest')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Drei Sekunden über denselben Weg wie eine Sprachnachricht. Nichts wird gesendet. Eine Aufnahme aus lauter Nullen darf hier nicht als „accept“ stehen.',
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: _level, minHeight: 14),
          ),
          const SizedBox(height: 12),
          Text('Quelle $_source'),
          Text('Abtastrate $_rate Hz'),
          Text('Zeit $_elapsed ms'),
          Text('Pegelspitze $_maxAbs'),
          Text('RMS $_rms'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _record,
            child: Text(_busy ? 'Nimmt auf…' : '3 Sekunden aufnehmen'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : _play, child: const Text('Wiedergabe')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _report));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diagnose kopiert.')));
            },
            child: const Text('Diagnose kopieren'),
          ),
          const SizedBox(height: 16),
          SelectableText(_report),
        ],
      ),
    );
  }
}
