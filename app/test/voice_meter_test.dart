// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/ui/voice_hold.dart';
import 'package:hoobird/voice_io.dart';
import 'package:hoobird/voice_meter.dart';

void main() {
  test('Ein nachgebauter Rekorder hebt den Pegel, eine Null davor nicht', () {
    final meter = VoiceMeter()..recording = true;
    meter.apply({'kind': 'recording', 'elapsedMs': 200, 'amplitude': 0});
    expect(meter.peak, 0);
    expect(meter.elapsedMs, 200);
    meter.apply({'kind': 'recording', 'elapsedMs': 400, 'amplitude': 0.42});
    expect(meter.peak, 0.42);
    expect(meter.levels, [0, 0.42]);
    expect(meter.elapsedMs, 400);
  });

  test('Ereignisse vor der Aufnahme zählen nicht', () {
    final meter = VoiceMeter();
    meter.apply({'kind': 'recording', 'elapsedMs': 200, 'amplitude': 0.9});
    expect(meter.levels, isEmpty);
    expect(meter.peak, 0);
  });

  test('Die Ereignisleitung erreicht den Zuhörer', () {
    VoiceIo.debugReset();
    final meter = VoiceMeter()..recording = true;
    void listener(Map<String, Object?> event) => meter.apply(event);
    VoiceIo.addListener(listener);
    VoiceIo.debugDispatch({'kind': 'recording', 'elapsedMs': 1500, 'amplitude': 0.55});
    expect(meter.elapsedMs, 1500);
    expect(meter.peak, 0.55);
    VoiceIo.removeListener(listener);
    VoiceIo.debugDispatch({'kind': 'recording', 'elapsedMs': 2000, 'amplitude': 0.9});
    expect(meter.peak, 0.55);
    VoiceIo.debugReset();
  });

  test('Kanalereignisse werden in Textschlüssel übersetzt', () {
    expect(
      VoiceIo.parseEvent({'kind': 'recording', 'elapsedMs': 10, 'amplitude': 0.1}),
      {'kind': 'recording', 'elapsedMs': 10, 'amplitude': 0.1},
    );
    expect(VoiceIo.parseEvent('nein'), {'kind': 'ignored'});
  });

  testWidgets('Die Wellenform steht, sobald der nachgebaute Rekorder Pegel schickt', (tester) async {
    final meter = VoiceMeter()..recording = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  VoiceRecordingChrome(
                    clock: '0:${(meter.elapsedMs / 1000).floor().toString().padLeft(2, '0')}',
                    levels: List<double>.from(meter.levels),
                    locked: false,
                  ),
                  TextButton(
                    onPressed: () {
                      const fake = <Map<String, Object?>>[
                        {'kind': 'recording', 'elapsedMs': 200, 'amplitude': 0},
                        {'kind': 'recording', 'elapsedMs': 1700, 'amplitude': 0.7},
                      ];
                      for (final event in fake) {
                        meter.apply(event);
                      }
                      setState(() {});
                    },
                    child: const Text('Rekorder'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    expect(find.byType(VoiceRecordingChrome), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    await tester.tap(find.text('Rekorder'));
    await tester.pump();
    expect(find.text('0:01'), findsOneWidget);
    expect(meter.levels.length, 2);
    expect(meter.peak, 0.7);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
