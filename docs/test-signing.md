# Test signing key

Debug and profile APKs can share one test certificate, so a later build updates the installed app instead of failing with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Each cloud VM otherwise generates its own `~/.android/debug.keystore`.

This key is for test builds only. It is not a release key, not a store key, and not a production secret that belongs in git. Release builds keep the stock debug signing config until a real release key exists.

## Where the key lives

The keystore and its password stay outside the repository. On this agent's machine they are in the agent store:

- `/cursor/stores/self/signing/hoobird-test.p12`
- `/cursor/stores/self/signing/hoobird-test.properties`

Alias: `hoobirdtest`. Certificate SHA-256:

`AA:5E:7B:EC:C0:7A:10:81:FE:31:7A:68:95:31:40:33:BC:D1:EC:89:6F:01:79:71:1B:DD:30:01:66:BB:44:9C`

Every test APK note from now on includes the signer SHA-256 of that file (`apksigner verify --print-certs`). A build that uses this key prints the same fingerprint.

## How Gradle finds it

`app/android/app/build.gradle.kts` reads four values. An environment variable wins over a property. The property file is `app/android/key.properties`, which is gitignored.

| Env | `key.properties` |
| --- | --- |
| `HOOBIRD_TEST_STORE_FILE` | `storeFile` |
| `HOOBIRD_TEST_STORE_PASSWORD` | `storePassword` |
| `HOOBIRD_TEST_KEY_ALIAS` | `keyAlias` |
| `HOOBIRD_TEST_KEY_PASSWORD` | `keyPassword` |

`storeFile` is an absolute path. If the file or any value is missing, debug and profile fall back to the normal debug key and the install-over-update problem comes back. A half-configured key prints a Gradle warning and uses that fallback. Release is unchanged either way.

Copy the properties file into place before a test build, or export the four variables. Do not commit the copy.

```bash
cp /cursor/stores/self/signing/hoobird-test.properties app/android/key.properties
```

## What is already installed

APK -7 (all three ABIs) and APK -6 were signed by one VM debug certificate, SHA-256 `5c905a33ee24f5f4ce64df2156439834f8670feaff27f57088b12c1b49a6c5b2`. APK -5 used a different debug certificate, SHA-256 `30b5aa77c222f6be23e90e0e718eef19690d14e02d6e4bc8f9b35ffccad0f9fb`. The next test APK uses the test certificate above, so the first install over -7 still needs one uninstall. After that, updates keep the app data.
