# Risk check: voice capture, all common Android phones

Written before the code change. The phone that failed is a Xiaomi 14 (HyperOS, Android 15). The same pipeline has to run on Samsung One UI, Pixel, Oppo/OnePlus/Realme ColorOS, Motorola, and Huawei/Honor without Play services, from the app's minSdk through Android 15 and 16.

This file lists what can go wrong, how the code prevents or detects it, and which test or log line proves it. Status (verified / only-emulator / unverified-needs-device) is filled in the report after the build, not guessed here.

## Platform floor

minSdk is **24** (Android 7.0). compileSdk and targetSdk are **36** (Android 16). minSdk is 24 because Flutter 3.47 refuses a lower value, and because `AudioRecord.Builder` plus AAC/`MediaMuxer` are the capture path. API 24 and 25 have no `AudioFocusRequest`; those versions use the older `requestAudioFocus` with the same exclusive-transient gain. Android 15 is API 35. Android 16 is API 36, which this binary targets but does not claim to have been run on.

ABIs in the debug set: `arm64-v8a` (phones since about 2017), `armeabi-v7a` (older 32-bit phones), `x86_64` (the emulator). No feature uses Google Play services. Maps, FCM, and Play Integrity are not dependencies. `camera` and `image_picker` use the platform camera APIs. Huawei and Honor without GMS are in scope for that reason, and still need a device.

## Risks

