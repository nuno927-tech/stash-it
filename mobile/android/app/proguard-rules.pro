# R8 keep rules for the release build.
#
# ── Why this file exists ─────────────────────────────────────────────────────
# Shrinking was off until Play asked for it: "DEX code optimization is below our
# threshold — Obfuscation (1%)". One percent is what an app scores when R8 never
# runs at all. From February 2027 Play enforces a 25% floor, and before then it
# is a warning attached to the production review.
#
# ── The rule for what goes in here ───────────────────────────────────────────
# Only things reached in a way R8 cannot see: reflection, JNI, or a name written
# down as a string somewhere. Everything else is left alone deliberately.
#
# A blanket `-keep class io.flutter.** { *; }` would make this file safe and
# make the app score badly, because every class kept is a class not obfuscated —
# which is the metric Play is measuring. Broad keeps are how an app "fixes" this
# warning and fails it again.
#
# Two whole categories need nothing here, and it is worth writing down why:
#
#   The Dart code is not in the DEX. Drift's generated code, every model, every
#   screen — all of it compiles into libapp.so, which R8 never sees and cannot
#   break. `flutter build --obfuscate` is the separate switch for that, and it
#   has no bearing on this warning.
#
#   Anything named in AndroidManifest.xml is kept automatically. R8 parses the
#   manifest, so the notification receivers and the widget provider are already
#   safe without a line here.


# ── Attributes the reflection below depends on ───────────────────────────────
#
# Generic signatures are what Gson reads to know that a List<Something> holds
# Somethings. Stripped, it deserialises into a list of LinkedTreeMap and the
# failure lands wherever the value is first used, not where it was parsed.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod


# ── flutter_local_notifications ──────────────────────────────────────────────
#
# THE ONE THAT ACTUALLY BREAKS. Scheduled notifications are written to disk as
# JSON by Gson and read back by a receiver after a reboot, so the field names
# are the storage format — rename them and every pending reminder is silently
# dropped on the next restart. Nothing in the build says so; it fails months
# later, on somebody else's phone, in the feature this app exists for.
#
# One small package, so the cost to the obfuscation score is nothing.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**


# ── Gson itself ──────────────────────────────────────────────────────────────
#
# Type tokens work by subclassing a generic class and reading its own type
# parameter back at runtime. That only survives if the signature does.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken


# ── ML Kit's four other alphabets ────────────────────────────────────────────
#
# THESE CLASSES ARE GENUINELY NOT IN THE APP, AND THAT IS CORRECT.
#
# google_mlkit_text_recognition speaks five scripts — Latin, Chinese,
# Devanagari, Japanese, Korean — and its Java names all five in one method that
# picks between them. Only the Latin model is a dependency here, deliberately:
# it ships inside the app so a photographed receipt never leaves the phone, and
# it is about four megabytes. Adding four more to satisfy a reference nothing
# reaches would quadruple that for nothing.
#
# So R8 finds four names it cannot resolve and stops, which is the right
# instinct and the wrong answer here: `io/text_recognition.dart` only ever asks
# for Latin, so the branches that mention the others are unreachable. R8 will
# strip them once it is told not to worry.
#
# Copied verbatim from the missing_rules.txt R8 wrote when it failed, rather
# than from a wildcard — a `-dontwarn com.google.mlkit.**` would also silence
# the day something in ML Kit that IS used goes missing.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions


# ── What is deliberately absent ──────────────────────────────────────────────
#
# SQLCipher, Play Billing, secure storage, the camera and file pickers: every
# one of those ships its own consumer rules inside its .aar, which R8 applies
# automatically. Repeating them here would be a second copy to drift out of date
# with the plugin — and the reason to suspect one of them is a crash in a
# release build, not a guess made in advance.
