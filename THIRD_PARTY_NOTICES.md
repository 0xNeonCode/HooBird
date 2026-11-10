# Drittkomponenten

Inventar, erzeugt von `scripts/license_inventory.py`. Es übernimmt Lizenzfelder und Copyright-Zeilen aus den gelesenen Dateien der festgenagelten Versionen. Wo keine Datei gelesen oder die Prüfsumme nicht bestätigt wurde, steht UNKNOWN. Dieses Inventar ist keine Rechtsberatung, keine Freigabe und keine Relizenzierung der genannten Werke. Ein fehlendes UNKNOWN ist keine Aussage, dass die Weitergabe rechtlich problemlos ist.

## Weitergabe der Kombination

Eigener Code: AGPL-3.0-or-later, siehe `COPYRIGHT.md`. `matrix` 16.0.1: in der Paketdatei `AGPL-3.0-or-later`, Copyright-Zeile `2019-Present Famedly GmbH`. `flutter_vodozemac` 0.9.0: der mitgelieferte Lizenztext ist die GNU AGPL Version 3. Eine eigene „or any later version“-Zeile der Urheber wurde in `pubspec.yaml` und ausserhalb dieses GNU-Textes nicht gefunden. Die Rust-Crate `vodozemac` 0.10.0 ist Apache-2.0, sofern die geprüfte Archiv-Checksumme das bestätigt.

Daraus folgt für die weitergebbare Kombination, als Lesart der vorliegenden Hinweise und nicht als Anwaltsmeinung: die Flutter-App, die eigenen Code, `matrix` und `flutter_vodozemac` zusammen ausliefert, bleibt an AGPL Version 3 gebunden, weil das Binding keine gelesene Erlaubnis für eine spätere AGPL-Version enthält. Die „or-later“-Erlaubnis des eigenen Codes und von `matrix` gilt für diese Dateien. Sie hebt die Bindung des Bindings nicht auf. Apache-2.0-Hinweise von `vodozemac` bleiben daneben stehen. Der Server aus eigenem Modul und Synapse unter der AGPL-Seite von `AGPL-3.0-or-later OR LicenseRef-Element-Commercial` kann unter AGPL-3.0 oder einer späteren Version weitergegeben werden, weil beide Seiten das vorsehen. Die kommerzielle Element-Alternative wurde nicht angenommen und nicht bezahlt. Wer Client und Server zusammen weitergibt, darf die Server-Erlaubnis nicht auf das Binding ausdehnen.

## Flutter- und Dart-SDK

Flutter-Revision in `app/.metadata`: `c197ca5199e9ee5661e865596c9c07294dfab51c`, Kanal stable. Die Datei `/opt/flutter/LICENSE` beginnt mit „Copyright 2014 The Flutter Authors“ und ist die BSD-3-Clause-Lizenz. Die von `flutter create` erzeugten Gerüste unter `app/android`, `app/linux` und `app/analysis_options.yaml` stammen aus diesem Werkzeug. Änderungen daran (Anwendungs-ID, `compileSdk` 36, Klartext nur für Loopback) sind Anpassungen dieses Prototyps. Die BSD-Hinweise des unveränderten Gerüsts bleiben.

Das mit dieser Flutter-Revision ausgelieferte Dart-SDK meldet `Dart SDK version: 3.13.7`. Die Datei `/opt/flutter/bin/cache/dart-sdk/LICENSE` beginnt mit „Copyright 2012, the Dart project authors.“ und ist eine BSD-Lizenz mit der Namensklausel für Google LLC. Eine davon getrennte NOTICE-Datei wurde nicht gefunden.

## Dart-Pakete aus app/pubspec.lock

Quelle der Version und des sha256: `app/pubspec.lock`. Lizenztext: lokale Kopie unter `~/.pub-cache/hosted/pub.dev/<name>-<version>/`, sofern vorhanden. Ein AGPL-Text ohne SPDX-Zeile ist hier `AGPL-3.0-text` und nicht automatisch „or-later“.