| Risk | What goes wrong | Prevention or detection | Proof |
| --- | --- | --- | --- |
| OEM mic returns digital zeros | HyperOS (and some ColorOS builds) can hand MediaRecorder a valid AAC file of zeros while AudioService says the mic is not silenced. | PCM is read with AudioRecord. The first 400 ms of zeros, a source that is not recording, or `isClientSilenced` drops that source and tries the next. Order: `VOICE_RECOGNITION`, `MIC`, `DEFAULT`, `CAMCORDER`. An all-zero file is not sent. | `probe source=... max=0` then `source kept` or `all probes were zero`. Decision `send=false` when `pcmMax=0` or `fileMax=0`. Unit: `probeShouldRetry`, `failClosedLoudness`. Emulator: `avd hostmicoff`. |
| Silence gate fails open | A long file used to be sent when the RMS decode path failed. | Send only if the file decoded, both peaks are above 0, and both RMS values are at least 0.01. Decode failure becomes peak 0. | `decision ... fileDecoded=false send=false` or `send=false` with `fileRms` under 0.01. Unit: `voiceTakeRejection`, `voiceSendAllowed`. |
| Sample rate or channel the HAL rejects | Assuming 48000 mono fails on devices that only open 16000 or stereo. | Candidates are 48000, 44100, 16000, mono then stereo. A format is used only when `AudioRecord.getMinBufferSize` returns a positive size. Stereo is downmixed to mono before the encoder and the meter. | `formats 48000/1,...` and `opened source=... rate=... channels=...`. Unit: `supportedCaptureFormats` skips a non-positive buffer. |
| No AAC encoder, or LC profile refused | Some HALs have no `c2.android.aac.encoder`, or reject `AACObjectLC`. | Try each AAC encoder as LC, then HE, then with no profile, then Opus in WebM, then raw PCM in a WAV file. Each failure is logged. WAV loudness is measured from the file we wrote, not from a codec. | `encoder failed name=...`, then `encoder chosen` or `encoder none, wav pcm`. Unit: `encoderAttempts` order and the empty-list WAV fallback. `wavLoudness` on zeros and on a tone. |
| Encoder or muxer throws mid-take | A started codec can fail on `configure`, `queue`, or `stop`. | The exception is caught, logged, and the take is not sent unless a finished file still decodes above the floor. A WAV header is rewritten when the take stops so an interrupted PCM file can still be measured. | `encode failed ...` or `muxer stop ...`. Decision `send=false` when the file does not decode. |
| Buffer overrun turns the rest of the take into zeros | Encoding on the mic thread overflows a tiny HAL buffer. | The mic is read on `HooBirdVoiceRead`. The AudioRecord buffer is at least one second (`max(minBuffer*2, one second)`). | Ticks stay non-zero on a live mic. `capture queue full` if the encoder falls behind. |
| Permission and AppOps | Denied, or HyperOS `MODE_FOREGROUND` mistaken for a block. | `RECORD_AUDIO` is requested. Only an actual denial blocks the start. `MODE_FOREGROUND` is logged and not treated as a block. Zeros afterwards are rejected by the gate. | `start requested ... ops=`. Mic test: `Mikrofon nicht erlaubt`. |
| Another app holds the mic, or a call starts | Focus loss or a silenced client. | `AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE` before start, released after. Focus loss stops the take. `isClientSilenced` retries the next source. Usage is `MEDIA`, not voice-communication, because a communication path has produced zeros on HyperOS. | `audio focus result=1`, `audio focus change`, `focus lost, stopping`, `client silenced`. |
| Bluetooth headset | SCO can be off, so the headset mic is silent, or forcing SCO mutes the phone mic on some Xiaomi builds. | SCO is not forced. The route is logged. A silent probe tries the next source. The phone mic remains the default. | `route sco= a2dp=`. A silent headset is `send=false` or a later source with a non-zero probe. |
| Background, lock, or leaving the app | A take that continues in the background often becomes zeros. | Start is refused unless the activity is resumed. `onPause` stops the mic and logs it. A take under one second is `too_short`. | `start refused activity not resumed`. `pause while recording, releasing the mic`. |
| Very short or very long take | A tap sends noise. A long take fills storage, especially as WAV. | Under 1000 ms or under 1024 bytes is rejected. The reader stops at 180000 ms. | `take reason=too_short`. `max duration`. |
| Storage full | `MediaMuxer` or the WAV file throws, and a partial file must not be sent. | Start is refused when fewer than 8 MB are free. A write error leaves `decoded=false`. | `storage low`. `encode failed` / `wav write failed` and `send=false`. |
| Decode failure | The partner receives a file we could not read back. | The gate requires a successful decode. WAV is parsed in-process. AAC/Opus go through `MediaExtractor`. | `decode failed` or `wav header bad`, then `send=false`. |
| Logs stripped | A release shrinker or a filtered logcat hides `HooBirdVoice`. | This artifact is a debug APK. `Log.i` and `Log.w` are used, and Dart prints the same line. The first line reports `debug=true`. | `adb logcat -s HooBirdVoice:I HooBirdVoice:W` shows `debug=true`, ticks, and `decision`. |
| Play services missing | Huawei/Honor without GMS cannot start a feature that links Play services. | No Play services, FCM, or Play Integrity dependency. | Manifest and the APK contain no `com.google.android.gms`. |
| 32-bit, x86 emulator, low RAM | An arm64-only APK does not install on armeabi-v7a. A one-second PCM buffer is small (96 KB at 48000 mono). | Split debug APKs: arm64-v8a, armeabi-v7a, x86_64. | `libflutter.so` lives in only one ABI directory per APK. |
| Small screen, large font, dark mode, gesture navigation | The mic test or the hold button clips or disappears. | The mic test is a scrollable list. The hold control is the existing one. | Emulator: font scale 1.3 and the in-app dark theme still show the mic-test actions. Gesture vs 3-button and real OEM skins are device checks. |

## Result of this run

No physical phone was attached. The only installed system image is android-35 (x86_64). API 24 and API 36 were not run.

