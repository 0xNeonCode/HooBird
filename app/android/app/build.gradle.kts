import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Test builds share one key so a later APK can update the installed app.
// The keystore stays out of git. Env vars win over app/android/key.properties.
// If neither is present, debug and profile keep the normal debug key.
// Release never uses this key.
val hoobirdTestKeyProperties = Properties()
val hoobirdTestKeyPropertiesFile = rootProject.file("key.properties")
if (hoobirdTestKeyPropertiesFile.isFile) {
    hoobirdTestKeyPropertiesFile.inputStream().use { hoobirdTestKeyProperties.load(it) }
}

fun hoobirdTestValue(envName: String, propertyName: String): String? {
    val fromEnv = System.getenv(envName)?.trim()?.takeIf { it.isNotEmpty() }
    if (fromEnv != null) return fromEnv
    return hoobirdTestKeyProperties.getProperty(propertyName)?.trim()?.takeIf { it.isNotEmpty() }
}

val hoobirdTestStorePath = hoobirdTestValue("HOOBIRD_TEST_STORE_FILE", "storeFile")
val hoobirdTestStorePassword = hoobirdTestValue("HOOBIRD_TEST_STORE_PASSWORD", "storePassword")
val hoobirdTestKeyAlias = hoobirdTestValue("HOOBIRD_TEST_KEY_ALIAS", "keyAlias")
val hoobirdTestKeyPassword = hoobirdTestValue("HOOBIRD_TEST_KEY_PASSWORD", "keyPassword")
val hoobirdTestStore = hoobirdTestStorePath?.let { File(it) }
val hoobirdTestKeyConfigured =
    hoobirdTestKeyPropertiesFile.isFile || !hoobirdTestStorePath.isNullOrEmpty()
val hoobirdTestKeyReady =
    hoobirdTestStore != null &&
        hoobirdTestStore.isFile &&
        !hoobirdTestStorePassword.isNullOrEmpty() &&
        !hoobirdTestKeyAlias.isNullOrEmpty() &&
        !hoobirdTestKeyPassword.isNullOrEmpty()

if (hoobirdTestKeyConfigured && !hoobirdTestKeyReady) {
    logger.warn(
        "HooBird test signing key is configured but not usable. Debug builds fall back to the normal debug key.",
    )
}

android {
    namespace = "dev.hoobird.spike.hoobird"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.hoobird.spike.hoobird"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hoobirdTestKeyReady) {
        signingConfigs {
            create("test") {
                storeFile = hoobirdTestStore
                storePassword = hoobirdTestStorePassword
                keyAlias = hoobirdTestKeyAlias
                keyPassword = hoobirdTestKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            if (hoobirdTestKeyReady) {
                signingConfig = signingConfigs.getByName("test")
            }
        }
        // Profile is created by the Flutter plugin as a copy of debug before this
        // block runs, so it does not follow the debug change on its own.
        findByName("profile")?.let { profile ->
            if (hoobirdTestKeyReady) {
                profile.signingConfig = signingConfigs.getByName("test")
            }
        }
        release {
            // A release key does not exist yet. This stays the stock debug key.
            // The dedicated test key must not sign a release.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            // Debug split APKs otherwise store libflutter.so uncompressed and also
            // pick up the Khronos Vulkan validation layer. HooBird does not call
            // that layer. Compressing the JNI libraries keeps the ABI split
            // produced by the build small enough to keep.
            useLegacyPackaging = true
            excludes += setOf("**/libVkLayer_khronos_validation.so")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
