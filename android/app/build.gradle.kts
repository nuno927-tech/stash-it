import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/*
   ── The upload key, read from a file that is not in the repository ──────────

   `android/key.properties` holds the passwords and the path to the keystore.
   It is gitignored, and so is the keystore itself — see the note in
   .gitignore on why this one secret matters more than the others.

   Absent, the release build falls back to the debug key. That is deliberate:
   a fresh clone should still be able to run `flutter run --release` to check
   performance, and failing the build with "no signing config" for somebody who
   only wants to look at the app is a worse trade than a build they cannot
   publish. `signingReady` below is what makes the difference visible.
*/
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
val signingReady = keyPropertiesFile.exists()
if (signingReady) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "app.stashit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // flutter_local_notifications uses java.time, which arrived in API 26.
        // Desugaring back-ports it so the app still runs on Android 6, which is
        // where minSdk is set — see the note below.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Permanent, and chosen deliberately. Changing it after a Play Store
        // release means a new app with zero installs.
        applicationId = "app.stashit"

        // Android 6. Set here rather than left at Flutter's default because
        // sqlcipher_flutter_libs will not build below it — and because the
        // alternative to encryption on old handsets is not "encryption later",
        // it is a plaintext database on the phones least likely to be patched.
        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingReady) {
            create("release") {
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                storeFile = keyProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keyProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingReady) {
                signingConfigs.getByName("release")
            } else {
                // Runnable, not publishable. Play rejects a debug-signed upload.
                signingConfigs.getByName("debug")
            }

            /*
               ── Shrinking is off, and this is a decision ────────────────────

               R8 strips classes nothing appears to reference, and three things
               in this app are reached in ways it cannot see: SQLCipher's
               native bindings, Drift's generated code, and the notification
               receivers named as strings in AndroidManifest.xml.

               The failure mode is the bad one — it builds, it installs, and it
               throws on the first database open, on a release build, on
               somebody else's phone. The app is a few megabytes of Dart and a
               SQLite binary; the download saved is not worth that risk before
               there is a single user. Revisit with `--analyze-size` once the
               store listing exists.
            */
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
