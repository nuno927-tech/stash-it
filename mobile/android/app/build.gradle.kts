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

/*
   ── The two SDK levels are pinned, not inherited ────────────────────────────

   Both of these read `flutter.compileSdkVersion` / `flutter.targetSdkVersion`
   until 0.61.2, which means "whichever Android version this laptop's Flutter
   install happens to default to". That is a fine default for a hobby project
   and the wrong one for something with a submission deadline attached.

   From 31 August 2026 Play rejects a NEW app that does not target Android 16
   (API 36). Flutter's default trails the platform by design — it moves when a
   Flutter release moves it, not when Play's rule changes — so the version that
   gets built depends on when the machine last ran `flutter upgrade`. Nothing
   in the project would say which number was used; it would surface as a
   rejected upload with a number in it that appears nowhere in this repository.

   So the number lives here, where it can be read, diffed and blamed.

   compileSdk is what the code is COMPILED against — which APIs exist.
   targetSdk is what the app CLAIMS to support — which behaviours Android
   applies to it. They are the same number here, and usually should be: a
   compileSdk ahead of targetSdk means compiling against APIs whose new
   behaviour is switched off, which is the confusing half of both worlds.

   Bumping targetSdk is never only a number. Android 16 makes edge-to-edge
   drawing mandatory, so the app now paints behind the status and navigation
   bars whether it asked to or not. Anything at the very top or bottom of a
   screen that is not inside a `SafeArea` will sit underneath them. Check the
   tab bar, the add button, and the top of every bottom sheet on a real device
   before this ships.
*/
android {
    namespace = "app.stashit"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        /*
           flutter_local_notifications uses java.time, which arrived in API 26.

           minSdk is now 26 as well, so nothing here needs back-porting any
           more and this could go. It stays because it costs a few hundred
           kilobytes and removing it turns any future lowering of the floor
           into a link error nobody would connect to this line.
        */
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Permanent, and chosen deliberately. Changing it after a Play Store
        // release means a new app with zero installs.
        applicationId = "app.stashit"

        /*
           ── Pinned, and pinned high on purpose ──────────────────────────────

           This was `flutter.minSdkVersion`, which is not a number — it is
           whatever the installed Flutter happens to default to that month. The
           floor of an app decides which phones can install it at all, and
           having it move when somebody upgrades their tools is the wrong kind
           of surprise: raising it silently drops people who already have the
           app installed.

           26 is Android 8.0, which is about 99% of active devices. The 1% is a
           real cost and it buys something specific — everything the app does
           works there with no fallbacks:

             Home screen widgets can load a font from res/font/. That starts at
             26 exactly, and an unresolvable font reference does not degrade,
             it stops the widget inflating.

             Widget icons are vector drawables. Those are unreliable inside
             RemoteViews below API 24 and can throw while the LAUNCHER inflates
             them, which reaches the home screen as "an error occurred loading
             widget" and cannot be caught here.

           Both of those are already written defensively, and at 26 neither
           defence can ever run. Kept anyway: a floor that gets lowered later
           should not silently break the widgets.

           Raise this only with a reason. Lowering it is free; raising it after
           release is not.
        */
        minSdk = 26

        targetSdk = 36
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
               ── Shrinking is on, and the old reasons did not survive ────────

               This read "shrinking is off, and this is a decision" and gave
               three things R8 could not see: SQLCipher's native bindings,
               Drift's generated code, and the notification receivers named as
               strings in AndroidManifest.xml. Two of those were wrong.

               Drift generates DART. It compiles into libapp.so, which R8 never
               opens — there was never anything there to strip. And R8 parses
               AndroidManifest.xml, so a receiver named in it is kept without
               anybody asking. Only the third was real, and the plugins that
               need reflection ship their own keep rules inside their .aar.

               What settled it was Play: "DEX code optimization is below our
               threshold — Obfuscation (1%)". One percent is the score for an
               app where R8 never ran. It is a warning on the production review
               now and a 25% floor from February 2027.

               The old note's fear is still the right one to hold — the failure
               mode is a build that installs and throws on somebody else's
               phone. That is what proguard-rules.pro is for, and it is why a
               release build gets exercised on a real device before it is
               uploaded rather than after.
            */
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            /*
               Resources are a separate question and the answer is still no.

               Play measures the DEX, and resource shrinking does not touch it —
               turning this on would buy nothing against the warning and add the
               one failure this app is least able to see coming: a drawable or a
               font stripped because only a home screen widget referenced it, in
               a process that is not ours, on a launcher we cannot test in CI.
            */
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