| Risk | Status |
| --- | --- |
| OEM mic returns digital zeros | Unit: exact zeros are rejected. Emulator `hostmicoff`: `send=false` (`fileRms` about 0.0008). That run still had a short peak (`pcmMax=5775`), so it is not a pure-zero HAL. Xiaomi, ColorOS, and every other phone: unverified-needs-device. |
| Silence gate fails open | Unit tests. Emulator tone `send=true`, silence `send=false`. |
| Sample rate or channel the HAL rejects | Unit: a non-positive `getMinBufferSize` is skipped. Emulator opened `48000` mono. 44100, 16000, and stereo were not the HAL's choice. Other phones: unverified-needs-device. |
| No AAC encoder | Unit: LC, then HE, then no profile, then Opus/WebM, then WAV. Emulator chose `c2.android.aac.encoder` profile `lc`. A device with no AAC encoder was not run. |
| Encoder or muxer throws mid-take | Unit covers the fallback order. A live codec failure was not injected. |
| Buffer overrun | Emulator: ticks continued and the decision used the whole take. Ranchu still fills the tail with zeros after a few hundred milliseconds. `capture queue full` did not appear. |
| Permission and AppOps | unverified-needs-device. The emulator grants the permission. |
| Focus loss or a call | Emulator: leaving the app logged `pause while recording, releasing the mic` and then a decision. A phone call and another app taking the mic were not run. |
| Bluetooth headset | unverified-needs-device. Emulator logged `route sco=false a2dp=false`. SCO is not forced. |
| Background or lock | only-emulator, via Home during the mic test. Screen lock was not run. |
| Very short or very long take | Under one second is covered by the Dart test. The 180 s cap is a unit check (`shouldStopForLength`), not a three-minute recording. |
| Storage full | Unit: under 8 MB refuses the start. A full disk was not injected. |
| Decode failure | Unit: a broken WAV and an all-zero WAV are not sent. Emulator files decoded. |
| Logs stripped | only-emulator: `channel ready debug=true`, ticks, and `decision` are in logcat. |
| Play services missing | The tree and the three APKs contain no `com.google.android.gms`. |
| 32-bit, x86, low RAM | The three split APKs each contain `libflutter.so` for one ABI. x86_64 ran on the API 35 emulator. armeabi-v7a and a low-RAM phone were not installed. |
| Font, dark mode, navigation | only-emulator: font scale 1.3 and system dark mode still show record, playback, and copy on Mikrofontest (1080x2400, gesture bar). 3-button navigation, small phones, and tablets: unverified-needs-device. |

Unverified device families: Samsung One UI, Xiaomi HyperOS/MIUI, Pixel, Oppo/OnePlus/Realme ColorOS, Motorola, Huawei/Honor without Play services, Android 7, Android 16, armeabi-v7a hardware, Bluetooth headsets.

## One pass on the phone

Install the ABI that matches the phone (`hoobird-arm64-v8a-debug-testserver-7.apk` on the Xiaomi 14). `adb logcat -s HooBirdVoice:I HooBirdVoice:W` stays open for the whole pass.

1. Cold start. Expect `channel ready debug=true`.
2. Einstellungen, Mikrofontest. Speak for the three seconds. Expect `formats`, `encoder chosen` (or `encoder none, wav pcm`), `opened` with rate and channels, `probe` with `max` above 0, ticks with `amp` above 0, `decision ... send=true`, and `accept` on screen. Copy the diagnostic. Play it back.
3. Cover the mic or deny the mic in the system settings, run the three seconds again. Expect `send=false` and no "accept". Restore the permission.
4. Start the three seconds and press Home after about a second. Expect `pause while recording, releasing the mic`.
5. Start a take and place a phone call, or start another app that records. Expect `focus lost, stopping` or `client silenced`, then `send=false` if the file is quiet.
6. Connect a Bluetooth headset, record once, and read `route sco=` / `a2dp=`. The note must be the voice you spoke, not silence. Hang up the headset and record once more from the phone mic.
7. Lock the screen during a take, then unlock. The mic must have stopped. A take under one second says "Zu kurz".
8. In the chat, hold, lock, and cancel once each. A real sentence must play back on the other account as audio, not as a silent file.