| Paket | Version | Einordnung | SPDX oder Hinweis im Paket | Copyright-Zeilen aus der Lizenzdatei, soweit vorhanden |
| --- | --- | --- | --- | --- |
| `archive` | 4.6.0 (sha256 `de5ac590b815…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2013-2021 Brendan Duncan. |
| `args` | 2.7.0 (sha256 `d0481093c50b…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013, the Dart project authors. |
| `async` | 2.13.1 (sha256 `e2eb0491ba5d…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2015, the Dart project authors. |
| `base58check` | 2.0.0 (sha256 `6c300dfc33e5…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2016 Dartcoin |
| `blurhash_dart` | 1.2.1 (sha256 `43955b6c2e30…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2020 Tobias Schwackenhofer |
| `boolean_selector` | 2.1.2 (sha256 `8aab1771e124…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2016, the Dart project authors. |
| `build_cli_annotations` | 2.1.1 (sha256 `e563c2e01de8…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2018 Kevin Moore |
| `canonical_json` | 1.1.3 (sha256 `618db0b1ea42…`) | Apache-2.0 | kein SPDX und kein license-Feld | keine Copyright-Zeile am Dateianfang ausser dem Lizenztext |
| `characters` | 1.4.1 (sha256 `faf38497bda5…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2019, the Dart project authors. |
| `clock` | 1.1.3 (sha256 `e51d50bca321…`) | Apache-2.0 | kein SPDX und kein license-Feld | keine Copyright-Zeile am Dateianfang ausser dem Lizenztext |
| `code_assets` | 1.2.1 (sha256 `bf394f466ba9…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2025, the Dart project authors. |
| `collection` | 1.19.1 (sha256 `2f5709ae4d3d…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2015, the Dart project authors. |
| `crypto` | 3.0.8 (sha256 `e3626ae62703…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2015, the Dart project authors. |
| `csslib` | 1.0.2 (sha256 `09bad715f418…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013, the Dart project authors. |
| `fake_async` | 1.3.3 (sha256 `5368f224a745…`) | Apache-2.0 | kein SPDX und kein license-Feld | keine Copyright-Zeile am Dateianfang ausser dem Lizenztext |
| `ffi` | 2.2.0 (sha256 `6d7fd8943126…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2019, the Dart project authors. |
| `file` | 7.0.1 (sha256 `a3b4f84adafe…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2017, the Dart project authors. All rights reserved. |
| `flutter` | SDK | Flutter/Dart SDK | siehe Abschnitt Flutter | — |
| `flutter_lints` | 6.0.0 (sha256 `3105dc8492f6…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors. All rights reserved. |
| `flutter_rust_bridge` | 2.13.0 (sha256 `ec69331e2335…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2021 fzyzcjy |
| `flutter_test` | SDK | Flutter/Dart SDK | siehe Abschnitt Flutter | — |
| `flutter_vodozemac` | 0.9.0 (sha256 `d2705fed826e…`) | AGPL-3.0-text | kein SPDX und kein license-Feld | keine Copyright-Zeile am Dateianfang ausser dem Lizenztext |
| `flutter_web_plugins` | SDK | Flutter/Dart SDK | siehe Abschnitt Flutter | — |
| `glob` | 2.2.0 (sha256 `218aeb56050c…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2014, the Dart project authors. |
| `hooks` | 2.0.2 (sha256 `9a62a50b50b7…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2025, the Dart project authors. |
| `html` | 0.15.7 (sha256 `43b67b8f4332…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2006-2012 The Authors |
| `html_unescape` | 2.0.0 (sha256 `15362d7a18f1…`) | BSD-like | kein SPDX und kein license-Feld | Copyright (c) 2018, Filip Hracek. |
| `http` | 1.6.0 (sha256 `87721a4a50b1…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2014, the Dart project authors. |
| `http_parser` | 4.1.2 (sha256 `178d74305e78…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2014, the Dart project authors. |
| `image` | 4.12.0 (sha256 `89ed75b2f823…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2013-2022 Brendan Duncan. |
| `jni` | 1.1.2 (sha256 `2e91e6087291…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2022, the Dart project authors. |
| `jni_flutter` | 1.0.4+1 (sha256 `0dd33d677975…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2026, the Dart project authors. |
| `jni_util` | 1.0.0 (sha256 `1ba86da04a5f…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2026, the Dart project authors. |
| `leak_tracker` | 11.0.2 (sha256 `33e2e26bdd85…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2022, the Dart project authors. |
| `leak_tracker_flutter_testing` | 3.0.10 (sha256 `1dbc140bb5a2…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2022, the Dart project authors. |
| `leak_tracker_testing` | 3.0.2 (sha256 `8d5a2d49f4a6…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2022, the Dart project authors. |
| `lints` | 6.1.0 (sha256 `12f842a47958…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2021, the Dart project authors. |
| `logging` | 1.3.0 (sha256 `c8245ada5f17…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013, the Dart project authors. |
| `markdown` | 7.3.1 (sha256 `ee85086ad769…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2012, the Dart project authors. |
| `matcher` | 0.12.20 (sha256 `31bd099b47c1…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2014, the Dart project authors. |
| `material_color_utilities` | 0.13.0 (sha256 `9c337007e82b…`) | Apache-2.0 | kein SPDX und kein license-Feld | keine Copyright-Zeile am Dateianfang ausser dem Lizenztext |
| `matrix` | 16.0.1 (sha256 `6f782a91f5d4…`) | AGPL-3.0-text | AGPL-3.0-or-later | 2019-Present Famedly GmbH; keine Copyright-Zeile am Dateianfang ausser dem Lizenztext |
| `meta` | 1.18.3 (sha256 `c82594181e33…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2016, the Dart project authors. |
| `mime` | 2.1.0 (sha256 `bd47de35f07e…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2015, the Dart project authors. |
| `native_toolchain_c` | 0.19.2 (sha256 `f9c168717100…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2023, the Dart project authors. |
| `objective_c` | 9.5.0 (sha256 `b7fb95a6d9a4…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2024, the Dart project authors. |
| `package_config` | 3.0.0 (sha256 `ffcf4cf3d6c0…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2019, the Dart project authors. |
| `path` | 1.9.1 (sha256 `75cca69d1490…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2014, the Dart project authors. |
| `path_provider` | 2.1.6 (sha256 `a7f4874f9871…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `path_provider_android` | 2.3.1 (sha256 `69cbd515a62b…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `path_provider_foundation` | 2.6.0 (sha256 `2a376b7d6392…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `path_provider_linux` | 2.2.2 (sha256 `58c2005f1473…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `path_provider_platform_interface` | 2.1.3 (sha256 `484838772624…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `path_provider_windows` | 2.3.0 (sha256 `bd6f00dbd873…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors. All rights reserved. |
| `platform` | 3.2.0 (sha256 `a36d119c1341…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2017, the Dart project authors. All rights reserved. |
| `plugin_platform_interface` | 2.1.8 (sha256 `4820fbfdb947…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors. All rights reserved. |
| `posix` | 6.5.4 (sha256 `613646d07694…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2020 Brett Sutton |
| `pub_semver` | 2.2.1 (sha256 `261236774e8b…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2014, the Dart project authors. |
| `random_string` | 2.3.1 (sha256 `03b52435aae8…`) | BSD-like | kein SPDX und kein license-Feld | Copyright (c) 2016-2019 |
| `record_use` | 0.6.0 (sha256 `2551bd8eecfe…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2024, the Dart project authors. |
| `sdp_transform` | 0.4.0 (sha256 `8bf8144bb612…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2018 湖北捷智云技术有限公司 |
| `shared_preferences` | 2.5.6 (sha256 `1e85e0dccf5b…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `shared_preferences_android` | 2.5.4 (sha256 `33b38b07d9ac…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `shared_preferences_foundation` | 2.5.7 (sha256 `2ec3934efa51…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `shared_preferences_linux` | 2.4.1 (sha256 `580abfd40f41…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors. All rights reserved. |
| `shared_preferences_platform_interface` | 2.4.2 (sha256 `649dc798a339…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `shared_preferences_web` | 2.4.3 (sha256 `c49bd060261c…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors. All rights reserved. |
| `shared_preferences_windows` | 2.4.1 (sha256 `94ef0f72b2d7…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors. All rights reserved. |
| `sky_engine` | SDK | Flutter/Dart SDK | siehe Abschnitt Flutter | — |
| `slugify` | 2.0.0 (sha256 `b272501565cb…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2014 izolate |
| `source_span` | 1.10.2 (sha256 `56a02f1f4cd1…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2014, the Dart project authors. |
| `sqflite` | 2.4.5 (sha256 `21a9750de2de…`) | BSD | kein SPDX und kein license-Feld | Copyright (c) 2019, Alexandre Roux Tekartik |
| `sqflite_android` | 2.4.5 (sha256 `3986f4cbdde1…`) | BSD | kein SPDX und kein license-Feld | Copyright (c) 2019, Alexandre Roux Tekartik |
| `sqflite_common` | 2.5.15 (sha256 `cf0cfe7c1278…`) | BSD | kein SPDX und kein license-Feld | Copyright (c) 2019, Alexandre Roux Tekartik |
| `sqflite_common_ffi` | 2.4.5 (sha256 `119d73046026…`) | BSD | kein SPDX und kein license-Feld | Copyright (c) 2019, Alexandre Roux Tekartik |
| `sqflite_darwin` | 2.4.5 (sha256 `5652e66a7db9…`) | BSD | kein SPDX und kein license-Feld | Copyright (c) 2019, Alexandre Roux Tekartik |
| `sqflite_platform_interface` | 2.4.3 (sha256 `5b611dbcb9ba…`) | BSD | kein SPDX und kein license-Feld | Copyright (c) 2019, Alexandre Roux Tekartik |
| `sqlite3` | 3.5.2 (sha256 `4c7fe7984038…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2020 Simon Binder |
| `stack_trace` | 1.12.2 (sha256 `277654b3034d…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2014, the Dart project authors. |
| `stream_channel` | 2.1.4 (sha256 `969e04c80b8b…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2015, the Dart project authors. |
| `string_scanner` | 1.4.1 (sha256 `921cd31725b7…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2014, the Dart project authors. |
| `synchronized` | 3.6.1 (sha256 `0ce4712bd3be…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2016, Alexandre Roux Tekartik. |
| `term_glyph` | 1.2.2 (sha256 `7f554798625e…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2017, the Dart project authors. |
| `test_api` | 0.7.12 (sha256 `2a122cbe059f…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2018, the Dart project authors. |
| `typed_data` | 1.4.0 (sha256 `f9049c039ebf…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2015, the Dart project authors. |
| `unorm_dart` | 0.3.3 (sha256 `b4f4d2aff27d…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2018 Yasuhiro Shimizu <the.phantom.bane@gmail.com> |
| `vector_math` | 2.4.0 (sha256 `1d774bbdf6b7…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors |
| `vm_service` | 15.4.0 (sha256 `89b11d62e104…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2015, the Dart project authors. |
| `vodozemac` | 0.9.0 (sha256 `272870cb6b39…`) | AGPL-3.0-text | kein SPDX und kein license-Feld | keine Copyright-Zeile am Dateianfang ausser dem Lizenztext |
| `web` | 1.1.2 (sha256 `e119e82ac479…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2023, the Dart project authors. |
| `webrtc_interface` | 1.5.1 (sha256 `c6f100eac505…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2021 Flutter WebRTC |
| `xdg_directories` | 1.1.0 (sha256 `7a3f37b05d98…`) | BSD-like | kein SPDX und kein license-Feld | Copyright 2013 The Flutter Authors. All rights reserved. |
| `yaml` | 3.1.4 (sha256 `f67cdd8e07d3…`) | MIT | kein SPDX und kein license-Feld | Copyright (c) 2014, the Dart project authors.; Copyright (c) 2006, Kirill Simonov. |

## Rust-Crates aus flutter_vodozemac 0.9.0

Lockdatei: `flutter_vodozemac-0.9.0/rust/Cargo.lock` im pub-cache. Jede Crate mit Checksumme wurde von `https://static.crates.io/crates/<name>/<name>-<version>.crate` geladen und die sha256-Summe gegen die Lockdatei geprüft. Lizenzfeld und `license-file` stammen aus `Cargo.toml.orig`, sonst aus der normalisierten `Cargo.toml` desselben Archivs. Eine Crate ohne bestandene Prüfung bleibt UNKNOWN. Das ist eine Dateilesung, keine rechtliche Freigabe.

Gelesen: 276. Davon mit UNKNOWN im Lizenzfeld: 0.

| Crate | Version | Lizenz aus dem geprüften Archiv | Nachweis | Copyright aus der Lizenzdatei |
| --- | --- | --- | --- | --- |
| `addr2line` | 0.24.2 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/addr2line/addr2line-0.24.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016-2018 The gimli Developers |
| `adler2` | 2.0.0 | 0BSD OR MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/adler2/adler2-2.0.0.crate; gelesen: Cargo.toml.orig | Copyright (C) Jonas Schievink <jonasschievink@gmail.com> |
| `aead` | 0.5.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/aead/aead-0.5.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 The RustCrypto Project Developers; Copyright (c) 2019 MobileCoin, LLC |
| `aes` | 0.8.4 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/aes/aes-0.8.4.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018 Artyom Pavlov |
| `aho-corasick` | 1.1.3 | Unlicense OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/aho-corasick/aho-corasick-1.1.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 Andrew Gallant |
| `allo-isolate` | 0.1.27 | Apache-2.0 aus LICENSE | sha256 = Cargo.lock; https://static.crates.io/crates/allo-isolate/allo-isolate-0.1.27.crate; gelesen: Cargo.toml.orig | Lizenzdatei ohne Copyright-Zeile am Anfang |
| `android-tzdata` | 0.1.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/android-tzdata/android-tzdata-0.1.1.crate; gelesen: Cargo.toml.orig | Copyright (c) [year] [fullname] |
| `android_log-sys` | 0.3.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/android_log-sys/android_log-sys-0.3.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 The android_log_sys Developers |
| `android_logger` | 0.15.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/android_logger/android_logger-0.15.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 The android_logger Developers |
| `android_system_properties` | 0.1.5 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/android_system_properties/android_system_properties-0.1.5.crate; gelesen: Cargo.toml.orig | Copyright 2016 Nicolas Silva; Copyright (c) 2013 Nicolas Silva |
| `anstream` | 0.6.18 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/anstream/anstream-0.6.18.crate; gelesen: Cargo.toml | Copyright (c) Individual contributors |
| `anstyle` | 1.0.10 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/anstyle/anstyle-1.0.10.crate; gelesen: Cargo.toml | Copyright (c) 2022 The rust-cli Developers |
| `anstyle-parse` | 0.2.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/anstyle-parse/anstyle-parse-0.2.6.crate; gelesen: Cargo.toml | Copyright (c) 2016 Joe Wilm and individual contributors |
| `anstyle-query` | 1.1.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/anstyle-query/anstyle-query-1.1.2.crate; gelesen: Cargo.toml | Copyright (c) Individual contributors |
| `anstyle-wincon` | 3.0.7 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/anstyle-wincon/anstyle-wincon-3.0.7.crate; gelesen: Cargo.toml | Copyright (c) 2015 Josh Triplett, 2022 The rust-cli Developers |
| `anyhow` | 1.0.97 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/anyhow/anyhow-1.0.97.crate; gelesen: Cargo.toml.orig | — |
| `arrayvec` | 0.7.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/arrayvec/arrayvec-0.7.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Ulrik Sverdrup "bluss" 2015-2023 |
| `atomic` | 0.5.3 | Apache-2.0/MIT | sha256 = Cargo.lock; https://static.crates.io/crates/atomic/atomic-0.5.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 The Rust Project Developers |
| `autocfg` | 1.4.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/autocfg/autocfg-1.4.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018 Josh Stone |
| `backtrace` | 0.3.74 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/backtrace/backtrace-0.3.74.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `base64` | 0.22.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/base64/base64-0.22.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 Alice Maz |
| `base64ct` | 1.8.3 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/base64ct/base64ct-1.8.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Steve "Sc00bz" Thomas (steve at tobtu dot com); Copyright (c) 2021-2025 The RustCrypto Project Developers |
| `bitflags` | 1.3.2 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/bitflags/bitflags-1.3.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 The Rust Project Developers |
| `bitflags` | 2.9.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/bitflags/bitflags-2.9.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 The Rust Project Developers |
| `block-buffer` | 0.10.4 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/block-buffer/block-buffer-0.10.4.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2019 The RustCrypto Project Developers |
| `block-padding` | 0.3.3 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/block-padding/block-padding-0.3.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2019 The RustCrypto Project Developers |
| `build-target` | 0.4.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/build-target/build-target-0.4.0.crate; gelesen: Cargo.toml.orig | Copyright (c) OpenByte <development.openbyte@gmail.com> |
| `bumpalo` | 3.17.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/bumpalo/bumpalo-3.17.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 Nick Fitzgerald |
| `bytemuck` | 1.22.0 | Zlib OR Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/bytemuck/bytemuck-1.22.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 Daniel "Lokathor" Gee. |
| `byteorder` | 1.5.0 | Unlicense OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/byteorder/byteorder-1.5.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 Andrew Gallant |
| `bytes` | 1.12.1 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/bytes/bytes-1.12.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018 Carl Lerche |
| `camino` | 1.1.9 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/camino/camino-1.1.9.crate; gelesen: Cargo.toml.orig | — |
| `cargo-platform` | 0.1.9 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/cargo-platform/cargo-platform-0.1.9.crate; gelesen: Cargo.toml | — |
| `cargo_metadata` | 0.14.2 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/cargo_metadata/cargo_metadata-0.14.2.crate; gelesen: Cargo.toml.orig | — |
| `cargo_toml` | 0.21.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/cargo_toml/cargo_toml-0.21.0.crate; gelesen: Cargo.toml.orig | — |
| `cbc` | 0.1.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/cbc/cbc-0.1.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2022 RustCrypto Developers; Copyright (c) 2018 Artyom Pavlov |
| `cbindgen` | 0.28.0 | MPL-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/cbindgen/cbindgen-0.28.0.crate; gelesen: Cargo.toml.orig | — |
| `cc` | 1.2.18 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/cc/cc-1.2.18.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `cfg-if` | 1.0.0 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/cfg-if/cfg-if-1.0.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `chacha20` | 0.9.1 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/chacha20/chacha20-0.9.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019-2023 The RustCrypto Project Developers |
| `chacha20poly1305` | 0.10.1 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/chacha20poly1305/chacha20poly1305-0.10.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 The RustCrypto Project Developers |
| `chrono` | 0.4.40 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/chrono/chrono-0.4.40.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014, Kang Seonghoon. |
| `cipher` | 0.4.4 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/cipher/cipher-0.4.4.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016-2020 RustCrypto Developers |
| `clap` | 4.5.35 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/clap/clap-4.5.35.crate; gelesen: Cargo.toml.orig workspace.package | Copyright (c) Individual contributors |
| `clap_builder` | 4.5.35 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/clap_builder/clap_builder-4.5.35.crate; gelesen: Cargo.toml | Copyright (c) 2015-2022 Kevin B. Knapp and Clap Contributors |
| `clap_derive` | 4.5.32 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/clap_derive/clap_derive-4.5.32.crate; gelesen: Cargo.toml | Copyright (c) 2015-2022 Kevin B. Knapp and Clap Contributors |
| `clap_lex` | 0.7.4 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/clap_lex/clap_lex-0.7.4.crate; gelesen: Cargo.toml | Copyright (c) 2015-2022 Kevin B. Knapp and Clap Contributors |
| `colorchoice` | 1.0.3 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/colorchoice/colorchoice-1.0.3.crate; gelesen: Cargo.toml | Copyright (c) Individual contributors |
| `colored` | 1.9.4 | MPL-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/colored/colored-1.9.4.crate; gelesen: Cargo.toml.orig | — |
| `console` | 0.15.11 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/console/console-0.15.11.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Armin Ronacher <armin.ronacher@active-4.com> |
| `console` | 0.16.4 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/console/console-0.16.4.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Armin Ronacher <armin.ronacher@active-4.com> |
| `console_error_panic_hook` | 0.1.7 | Apache-2.0/MIT | sha256 = Cargo.lock; https://static.crates.io/crates/console_error_panic_hook/console_error_panic_hook-0.1.7.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018 Nick Fitzgerald |
| `const-oid` | 0.9.6 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/const-oid/const-oid-0.9.6.crate; gelesen: Cargo.toml.orig | Copyright (c) 2020-2022 The RustCrypto Project Developers |
| `convert_case` | 0.5.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/convert_case/convert_case-0.5.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2020 David Purdum |
| `core-foundation-sys` | 0.8.7 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/core-foundation-sys/core-foundation-sys-0.8.7.crate; gelesen: Cargo.toml.orig | Copyright (c) 2012-2013 Mozilla Foundation |
| `cpufeatures` | 0.2.17 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/cpufeatures/cpufeatures-0.2.17.crate; gelesen: Cargo.toml.orig | Copyright (c) 2020-2025 The RustCrypto Project Developers |
| `crossbeam-channel` | 0.5.15 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/crossbeam-channel/crossbeam-channel-0.5.15.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 The Crossbeam Project Developers |
| `crossbeam-utils` | 0.8.21 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/crossbeam-utils/crossbeam-utils-0.8.21.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 The Crossbeam Project Developers |
| `crypto-common` | 0.1.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/crypto-common/crypto-common-0.1.6.crate; gelesen: Cargo.toml.orig | Copyright (c) 2021 RustCrypto Developers |
| `ctr` | 0.9.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/ctr/ctr-0.9.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2022 RustCrypto Developers; Copyright (c) 2018 Artyom Pavlov |
| `curve25519-dalek` | 4.1.3 | BSD-3-Clause | sha256 = Cargo.lock; https://static.crates.io/crates/curve25519-dalek/curve25519-dalek-4.1.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016-2021 isis agora lovecruft. All rights reserved.; Copyright (c) 2016-2021 Henry de Valence. All rights reserved. |
| `curve25519-dalek-derive` | 0.1.1 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/curve25519-dalek-derive/curve25519-dalek-derive-0.1.1.crate; gelesen: Cargo.toml.orig | — |
| `dart-sys` | 4.1.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/dart-sys/dart-sys-4.1.5.crate; gelesen: Cargo.toml | Copyright 2012, the Dart project authors. |
| `dashmap` | 5.5.3 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/dashmap/dashmap-5.5.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 Acrimon |
| `delegate-attr` | 0.3.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/delegate-attr/delegate-attr-0.3.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2020 Xidorn Quan |
| `der` | 0.7.9 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/der/der-0.7.9.crate; gelesen: Cargo.toml.orig | Copyright (c) 2020-2023 The RustCrypto Project Developers |
| `derivative` | 2.2.0 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/derivative/derivative-2.2.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Martin Carton |
| `digest` | 0.10.7 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/digest/digest-0.10.7.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Artyom Pavlov |
| `ed25519` | 2.2.3 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/ed25519/ed25519-2.2.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2023 RustCrypto Developers |
| `ed25519-dalek` | 2.1.1 | BSD-3-Clause | sha256 = Cargo.lock; https://static.crates.io/crates/ed25519-dalek/ed25519-dalek-2.1.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017-2019 isis agora lovecruft. All rights reserved. |
| `either` | 1.15.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/either/either-1.15.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 |
| `encode_unicode` | 1.0.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/encode_unicode/encode_unicode-1.0.0.crate; gelesen: Cargo.toml.orig | — |
| `enum-iterator` | 1.5.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/enum-iterator/enum-iterator-1.5.0.crate; gelesen: Cargo.toml.orig | — |
| `enum-iterator-derive` | 1.4.0 | 0BSD | sha256 = Cargo.lock; https://static.crates.io/crates/enum-iterator-derive/enum-iterator-derive-1.4.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018 Stephane Raux |
| `enum_dispatch` | 0.3.13 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/enum_dispatch/enum_dispatch-0.3.13.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 Anton Lazarev |
| `env_filter` | 0.1.3 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/env_filter/env_filter-0.1.3.crate; gelesen: Cargo.toml | Copyright (c) Individual contributors |
| `equivalent` | 1.0.2 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/equivalent/equivalent-1.0.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016--2023 |
| `errno` | 0.3.11 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/errno/errno-0.3.11.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Chris Wong |
| `fastrand` | 2.3.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/fastrand/fastrand-2.3.0.crate; gelesen: Cargo.toml.orig | — |
| `fern` | 0.6.2 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/fern/fern-0.6.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014-2017 David Ross |
| `fiat-crypto` | 0.2.9 | MIT OR Apache-2.0 OR BSD-1-Clause | sha256 = Cargo.lock; https://static.crates.io/crates/fiat-crypto/fiat-crypto-0.2.9.crate; gelesen: Cargo.toml.orig | Copyright 2015-2020 the fiat-crypto authors (see the AUTHORS file); Copyright (c) 2015-2020 the fiat-crypto authors (see the AUTHORS file); Copyright (c) 2015-2020 the fiat-crypto authors (see the AUTHORS file). |
| `filetime` | 0.2.25 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/filetime/filetime-0.2.25.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `flutter_rust_bridge` | 2.13.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/flutter_rust_bridge/flutter_rust_bridge-2.13.0.crate; gelesen: Cargo.toml | — |
| `flutter_rust_bridge_codegen` | 2.13.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/flutter_rust_bridge_codegen/flutter_rust_bridge_codegen-2.13.0.crate; gelesen: Cargo.toml | Copyright 2022 Matej Knopp |
| `flutter_rust_bridge_macros` | 2.13.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/flutter_rust_bridge_macros/flutter_rust_bridge_macros-2.13.0.crate; gelesen: Cargo.toml | — |
| `fsevent-sys` | 4.1.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/fsevent-sys/fsevent-sys-4.1.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 Pierre Baillet |
| `futures` | 0.3.31 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/futures/futures-0.3.31.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Alex Crichton; Copyright (c) 2017 The Tokio Authors |
| `futures-channel` | 0.3.31 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/futures-channel/futures-channel-0.3.31.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Alex Crichton; Copyright (c) 2017 The Tokio Authors |
| `futures-core` | 0.3.31 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/futures-core/futures-core-0.3.31.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Alex Crichton; Copyright (c) 2017 The Tokio Authors |
| `futures-executor` | 0.3.31 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/futures-executor/futures-executor-0.3.31.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Alex Crichton; Copyright (c) 2017 The Tokio Authors |
| `futures-io` | 0.3.31 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/futures-io/futures-io-0.3.31.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Alex Crichton; Copyright (c) 2017 The Tokio Authors |
| `futures-macro` | 0.3.31 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/futures-macro/futures-macro-0.3.31.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Alex Crichton; Copyright (c) 2017 The Tokio Authors |
| `futures-sink` | 0.3.31 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/futures-sink/futures-sink-0.3.31.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Alex Crichton; Copyright (c) 2017 The Tokio Authors |
| `futures-task` | 0.3.31 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/futures-task/futures-task-0.3.31.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Alex Crichton; Copyright (c) 2017 The Tokio Authors |
| `futures-util` | 0.3.31 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/futures-util/futures-util-0.3.31.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Alex Crichton; Copyright (c) 2017 The Tokio Authors |
| `generic-array` | 0.14.7 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/generic-array/generic-array-0.14.7.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 Bartłomiej Kamiński |
| `getrandom` | 0.2.15 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/getrandom/getrandom-0.2.15.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2024 The rust-random Project Developers; Copyright (c) 2014 The Rust Project Developers |
| `getrandom` | 0.3.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/getrandom/getrandom-0.3.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2025 The rust-random Project Developers; Copyright (c) 2014 The Rust Project Developers |
| `gimli` | 0.31.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/gimli/gimli-0.31.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 The Rust Project Developers |
| `glob` | 0.3.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/glob/glob-0.3.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 The Rust Project Developers |
| `hashbrown` | 0.14.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/hashbrown/hashbrown-0.14.5.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Amanieu d'Antras |
| `hashbrown` | 0.15.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/hashbrown/hashbrown-0.15.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Amanieu d'Antras |
| `heck` | 0.4.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/heck/heck-0.4.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 The Rust Project Developers |
| `heck` | 0.5.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/heck/heck-0.5.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 The Rust Project Developers |
| `hermit-abi` | 0.3.9 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/hermit-abi/hermit-abi-0.3.9.crate; gelesen: Cargo.toml.orig | — |
| `hermit-abi` | 0.5.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/hermit-abi/hermit-abi-0.5.0.crate; gelesen: Cargo.toml.orig | — |
| `hex` | 0.4.3 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/hex/hex-0.4.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2013-2014 The Rust Project Developers.; Copyright (c) 2015-2020 The rust-hex Developers |
| `hkdf` | 0.12.4 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/hkdf/hkdf-0.12.4.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015-2018 Vlad Filippov; Copyright (c) 2018-2021 RustCrypto Developers |
| `hmac` | 0.12.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/hmac/hmac-0.12.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Artyom Pavlov |
| `iana-time-zone` | 0.1.63 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/iana-time-zone/iana-time-zone-0.1.63.crate; gelesen: Cargo.toml.orig | Copyright (c) 2020 Andrew D. Straw |
| `iana-time-zone-haiku` | 0.1.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/iana-time-zone-haiku/iana-time-zone-haiku-0.1.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2020 Andrew D. Straw |
| `include_dir` | 0.7.4 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/include_dir/include_dir-0.7.4.crate; gelesen: Cargo.toml | — |
| `include_dir_macros` | 0.7.4 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/include_dir_macros/include_dir_macros-0.7.4.crate; gelesen: Cargo.toml | — |
| `indexmap` | 2.9.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/indexmap/indexmap-2.9.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016--2017 |
| `indicatif` | 0.17.11 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/indicatif/indicatif-0.17.11.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Armin Ronacher <armin.ronacher@active-4.com> |
| `indicatif` | 0.18.6 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/indicatif/indicatif-0.18.6.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Armin Ronacher <armin.ronacher@active-4.com> |
| `indicatif-log-bridge` | 0.2.3 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/indicatif-log-bridge/indicatif-log-bridge-0.2.3.crate; gelesen: Cargo.toml.orig | — |
| `inotify` | 0.9.6 | ISC | sha256 = Cargo.lock; https://static.crates.io/crates/inotify/inotify-0.9.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Hanno Braun and contributors |
| `inotify-sys` | 0.1.5 | ISC | sha256 = Cargo.lock; https://static.crates.io/crates/inotify-sys/inotify-sys-0.1.5.crate; gelesen: Cargo.toml.orig | Copyright (c) Hanno Braun and contributors |
| `inout` | 0.1.4 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/inout/inout-0.1.4.crate; gelesen: Cargo.toml.orig | Copyright (c) 2022 The RustCrypto Project Developers; Copyright (c) 2022 Artyom Pavlov |
| `is-terminal` | 0.4.16 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/is-terminal/is-terminal-0.4.16.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015-2019 Doug Tangren |
| `is_terminal_polyfill` | 1.70.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/is_terminal_polyfill/is_terminal_polyfill-1.70.1.crate; gelesen: Cargo.toml.orig | Copyright (c) Individual contributors |
| `itertools` | 0.10.5 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/itertools/itertools-0.10.5.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 |
| `itertools` | 0.14.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/itertools/itertools-0.14.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 |
| `itoa` | 1.0.15 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/itoa/itoa-1.0.15.crate; gelesen: Cargo.toml.orig | — |
| `js-sys` | 0.3.77 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/js-sys/js-sys-0.3.77.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `kqueue` | 1.0.8 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/kqueue/kqueue-1.0.8.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 William Orr <will@worrbase.com> |
| `kqueue-sys` | 1.0.4 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/kqueue-sys/kqueue-sys-1.0.4.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 William Orr <will@worrbase.com> |
| `lazy_static` | 1.5.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/lazy_static/lazy_static-1.5.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2010 The Rust Project Developers |
| `libc` | 0.2.171 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/libc/libc-0.2.171.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014-2020 The Rust Project Developers |
| `libredox` | 0.1.3 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/libredox/libredox-0.1.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2023 4lDO2 |
| `linux-raw-sys` | 0.9.4 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/linux-raw-sys/linux-raw-sys-0.9.4.crate; gelesen: Cargo.toml.orig | Copyrights in the `linux-raw-sys` project are retained by their contributors. |
| `lock_api` | 0.4.12 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/lock_api/lock_api-0.4.12.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 The Rust Project Developers |
| `log` | 0.4.27 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/log/log-0.4.27.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 The Rust Project Developers |
| `matrix-pickle` | 0.2.1 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/matrix-pickle/matrix-pickle-0.2.1.crate; gelesen: Cargo.toml.orig | — |
| `matrix-pickle-derive` | 0.2.1 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/matrix-pickle-derive/matrix-pickle-derive-0.2.1.crate; gelesen: Cargo.toml.orig | — |
| `md-5` | 0.10.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/md-5/md-5-0.10.6.crate; gelesen: Cargo.toml.orig | Copyright (c) 2006-2009 Graydon Hoare; Copyright (c) 2009-2013 Mozilla Foundation |
| `memchr` | 2.7.4 | Unlicense OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/memchr/memchr-2.7.4.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 Andrew Gallant |
| `miniz_oxide` | 0.8.8 | MIT OR Zlib OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/miniz_oxide/miniz_oxide-0.8.8.crate; gelesen: Cargo.toml.orig | Copyright 2013-2014 RAD Game Tools and Valve Software; Copyright 2010-2014 Rich Geldreich and Tenacious Software LLC |
| `mio` | 0.8.11 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/mio/mio-0.8.11.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Carl Lerche and other MIO contributors |
| `notify` | 6.1.1 | CC0-1.0 | sha256 = Cargo.lock; https://static.crates.io/crates/notify/notify-6.1.1.crate; gelesen: Cargo.toml.orig | — |
| `notify-debouncer-mini` | 0.4.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/notify-debouncer-mini/notify-debouncer-mini-0.4.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2023 Notify Contributors |
| `num-traits` | 0.2.19 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/num-traits/num-traits-0.2.19.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 The Rust Project Developers |
| `num_cpus` | 1.16.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/num_cpus/num_cpus-1.16.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 |
| `number_prefix` | 0.4.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/number_prefix/number_prefix-0.4.0.crate; gelesen: Cargo.toml.orig | — |
| `object` | 0.36.7 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/object/object-0.36.7.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 The Gimli Developers |
| `once_cell` | 1.21.3 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/once_cell/once_cell-1.21.3.crate; gelesen: Cargo.toml.orig | — |
| `opaque-debug` | 0.3.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/opaque-debug/opaque-debug-0.3.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2024 The RustCrypto Project Developers |
| `oslog` | 0.2.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/oslog/oslog-0.2.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2020 Steven Joruk |
| `parking_lot` | 0.12.3 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/parking_lot/parking_lot-0.12.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 The Rust Project Developers |
| `parking_lot_core` | 0.9.10 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/parking_lot_core/parking_lot_core-0.9.10.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 The Rust Project Developers |
| `paste` | 1.0.15 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/paste/paste-1.0.15.crate; gelesen: Cargo.toml.orig | — |
| `pathdiff` | 0.2.3 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/pathdiff/pathdiff-0.2.3.crate; gelesen: Cargo.toml.orig | — |
| `pbkdf2` | 0.12.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/pbkdf2/pbkdf2-0.12.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Artyom Pavlov; Copyright (c) 2018-2023 The RustCrypto Project Developers |
| `pin-project-lite` | 0.2.16 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/pin-project-lite/pin-project-lite-0.2.16.crate; gelesen: Cargo.toml.orig | — |
| `pin-utils` | 0.1.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/pin-utils/pin-utils-0.1.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018 The pin-utils authors |
| `pkcs8` | 0.10.2 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/pkcs8/pkcs8-0.10.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2020-2023 The RustCrypto Project Developers |
| `poly1305` | 0.8.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/poly1305/poly1305-0.8.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015-2019 RustCrypto Developers |
| `portable-atomic` | 1.15.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/portable-atomic/portable-atomic-1.15.0.crate; gelesen: Cargo.toml.orig | — |
| `ppv-lite86` | 0.2.21 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/ppv-lite86/ppv-lite86-0.2.21.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 The CryptoCorrosion Contributors |
| `proc-macro-crate` | 3.3.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/proc-macro-crate/proc-macro-crate-3.3.0.crate; gelesen: Cargo.toml.orig | — |
| `proc-macro-error-attr2` | 2.0.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/proc-macro-error-attr2/proc-macro-error-attr2-2.0.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019-2020 CreepySkeleton |
| `proc-macro-error2` | 2.0.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/proc-macro-error2/proc-macro-error2-2.0.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019-2020 CreepySkeleton |
| `proc-macro2` | 1.0.94 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/proc-macro2/proc-macro2-1.0.94.crate; gelesen: Cargo.toml.orig | — |
| `prost` | 0.14.4 | Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/prost/prost-0.14.4.crate; gelesen: Cargo.toml | — |
| `prost-derive` | 0.14.4 | Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/prost-derive/prost-derive-0.14.4.crate; gelesen: Cargo.toml | — |
| `quote` | 1.0.40 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/quote/quote-1.0.40.crate; gelesen: Cargo.toml.orig | — |
| `r-efi` | 5.2.0 | MIT OR Apache-2.0 OR LGPL-2.1-or-later | sha256 = Cargo.lock; https://static.crates.io/crates/r-efi/r-efi-5.2.0.crate; gelesen: Cargo.toml.orig | — |
| `rand` | 0.8.8 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/rand/rand-0.8.8.crate; gelesen: Cargo.toml.orig | Copyrights in the Rand project are retained by their contributors. No; Copyright 2018 Developers of the Rand project; Copyright (c) 2014 The Rust Project Developers |
| `rand_chacha` | 0.3.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/rand_chacha/rand_chacha-0.3.1.crate; gelesen: Cargo.toml.orig | Copyrights in the Rand project are retained by their contributors. No; Copyright 2018 Developers of the Rand project; Copyright (c) 2014 The Rust Project Developers |
| `rand_core` | 0.6.4 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/rand_core/rand_core-0.6.4.crate; gelesen: Cargo.toml.orig | Copyrights in the Rand project are retained by their contributors. No; Copyright 2018 Developers of the Rand project; Copyright (c) 2014 The Rust Project Developers |
| `redox_syscall` | 0.5.11 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/redox_syscall/redox_syscall-0.5.11.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Redox OS Developers |
| `regex` | 1.11.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/regex/regex-1.11.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 The Rust Project Developers |
| `regex-automata` | 0.4.9 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/regex-automata/regex-automata-0.4.9.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 The Rust Project Developers |
| `regex-syntax` | 0.8.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/regex-syntax/regex-syntax-0.8.5.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 The Rust Project Developers; Copyright © 1991-2018 Unicode, Inc. All rights reserved. |
| `rustc-demangle` | 0.1.24 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/rustc-demangle/rustc-demangle-0.1.24.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `rustc_version` | 0.4.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/rustc_version/rustc_version-0.4.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 The Rust Project Developers |
| `rustix` | 1.0.5 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/rustix/rustix-1.0.5.crate; gelesen: Cargo.toml.orig | Copyrights in the `rustix` project are retained by their contributors. |
| `rustversion` | 1.0.20 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/rustversion/rustversion-1.0.20.crate; gelesen: Cargo.toml.orig | — |
| `ryu` | 1.0.20 | Apache-2.0 OR BSL-1.0 | sha256 = Cargo.lock; https://static.crates.io/crates/ryu/ryu-1.0.20.crate; gelesen: Cargo.toml.orig | — |
| `same-file` | 1.0.6 | Unlicense/MIT | sha256 = Cargo.lock; https://static.crates.io/crates/same-file/same-file-1.0.6.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Andrew Gallant |
| `scopeguard` | 1.2.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/scopeguard/scopeguard-1.2.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016-2019 Ulrik Sverdrup "bluss" and scopeguard developers |
| `semver` | 1.0.26 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/semver/semver-1.0.26.crate; gelesen: Cargo.toml.orig | — |
| `serde` | 1.0.219 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/serde/serde-1.0.219.crate; gelesen: Cargo.toml.orig | — |
| `serde_bytes` | 0.11.17 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/serde_bytes/serde_bytes-0.11.17.crate; gelesen: Cargo.toml.orig | — |
| `serde_derive` | 1.0.219 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/serde_derive/serde_derive-1.0.219.crate; gelesen: Cargo.toml.orig | — |
| `serde_json` | 1.0.140 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/serde_json/serde_json-1.0.140.crate; gelesen: Cargo.toml.orig | — |
| `serde_spanned` | 0.6.8 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/serde_spanned/serde_spanned-0.6.8.crate; gelesen: Cargo.toml | Copyright (c) Individual contributors |
| `serde_yaml` | 0.9.34+deprecated | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/serde_yaml/serde_yaml-0.9.34+deprecated.crate; gelesen: Cargo.toml.orig | — |
| `serial_test` | 2.0.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/serial_test/serial_test-2.0.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018 Tom Parker-Shemilt |
| `serial_test_derive` | 2.0.0 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/serial_test_derive/serial_test_derive-2.0.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018 Tom Parker-Shemilt |
| `sha1` | 0.10.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/sha1/sha1-0.10.6.crate; gelesen: Cargo.toml.orig | Copyright (c) 2006-2009 Graydon Hoare; Copyright (c) 2009-2013 Mozilla Foundation |
| `sha2` | 0.10.9 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/sha2/sha2-0.10.9.crate; gelesen: Cargo.toml.orig | Copyright (c) 2006-2009 Graydon Hoare; Copyright (c) 2009-2013 Mozilla Foundation |
| `shlex` | 1.3.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/shlex/shlex-1.3.0.crate; gelesen: Cargo.toml.orig | Copyright 2015 Nicholas Allegra (comex).; Copyright (c) 2015 Nicholas Allegra (comex). |
| `signature` | 2.2.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/signature/signature-2.2.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2023 RustCrypto Developers |
| `slab` | 0.4.9 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/slab/slab-0.4.9.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 Carl Lerche |
| `smallvec` | 1.15.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/smallvec/smallvec-1.15.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018 The Servo Project Developers |
| `spki` | 0.7.3 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/spki/spki-0.7.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2021-2023 The RustCrypto Project Developers |
| `strsim` | 0.11.1 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/strsim/strsim-0.11.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 Danny Guo; Copyright (c) 2016 Titus Wormer <tituswormer@gmail.com> |
| `strum` | 0.26.3 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/strum/strum-0.26.3.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 Peter Glotfelty |
| `strum_macros` | 0.26.4 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/strum_macros/strum_macros-0.26.4.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019 Peter Glotfelty |
| `subtle` | 2.6.1 | BSD-3-Clause | sha256 = Cargo.lock; https://static.crates.io/crates/subtle/subtle-2.6.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016-2017 Isis Agora Lovecruft, Henry de Valence. All rights reserved.; Copyright (c) 2016-2024 Isis Agora Lovecruft. All rights reserved. |
| `syn` | 1.0.109 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/syn/syn-1.0.109.crate; gelesen: Cargo.toml.orig | — |
| `syn` | 2.0.100 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/syn/syn-2.0.100.crate; gelesen: Cargo.toml.orig | — |
| `syn` | 3.0.3 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/syn/syn-3.0.3.crate; gelesen: Cargo.toml.orig | — |
| `tempfile` | 3.19.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/tempfile/tempfile-3.19.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 Steven Allen |
| `thiserror` | 1.0.69 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/thiserror/thiserror-1.0.69.crate; gelesen: Cargo.toml.orig | — |
| `thiserror` | 2.0.19 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/thiserror/thiserror-2.0.19.crate; gelesen: Cargo.toml.orig | — |
| `thiserror-impl` | 1.0.69 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/thiserror-impl/thiserror-impl-1.0.69.crate; gelesen: Cargo.toml.orig | — |
| `thiserror-impl` | 2.0.19 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/thiserror-impl/thiserror-impl-2.0.19.crate; gelesen: Cargo.toml.orig | — |
| `threadpool` | 1.8.1 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/threadpool/threadpool-1.8.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 The Rust Project Developers |
| `tokio` | 1.44.2 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/tokio/tokio-1.44.2.crate; gelesen: Cargo.toml.orig | Copyright (c) Tokio Contributors |
| `toml` | 0.5.11 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/toml/toml-0.5.11.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `toml` | 0.8.20 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/toml/toml-0.8.20.crate; gelesen: Cargo.toml | Copyright (c) Individual contributors |
| `toml_datetime` | 0.6.8 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/toml_datetime/toml_datetime-0.6.8.crate; gelesen: Cargo.toml | Copyright (c) Individual contributors |
| `toml_edit` | 0.22.24 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/toml_edit/toml_edit-0.22.24.crate; gelesen: Cargo.toml | Copyright (c) Individual contributors |
| `topological-sort` | 0.2.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/topological-sort/topological-sort-0.2.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 The topological-sort-rs Developers |
| `typenum` | 1.18.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/typenum/typenum-1.18.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Paho Lurie-Gregg |
| `unicode-ident` | 1.0.18 | (MIT OR Apache-2.0) AND Unicode-3.0 | sha256 = Cargo.lock; https://static.crates.io/crates/unicode-ident/unicode-ident-1.0.18.crate; gelesen: Cargo.toml.orig | Copyright © 1991-2023 Unicode, Inc. |
| `unicode-width` | 0.2.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/unicode-width/unicode-width-0.2.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 The Rust Project Developers |
| `unit-prefix` | 0.5.2 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/unit-prefix/unit-prefix-0.5.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2024 Benjamin Sago, Fabio Valentini |
| `universal-hash` | 0.5.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/universal-hash/universal-hash-0.5.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019-2020 RustCrypto Developers |
| `unsafe-libyaml` | 0.2.11 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/unsafe-libyaml/unsafe-libyaml-0.2.11.crate; gelesen: Cargo.toml.orig | — |
| `utf8parse` | 0.2.2 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/utf8parse/utf8parse-0.2.2.crate; gelesen: Cargo.toml.orig | Copyright (c) 2016 Joe Wilm |
| `version_check` | 0.9.5 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/version_check/version_check-0.9.5.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017-2018 Sergio Benitez |
| `vodozemac` | 0.10.0 | Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/vodozemac/vodozemac-0.10.0.crate; gelesen: Cargo.toml.orig | — |
| `vodozemac_bindings_dart` | 0.1.0 | kein license-Feld in der Crate | Pfad-Crate im Archiv flutter_vodozemac 0.9.0, keine crates.io-Checksumme. Die LICENSE des Pakets ist der AGPL-3.0-Text; Paket-LICENSE gelesen | siehe flutter_vodozemac, keine eigene Copyright-Zeile in Cargo.toml |
| `walkdir` | 2.5.0 | Unlicense/MIT | sha256 = Cargo.lock; https://static.crates.io/crates/walkdir/walkdir-2.5.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015 Andrew Gallant |
| `wasi` | 0.11.0+wasi-snapshot-preview1 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/wasi/wasi-0.11.0+wasi-snapshot-preview1.crate; gelesen: Cargo.toml.orig | — |
| `wasi` | 0.14.2+wasi-0.2.4 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/wasi/wasi-0.14.2+wasi-0.2.4.crate; gelesen: Cargo.toml.orig workspace.package | — |
| `wasm-bindgen` | 0.2.100 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/wasm-bindgen/wasm-bindgen-0.2.100.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `wasm-bindgen-backend` | 0.2.100 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/wasm-bindgen-backend/wasm-bindgen-backend-0.2.100.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `wasm-bindgen-futures` | 0.4.50 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/wasm-bindgen-futures/wasm-bindgen-futures-0.4.50.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `wasm-bindgen-macro` | 0.2.100 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/wasm-bindgen-macro/wasm-bindgen-macro-0.2.100.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `wasm-bindgen-macro-support` | 0.2.100 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/wasm-bindgen-macro-support/wasm-bindgen-macro-support-0.2.100.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `wasm-bindgen-shared` | 0.2.100 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/wasm-bindgen-shared/wasm-bindgen-shared-0.2.100.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `web-sys` | 0.3.77 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/web-sys/web-sys-0.3.77.crate; gelesen: Cargo.toml.orig | Copyright (c) 2014 Alex Crichton |
| `web-time` | 1.1.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/web-time/web-time-1.1.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2023 dAxpeDDa |
| `winapi` | 0.3.9 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/winapi/winapi-0.3.9.crate; gelesen: Cargo.toml.orig | Copyright (c) 2015-2018 The winapi-rs Developers |
| `winapi-i686-pc-windows-gnu` | 0.4.0 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/winapi-i686-pc-windows-gnu/winapi-i686-pc-windows-gnu-0.4.0.crate; gelesen: Cargo.toml.orig | — |
| `winapi-util` | 0.1.9 | Unlicense OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/winapi-util/winapi-util-0.1.9.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017 Andrew Gallant |
| `winapi-x86_64-pc-windows-gnu` | 0.4.0 | MIT/Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/winapi-x86_64-pc-windows-gnu/winapi-x86_64-pc-windows-gnu-0.4.0.crate; gelesen: Cargo.toml.orig | — |
| `windows-core` | 0.61.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-core/windows-core-0.61.0.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-implement` | 0.60.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-implement/windows-implement-0.60.0.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-interface` | 0.59.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-interface/windows-interface-0.59.1.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-link` | 0.1.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-link/windows-link-0.1.1.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-link` | 0.2.1 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-link/windows-link-0.2.1.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-result` | 0.3.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-result/windows-result-0.3.2.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-strings` | 0.4.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-strings/windows-strings-0.4.0.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-sys` | 0.48.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-sys/windows-sys-0.48.0.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-sys` | 0.59.0 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-sys/windows-sys-0.59.0.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-sys` | 0.61.2 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-sys/windows-sys-0.61.2.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-targets` | 0.48.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-targets/windows-targets-0.48.5.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows-targets` | 0.52.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows-targets/windows-targets-0.52.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_aarch64_gnullvm` | 0.48.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_aarch64_gnullvm/windows_aarch64_gnullvm-0.48.5.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_aarch64_gnullvm` | 0.52.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_aarch64_gnullvm/windows_aarch64_gnullvm-0.52.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_aarch64_msvc` | 0.48.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_aarch64_msvc/windows_aarch64_msvc-0.48.5.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_aarch64_msvc` | 0.52.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_aarch64_msvc/windows_aarch64_msvc-0.52.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_i686_gnu` | 0.48.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_i686_gnu/windows_i686_gnu-0.48.5.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_i686_gnu` | 0.52.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_i686_gnu/windows_i686_gnu-0.52.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_i686_gnullvm` | 0.52.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_i686_gnullvm/windows_i686_gnullvm-0.52.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_i686_msvc` | 0.48.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_i686_msvc/windows_i686_msvc-0.48.5.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_i686_msvc` | 0.52.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_i686_msvc/windows_i686_msvc-0.52.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_x86_64_gnu` | 0.48.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_x86_64_gnu/windows_x86_64_gnu-0.48.5.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_x86_64_gnu` | 0.52.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_x86_64_gnu/windows_x86_64_gnu-0.52.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_x86_64_gnullvm` | 0.48.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_x86_64_gnullvm/windows_x86_64_gnullvm-0.48.5.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_x86_64_gnullvm` | 0.52.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_x86_64_gnullvm/windows_x86_64_gnullvm-0.52.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_x86_64_msvc` | 0.48.5 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_x86_64_msvc/windows_x86_64_msvc-0.48.5.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `windows_x86_64_msvc` | 0.52.6 | MIT OR Apache-2.0 | sha256 = Cargo.lock; https://static.crates.io/crates/windows_x86_64_msvc/windows_x86_64_msvc-0.52.6.crate; gelesen: Cargo.toml.orig | Copyright (c) Microsoft Corporation. |
| `winnow` | 0.7.6 | MIT | sha256 = Cargo.lock; https://static.crates.io/crates/winnow/winnow-0.7.6.crate; gelesen: Cargo.toml.orig workspace.package | — |
| `wit-bindgen-rt` | 0.39.0 | { workspace = true } | sha256 = Cargo.lock; https://static.crates.io/crates/wit-bindgen-rt/wit-bindgen-rt-0.39.0.crate; gelesen: Cargo.toml.orig | — |
| `x25519-dalek` | 2.0.1 | BSD-3-Clause | sha256 = Cargo.lock; https://static.crates.io/crates/x25519-dalek/x25519-dalek-2.0.1.crate; gelesen: Cargo.toml.orig | Copyright (c) 2017-2021 isis agora lovecruft. All rights reserved.; Copyright (c) 2019-2021 DebugSteven. All rights reserved. |
| `zerocopy` | 0.8.24 | BSD-2-Clause OR Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/zerocopy/zerocopy-0.8.24.crate; gelesen: Cargo.toml.orig | Copyright 2019 The Fuchsia Authors.; Copyright 2023 The Fuchsia Authors |
| `zerocopy-derive` | 0.8.24 | BSD-2-Clause OR Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/zerocopy-derive/zerocopy-derive-0.8.24.crate; gelesen: Cargo.toml.orig | Copyright 2019 The Fuchsia Authors.; Copyright 2023 The Fuchsia Authors |
| `zeroize` | 1.9.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/zeroize/zeroize-1.9.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2018-2026 The RustCrypto Project Developers |
| `zeroize_derive` | 1.5.0 | Apache-2.0 OR MIT | sha256 = Cargo.lock; https://static.crates.io/crates/zeroize_derive/zeroize_derive-1.5.0.crate; gelesen: Cargo.toml.orig | Copyright (c) 2019-2026 The RustCrypto Project Developers |

## Python-Testumgebung (.venv)

| Distribution | Version | License-Feld |
| --- | --- | --- |
| `aiofiles` | 25.1.0 | Apache-2.0 |
| `aiohappyeyeballs` | 2.7.1 | PSF-2.0 |
| `aiohttp` | 3.14.5 | Apache-2.0 AND MIT |
| `aiohttp_socks` | 0.12.0 | Apache-2.0 |
| `aiosignal` | 1.4.0 | Apache 2.0 |
| `anyio` | 4.16.0 | MIT |
| `atomicwrites` | 1.4.1 | MIT |
| `attrs` | 26.1.0 | MIT |
| `cachetools` | 8.0.0 | MIT |
| `certifi` | 2026.10.23 | MPL-2.0 |
| `frozenlist` | 1.8.0 | Apache-2.0 |
| `h11` | 0.16.0 | MIT |
| `h2` | 4.4.1 | MIT |
| `hpack` | 4.2.0 | MIT |
| `httpcore` | 1.0.9 | BSD-3-Clause |
| `httpx` | 0.28.1 | BSD-3-Clause |
| `hyperframe` | 6.1.0 | The MIT License (MIT) |
| `idna` | 3.20 | BSD-3-Clause |
| `iniconfig` | 2.3.1 | MIT |
| `jsonschema` | 4.26.0 | MIT |
| `jsonschema-specifications` | 2025.9.1 | MIT |
| `matrix-nio` | 0.26.0 | ISC |
| `multidict` | 7.2.1 | Apache-2.0 |
| `packaging` | 26.3 | Apache-2.0 OR BSD-2-Clause |
| `peewee` | 3.19.0 | MIT (aus LICENSE, nicht aus dem License-Feld) |
| `piexif` | 1.1.3 | MIT |
| `pillow` | 11.1.0 | MIT-CMU |
| `pip` | 26.3 | MIT |
| `pluggy` | 1.7.0 | MIT |
| `propcache` | 0.5.4 | Apache-2.0 |
| `psycopg2-binary` | 2.9.10 | LGPL with exceptions |
| `pycryptodome` | 4.4.0 | BSD-2-Clause AND Unlicense AND MIT |
| `pytest` | 8.3.4 | MIT |
| `python-socks` | 3.2.1 | Apache-2.0 |
| `referencing` | 0.37.0 | MIT |
| `rpds-py` | 2026.9.1 | MIT |
| `typing_extensions` | 4.16.0 | PSF-2.0 |
| `unpaddedbase64` | 2.1.0 | Apache-2.0 |
| `vodozemac` | 0.10.0 | MIT (aus LICENSE, nicht aus dem License-Feld) |
| `yarl` | 1.25.1 | Apache-2.0 |

## Policy-Image hoobird-spike-policy (lokaler Build)

| Distribution | Version | License-Feld |
| --- | --- | --- |
| `annotated-types` | 0.8.0 | MIT |
| `anyio` | 4.16.0 | MIT |
| `certifi` | 2026.10.23 | MPL-2.0 |
| `click` | 8.5.1 | BSD-3-Clause |
| `fastapi` | 0.115.6 | Lizenzdatei vorhanden (LICENSE) |
| `h11` | 0.16.0 | MIT |
| `httpcore` | 1.0.9 | BSD-3-Clause |
| `httpx` | 0.28.1 | BSD-3-Clause |
| `idna` | 3.20 | BSD-3-Clause |
| `psycopg2-binary` | 2.9.10 | LGPL with exceptions |
| `pydantic` | 2.14.3 | MIT |
| `pydantic_core` | 2.50.4 | MIT |
| `starlette` | 0.41.3 | BSD-3-Clause |
| `typing_extensions` | 4.16.0 | PSF-2.0 |
| `typing-inspection` | 0.4.5 | MIT |
| `uvicorn` | 0.34.0 | BSD-3-Clause |

## Synapse-Image matrixdotorg/synapse:v1.163.0

| Distribution | Version | License-Feld |
| --- | --- | --- |
| `Pympler` | 1.0.1 | Apache License, Version 2.0 |
| `annotated-types` | 0.7.0 | Lizenzdatei vorhanden (LICENSE) |
| `attrs` | 26.1.0 | MIT |
| `Authlib` | 1.6.12 | BSD-3-Clause |
| `autocommand` | 2.2.2 | LGPLv3 |
| `Automat` | 25.4.16 | Copyright (c) 2014 Rackspace |
| `backports.tarfile` | 1.2.0 | Lizenzdatei vorhanden (LICENSE) |
| `bcrypt` | 5.0.0 | Apache-2.0 |
| `beautifulsoup4` | 4.15.0 | MIT License |
| `bleach` | 6.4.0 | Apache Software License |
| `canonicaljson` | 2.0.0 | Apache License, Version 2.0 |
| `certifi` | 2026.2.25 | MPL-2.0 |
| `cffi` | 2.0.0 | MIT |
| `charset-normalizer` | 3.4.4 | MIT |
| `constantly` | 23.10.4 | MIT |
| `cryptography` | 50.0.1 | Apache-2.0 OR BSD-3-Clause |
| `defusedxml` | 0.7.1 | PSFL |
| `elementpath` | 4.8.0 | MIT |
| `hiredis` | 3.3.1 | MIT |
| `html5lib` | 1.1 | MIT License |
| `hyperlink` | 21.0.0 | MIT |
| `idna` | 3.15 | BSD-3-Clause |
| `ijson` | 3.5.0 | BSD-3-Clause AND ISC |
| `immutabledict` | 4.3.1 | MIT |
| `importlib_metadata` | 8.7.1 | Apache-2.0 |
| `Incremental` | 24.11.0 | Lizenzdatei vorhanden (LICENSE) |
| `jaeger-client` | 4.8.0 | Apache License 2.0 |
| `jaraco.text` | 4.0.0 | Lizenzdatei vorhanden (LICENSE) |
| `jaraco.context` | 6.1.0 | MIT |
| `jaraco.functools` | 4.4.0 | MIT |
| `Jinja2` | 3.1.6 | Lizenzdatei vorhanden (LICENSE.txt) |
| `jsonschema` | 4.26.0 | MIT |
| `jsonschema-specifications` | 2025.9.1 | MIT |
| `ldap3` | 2.9.1 | LGPL v3 |
| `lxml-stubs` | 0.5.1 | Apache-2.0 (LICENSE) |
| `MarkupSafe` | 3.0.3 | BSD-3-Clause |
| `matrix-common` | 1.3.0 | Apache-2.0 (LICENSE) |
| `matrix-synapse` | 1.163.0 | AGPL-3.0-or-later OR LicenseRef-Element-Commercial |
| `matrix-synapse-ldap3` | 0.4.0 | Apache-2.0 (LICENSE) |
| `more-itertools` | 10.8.0 | MIT |
| `msgpack` | 1.2.1 | Apache-2.0 |
| `multipart` | 1.3.1 | Lizenzdatei vorhanden (LICENSE) |
| `netaddr` | 1.3.0 | BSD License |
| `opentracing` | 2.4.0 | Apache License 2.0 |
| `packaging` | 26.0 | Apache-2.0 OR BSD-2-Clause |
| `packaging` | 26.0 | Apache-2.0 OR BSD-2-Clause |
| `phonenumbers` | 9.0.28 | Apache-2.0 |
| `pillow` | 12.3.0 | MIT-CMU |
| `platformdirs` | 4.4.0 | MIT |
| `prometheus_client` | 0.24.1 | Apache-2.0 AND BSD-2-Clause |
| `psycopg2` | 2.9.11 | LGPL with exceptions |
| `pyasn1` | 0.6.4 | BSD-2-Clause |
| `pyasn1_modules` | 0.4.2 | BSD |
| `pycparser` | 3.0 | BSD-3-Clause |
| `pydantic` | 2.12.5 | MIT |
| `pydantic_core` | 2.41.5 | MIT |
| `pymacaroons` | 0.13.0 | MIT |
| `PyNaCl` | 1.6.2 | Apache-2.0 |
| `pyOpenSSL` | 26.4.0 | Apache License, Version 2.0 |
| `pyparsing` | 3.3.2 | MIT |
| `pyrsistent` | 0.20.0 | MIT |
| `pysaml2` | 7.5.0 | Apache-2.0 |
| `python-dateutil` | 2.9.0.post0 | Dual License |
| `python-multipart` | 0.0.31 | Apache-2.0 |
| `pytz` | 2026.1.post1 | MIT |
| `PyYAML` | 6.0.3 | MIT |
| `referencing` | 0.37.0 | MIT |
| `requests` | 2.33.1 | Apache-2.0 |
| `rpds-py` | 0.30.0 | MIT |
| `semantic-version` | 2.10.0 | BSD |
| `sentry-sdk` | 2.57.0 | MIT |
| `service-identity` | 24.2.0 | MIT |
| `setuptools` | 83.0.0 | MIT |
| `setuptools-rust` | 1.12.1 | Lizenzdatei vorhanden (LICENSE) |
| `signedjson` | 1.1.4 | Apache-2.0 (LICENSE) |
| `six` | 1.17.0 | MIT |
| `sortedcontainers` | 2.4.0 | Apache 2.0 |
| `soupsieve` | 2.10 | MIT |
| `threadloop` | 1.0.2 | MIT |
| `thrift` | 0.24.0 | Apache License 2.0 |
| `tomli` | 2.4.0 | MIT |
| `tornado` | 6.5.9 | Apache-2.0 |
| `treq` | 25.5.0 | MIT |
| `Twisted` | 26.4.0 | MIT License |
| `txredisapi` | 1.4.12 | http://www.apache.org/licenses/LICENSE-2.0 |
| `typing_extensions` | 4.15.0 | PSF-2.0 |
| `typing-inspection` | 0.4.2 | MIT |
| `unpaddedbase64` | 2.1.0 | Apache-2.0 |
| `urllib3` | 2.8.0 | MIT |
| `webencodings` | 0.5.1 | BSD |
| `wheel` | 0.46.3 | MIT |
| `xmlschema` | 2.5.1 | MIT |
| `zipp` | 3.23.0 | MIT |
| `zope.interface` | 8.2 | ZPL-2.1 |

## Basis-Images, gelesene Hinweise

`python:3.12-slim`, Image-ID `sha256:4840d514c583a4d3d8cad3940e68dee6f0f6f3635c12fcd0a3d74c21a5b93a54`. Interpreterdatei `/usr/local/lib/python3.12/LICENSE.txt` wurde aus diesem Image gelesen. Der Abschnitt „Python Software Foundation License Version 2“ ist vorhanden. Die darin verlangte Hinweiszeile lautet: Copyright (c) 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023 Python Software Foundation;. Betriebssystem im selben Image: PRETTY_NAME="Debian GNU/Linux 13 (trixie)"; VERSION="13 (trixie)"; DEBIAN_VERSION_FULL=13.7. Die Debian-`copyright`-Dateien unter `/usr/share/doc/<paket>/copyright` bleiben im Image. Unten stehen nur die dortigen `License:`-Felder, keine umgeschriebenen Texte.

| Debian-Paket im Image python:3.12-slim | License-Felder aus copyright |
| --- | --- |
| `adduser` | GPL-2+ |
| `apt` | GPL-2+ / GPL-2+ and curl / BSD-3-clause / Expat / GPL-2 / curl |
| `base-files` | GPL-2+ / verbatim |
| `base-passwd` | GPL-2 / public-domain |
| `bash` | GPL-3+ / GPL-3+ with Bison exception / GPL-2+ / GFDL-NIV-1.3 / Latex2e / BSD-4-clause-UC and MIT-like / BSD-4-clause-UC / MIT-like / permissive |
| `bsdutils` | GPL-2+ / GPL-2 / GPL-3+ / LGPL-2.1+ / public-domain / BSD-4-clause / Expat / ISC / BSD-3-clause / BSLA / LGPL-2+ / LGPL / BSD-2-clause / LGPL-3+ |
| `ca-certificates` | GPL-2+ / MPL-2.0 |
| `coreutils` | GPL-3+ / GPL-3+ and BSD-4-clause-UC / BSD-4-clause-UC / GPL-3+ and ISC / ISC / FSFULLR / GFDL-NIV-1.3 |
| `dash` | BSD-3-Clause / public-domain / GPL-2+ / BSD-3-clause |
| `debconf` | BSD-2-clause |
| `debian-archive-keyring` | Schlüssel: kein Copyright laut Datei; übrige Dateien GPL-2.0-or-later laut demselben Text |
| `debianutils` | GPL-2+ / public-domain / SMAIL-GPL |
| `diffutils` | GPL-3+ / FSFULLR / GPL-3+ and FSFULLR / LGPL-2.1+ / GPL-3+ with autoconf exception / GPL-3+ with texinfo exception / LGPL-2.0+ / GPL-2+ / X11 / FSFAP / GFDL-NIV-1.3 / LGPL-3.0+ / LGPL-3.0+ or GPL-2+ / public-domain |
| `dpkg` | GPL-2+ / public-domain-s-s-d |
| `findutils` | GFDL-NIV-1.3+ or GFDL-NIV-1.3+ / GPL-3+ / FSFAP / GFDL-NIV-1.3+ / GPL-2+ with Autoconf-data exception / GPL-3+ with Autoconf-data exception / FSFULLR / GPL-2+ / X11 / public-domain / LGPL-2.1+ / GPL with automake exception / LGPL-2+ / LGPL-3+ / BSD-3-clause or GPL-3+ / GPL-3+ with Bison-2.2 exception / LGPL-3 / FSFULLR or GPL or LGPL / ISC or LGPL-2.1+ / BSD-3-clause or LGPL-3+ / BSD-3-clause or LGPL-2.1+ / BSD-3-clause / GPL / ISC / LGPL |
| `gcc-14-base` | Datei enthält die GCC Runtime Library Exception und weitere Lizenzen der GCC-Sammlung |
| `grep` | GPL-3+ |
| `gzip` | GPL-3+ / GFDL-1.3+-no-invariant / FSF-manpages |
| `hostname` | GPL-2 |
| `init-system-helpers` | BSD-3-clause / GPL-2+ |
| `libacl1` | GPL-2+ / LGPL-2+ |
| `libapt-pkg7.0` | GPL-2+ / GPL-2+ and curl / BSD-3-clause / Expat / GPL-2 / curl |
| `libattr1` | GPL-2+ / LGPL-2+ |
| `libaudit-common` | GPL-2 / LGPL-2.1 |
| `libaudit1` | GPL-2 / LGPL-2.1 |
| `libblkid1` | GPL-2+ / GPL-2 / GPL-3+ / LGPL-2.1+ / public-domain / BSD-4-clause / Expat / ISC / BSD-3-clause / BSLA / LGPL-2+ / LGPL / BSD-2-clause / LGPL-3+ |
| `libbsd0` | BSD-3-clause / BSD-3-clause-Regents / BSD-3-clause-Regents and BSD-2-clause-NetBSD / BSD-3-clause-author / BSD-3-clause-John-Birrell / BSD-5-clause-Peter-Wemm / BSD-2-clause-NetBSD / BSD-2-clause / BSD-2-clause-verbatim / BSD-2-clause-author / ISC / ISC-Original / Expat / public-domain / Beerware |
| `libbz2-1.0` | BSD-variant / GPL-2 |
| `libc-bin` | LGPL-2.1+ / LGPL-2+ / LGPL-2.1+-with-link-exception / LGPL-3+ / GPL-2+ / GPL-2+-with-link-exception / LGPL-2.1+ and GPL-2 / GPL-3+ / FSFAP / Carnegie / Carnegie and LGPL-2.1+ / Inner-Net and LGPL-2.1+ / MIT-like-Lord / BSD-like-Spencer / PCRE / BSD-3-clause-Carnegie / Unicode-DFS-2016 / BSL-1.0 / SunPro / LGPL-2.1+ and SunPro / CORE-MATH / BSD-3-clause-Berkeley / BSD-3-clause-Berkeley and BSD-3-clause-WIDE / BSD-3-clause-Berkeley and LGPL-2.1+ / BSD-2-clause or GPL-2 / BSD-3-clause-Oracle / BSD-3-clause-Berkeley and DEC / BSD-3-clause-Berkeley and DEC and IBM and ISC / BSD-3-clause-Berkeley and DEC and ISC / BSD-3-clause-Berkeley and DEC and ISC and LGPL-2.1+ / BSD-3-clause-Berkeley and DEC and LGPL-2.1+ / BSD-3-clause-Berkeley and ISC / BSD-3-clause-Berkeley and LGPL-2.1+ and Univ-Coimbra / IBM and ISC / ISC / ISC and LGPL-2.1+ / public-domain / BSD-2-clause / BSD-3-clause-WIDE / Univ-Coimbra / DEC / GPL-2 / IBM / Inner-Net |
| `libc6` | LGPL-2.1+ / LGPL-2+ / LGPL-2.1+-with-link-exception / LGPL-3+ / GPL-2+ / GPL-2+-with-link-exception / LGPL-2.1+ and GPL-2 / GPL-3+ / FSFAP / Carnegie / Carnegie and LGPL-2.1+ / Inner-Net and LGPL-2.1+ / MIT-like-Lord / BSD-like-Spencer / PCRE / BSD-3-clause-Carnegie / Unicode-DFS-2016 / BSL-1.0 / SunPro / LGPL-2.1+ and SunPro / CORE-MATH / BSD-3-clause-Berkeley / BSD-3-clause-Berkeley and BSD-3-clause-WIDE / BSD-3-clause-Berkeley and LGPL-2.1+ / BSD-2-clause or GPL-2 / BSD-3-clause-Oracle / BSD-3-clause-Berkeley and DEC / BSD-3-clause-Berkeley and DEC and IBM and ISC / BSD-3-clause-Berkeley and DEC and ISC / BSD-3-clause-Berkeley and DEC and ISC and LGPL-2.1+ / BSD-3-clause-Berkeley and DEC and LGPL-2.1+ / BSD-3-clause-Berkeley and ISC / BSD-3-clause-Berkeley and LGPL-2.1+ and Univ-Coimbra / IBM and ISC / ISC / ISC and LGPL-2.1+ / public-domain / BSD-2-clause / BSD-3-clause-WIDE / Univ-Coimbra / DEC / GPL-2 / IBM / Inner-Net |
| `libcap-ng0` | LGPL-2.1+ / GPL-2+ / GPL-3 |
| `libcap2` | BSD-3-clause or GPL-2 / BSD-3-clause or GPL-2+ / BSD-3-clause / GPL-2 / GPL-2+ |
| `libcrypt1` | Gesamttext: LGPL-2.1-or-later; dieselbe Datei listet abweichende Dateilizenzen |
| `libdb5.3t64` | Sleepycat and BSD-3-clause / Sleepycat / BSD-3-clause / Ms-PL / GPL or Artistic / X11 / MIT-old / TCL-like / BSD-3-clause-fjord / GPL-3 / zlib / Artistic or BSD-3-clause / GPL |
| `libdebconfclient0` | BSD-2-Clause / GPL-2+ / BSD-2-clause |
| `libffi8` | Expat / X11 / GPL-2+ / GPL-3+ / MPL-1.1 or GPL-2+ or LGPL-2.1+ / public-domain / GPL |
| `libgcc-s1` | Datei enthält die GCC Runtime Library Exception und weitere Lizenzen der GCC-Sammlung |
| `libgdbm6t64` | GPL-3+ / GPL-2+ / GFDL-NIV-1.3+ |
| `libgmp10` | GPL-2+ or LGPL-3+ / GPL-3+ / GPL-3+ with Bison exception / GPL-2+ / LGPL-3+ |
| `libhogweed6t64` | LGPL-3+ or GPL-2+ / LGPL-2+ / Expat / GPL-2+ / GPL-3+ with Autoconf exception / public-domain / GPL-2 / GAP / LGPL-3+ |
| `liblastlog2-2` | GPL-2+ / GPL-2 / GPL-3+ / LGPL-2.1+ / public-domain / BSD-4-clause / Expat / ISC / BSD-3-clause / BSLA / LGPL-2+ / LGPL / BSD-2-clause / LGPL-3+ |
| `liblz4-1` | GPL-2+ / BSD-2-clause / BSD-2-clause or GPL-2+ |
| `liblzma5` | 0BSD / GPL-2+ / LGPL-2.1+ / FSFULLR / GPL-3.0-or-later-WITH-Autoconf-exception-macro / none / PD / permissive-nowarranty / FSFUL / noderivs / PD-debian |
| `libmd0` | BSD-3-clause / BSD-3-clause-Aaron-D-Gifford / BSD-2-clause / BSD-2-clause-NetBSD / ISC / Beerware / public-domain-md4 / public-domain-md5 / public-domain-sha1 |
| `libmount1` | GPL-2+ / GPL-2 / GPL-3+ / LGPL-2.1+ / public-domain / BSD-4-clause / Expat / ISC / BSD-3-clause / BSLA / LGPL-2+ / LGPL / BSD-2-clause / LGPL-3+ |
| `libncursesw6` | MIT/X11 / X11 / BSD-3-clause |
| `libnettle8t64` | LGPL-3+ or GPL-2+ / LGPL-2+ / Expat / GPL-2+ / GPL-3+ with Autoconf exception / public-domain / GPL-2 / GAP / LGPL-3+ |
| `libpam-modules` | BSD-3-clause or GPL / GPL-2 / GPL-2+ / GPL-3 / GPL-3+ with Bison exception / BSD-tcp_wrappers / LGPL-2+ / public-domain / Beerware |
| `libpam-modules-bin` | BSD-3-clause or GPL / GPL-2 / GPL-2+ / GPL-3 / GPL-3+ with Bison exception / BSD-tcp_wrappers / LGPL-2+ / public-domain / Beerware |
| `libpam-runtime` | BSD-3-clause or GPL / GPL-2 / GPL-2+ / GPL-3 / GPL-3+ with Bison exception / BSD-tcp_wrappers / LGPL-2+ / public-domain / Beerware |
| `libpam0g` | BSD-3-clause or GPL / GPL-2 / GPL-2+ / GPL-3 / GPL-3+ with Bison exception / BSD-tcp_wrappers / LGPL-2+ / public-domain / Beerware |
| `libpcre2-8-0` | BSD-3-clause-Cambridge with BINARY LIBRARY-LIKE PACKAGES exception / BSD-3-clause / X11 / BSD-2-clause / public-domain |
| `libreadline8t64` | GPL-3+ / GPL-2+ / GFDL-NIV-1.3+ / ISC-no-attribution / GPL-3 |
| `libseccomp2` | LGPL-2.1 |
| `libselinux1` | public-domain / GPL-2 |
| `libsemanage-common` | LGPL-2.1+ / GPL-2 |
| `libsemanage2` | LGPL-2.1+ / GPL-2 |
| `libsepol2` | LGPL-2.1+ / Zlib / GPL-2 / GPL-2+ |
| `libsmartcols1` | GPL-2+ / GPL-2 / GPL-3+ / LGPL-2.1+ / public-domain / BSD-4-clause / Expat / ISC / BSD-3-clause / BSLA / LGPL-2+ / LGPL / BSD-2-clause / LGPL-3+ |
| `libsqlite3-0` | public-domain / GPL-2+ |
| `libssl3t64` | Apache-2.0 / Artistic or GPL-1+ / Artistic / GPL-1+ |
| `libstdc++6` | Datei enthält die GCC Runtime Library Exception und weitere Lizenzen der GCC-Sammlung |
| `libsystemd0` | LGPL-2.1+ / CC0-1.0 / GPL-2 with Linux-syscall-note exception / Expat / public-domain / GPL-2+ |
| `libtinfo6` | MIT/X11 / X11 / BSD-3-clause |
| `libudev1` | LGPL-2.1+ / CC0-1.0 / GPL-2 with Linux-syscall-note exception / Expat / public-domain / GPL-2+ |
| `libuuid1` | GPL-2+ / GPL-2 / GPL-3+ / LGPL-2.1+ / public-domain / BSD-4-clause / Expat / ISC / BSD-3-clause / BSLA / LGPL-2+ / LGPL / BSD-2-clause / LGPL-3+ |
| `libxxhash0` | BSD-2-clause / GPL-2+ / BSD-2-clause or GPL-2+ |
| `libzstd1` | BSD-3-clause or GPL-2 / zlib / Expat / GPL-2 / BSD-3-clause |
| `login` | GPL-2+ / GPL-2 / GPL-3+ / LGPL-2.1+ / public-domain / BSD-4-clause / Expat / ISC / BSD-3-clause / BSLA / LGPL-2+ / LGPL / BSD-2-clause / LGPL-3+ |
| `login.defs` | BSD-3-clause / GPL-1 / GPL-2+ |
| `mawk` | GPL-2.0-only / X11 / CC-BY-3.0 |
| `mount` | GPL-2+ / GPL-2 / GPL-3+ / LGPL-2.1+ / public-domain / BSD-4-clause / Expat / ISC / BSD-3-clause / BSLA / LGPL-2+ / LGPL / BSD-2-clause / LGPL-3+ |
| `ncurses-base` | MIT/X11 / X11 / BSD-3-clause |
| `ncurses-bin` | MIT/X11 / X11 / BSD-3-clause |
| `netbase` | GPL-2 |
| `openssl` | Apache-2.0 / Artistic or GPL-1+ / Artistic / GPL-1+ |
| `openssl-provider-legacy` | Apache-2.0 / Artistic or GPL-1+ / Artistic / GPL-1+ |
| `passwd` | BSD-3-clause / GPL-1 / GPL-2+ |
| `perl-base` | GPL-1+ or Artistic / Expat / REGCOMP, and GPL-1+ or Artistic / GPL-3+-WITH-BISON-EXCEPTION / Unicode / GPL-1+ or Artistic, and Unicode / BZIP / ZLIB / Artistic / GPL-2+ or Artistic / Expat or GPL-1+ or Artistic / FSFAP / BSD-3-clause-with-weird-numbering / CC0-1.0 / Artistic or GPL-1+ / TEXT-TABS / GPL-1+ or Artistic, and BSD-4-clause-POWERDOG / GPL-1+ or Artistic, and BSD-3-clause-GENERIC / BSD-3-clause / SDBM-PUBLIC-DOMAIN / DONT-CHANGE-THE-GPL / GPL-1+ or Artistic or Artistic-dist / Artistic-dist / Artistic or GPL-1+ or Artistic-dist / GPL-1+ or Artistic, and Expat / LGPL-2.1 / GPL-1+ / GPL-2+ / Artistic-2 / BSD-4-clause-POWERDOG / BSD-3-clause-GENERIC / REGCOMP |
| `readline-common` | GPL-3+ / GPL-2+ / GFDL-NIV-1.3+ / ISC-no-attribution / GPL-3 |
| `sed` | GPL-3+ / X11 / GFDL-NIV-1.3+ / GPL-3+ and ISC / ISC / BSD-4-clause-UC / BSL-1 / pcre |
| `sqv` | LGPL-2.0-or-later |
| `sysvinit-utils` | GPL-2.0+ / LGPL-2.1+ / GPL-3.0 / GPL-2.0 |
| `tar` | GPL-3+ / GPL-3+ with Bison exception / LGPL-2.1+ / LGPL-3+ / GPL-2+ |
| `tzdata` | public-domain |
| `util-linux` | GPL-2+ / GPL-2 / GPL-3+ / LGPL-2.1+ / public-domain / BSD-4-clause / Expat / ISC / BSD-3-clause / BSLA / LGPL-2+ / LGPL / BSD-2-clause / LGPL-3+ |
| `zlib1g` | Zlib |

`postgres:16-alpine`, Image-ID `sha256:aa6cb33cf4c19c765cefcf48d96176258800870a9a1e930ad126200f9d825139`. `postgres --version` in diesem Image: `postgres (PostgreSQL) 16.15`. Eine COPYRIGHT- oder LICENSE-Datei des Servers wurde im Image nicht gefunden. Der passende Upstream-Tag wurde nur verwendet, weil die Versionszeichenkette 16.15 ist: `postgres/postgres` Tag `REL_16_15`, Datei `meson.build` mit `version: '16.15'` und `license: 'PostgreSQL'`, Datei `COPYRIGHT` mit „Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group“ und „Portions Copyright (c) 1994, The Regents of the University of California“. Das Binary im Image wurde nicht Byte für Byte gegen diesen Tag geprüft. Pflicht aus diesem Text, falls das Programm weitergegeben wird: der Copyright-Hinweis und die beiden folgenden Absätze bleiben in allen Kopien. Das ist die gelesene Lizenz, keine Aussage, dass das Image rechtlich unbedenklich ist.

Alpine-Pakete, die das Postgres-Image tatsächlich installiert hat. Das Feld stammt aus `/lib/apk/db/installed` und ist die von Alpine eingetragene Kennung, nicht der mitgelieferte Lizenztext. Der PostgreSQL-Server selbst ist kein apk-Paket in diesem Image; sein Hinweis steht im Absatz darüber. Leere Felder bleiben UNKNOWN.

`signedjson` 1.1.4 im Synapse-Image: `METADATA` setzt `License: UNKNOWN` und `License-File: LICENSE`. Die Datei `signedjson-1.1.4.dist-info/LICENSE` ist der Apache-2.0-Text ohne Copyright-Anhang. Die Copyright-Zeilen stehen in den Modulen desselben installierten Pakets:

```
files=__init__.py,key.py,sign.py,types.py
Copyright 2014 OpenMarket Ltd
Copyright 2014 OpenMarket Ltd
Copyright 2020 The Matrix.org Foundation C.I.C
Copyright 2014 OpenMarket Ltd
Copyright 2020 The Matrix.org Foundation C.I.C
Copyright 2020 The Matrix.org Foundation C.I.C.
```

## Synapse-Paket

`matrixdotorg/synapse:v1.163.0`, Image-ID `sha256:e98ab72138d90fa8b8876c6421fe78a9fdb181c0d7cc690ad740e5173e0c65e6`. Lizenzausdruck aus `matrix_synapse-1.163.0.dist-info/METADATA`: `AGPL-3.0-or-later OR LicenseRef-Element-Commercial`. Genutzt wird die AGPL-Seite. Eine Element-Commercial-Lizenz wurde nicht angenommen.

## Was die Dateien nicht hergeben

- `flutter_vodozemac` 0.9.0 enthält den AGPL-3.0-Text. Eine SPDX-Zeile „AGPL-3.0-or-later“ steht in dem gelesenen Archiv nicht. Die „How to Apply These Terms“-Passage im GNU-Text ist die Anleitung der Free Software Foundation, kein zusätzlicher Hinweis der Paketautoren.
- `matrix` 16.0.1 hat in `pubspec.yaml` die Zeilen `SPDX-FileCopyrightText: 2019-Present Famedly GmbH` und `SPDX-License-Identifier: AGPL-3.0-or-later`.
- Die kommerzielle Element-Lizenz ist keine Option dieses Entwurfs.
- UNKNOWN bleibt UNKNOWN. Dazu kann eine Crate gehören, deren Archiv nicht geladen oder deren Prüfsumme nicht bestätigt wurde.

## Nachtrag image_picker

`scripts/license_inventory.py` wurde für diesen Nachtrag nicht erneut ausgeführt. Die Tabelle oben enthält `image_picker` deshalb nicht. `app/pubspec.lock` hält `image_picker` 1.2.4 fest. Die gelesene Datei `LICENSE` in diesem Paket beginnt mit „Copyright 2013 The Flutter Authors“ und ist eine BSD-3-Clause-Lizenz. Dieselbe Datei hängt weitere Hinweise an, darunter aFileChooser. Die transitiven Pakete, die `flutter pub get` dafür geholt hat, stehen im Lockfile. Ihre Lizenztexte sind in dieser Tabelle nicht neu abgeschrieben.
