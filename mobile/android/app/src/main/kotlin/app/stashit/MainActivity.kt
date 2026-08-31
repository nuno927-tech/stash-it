package app.stashit

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/*
   FlutterFragmentActivity, not FlutterActivity.

   The biometric prompt is a Fragment — androidx.biometric puts it in the host
   activity's fragment manager — and a plain FlutterActivity has no fragment
   manager to put it in. `local_auth` answers that by reporting no biometrics
   available at all rather than by failing when asked, so the switch in
   Settings simply never appeared and there was nothing to debug.

   It is a drop-in swap: FlutterFragmentActivity is a FragmentActivity that
   hosts the same Flutter engine, and nothing else in the app can tell.
*/
class MainActivity : FlutterFragmentActivity() {

    /*
       ── Handing a tapped .stashcard to Dart ────────────────────────────────

       The manifest claims the extension, so Android will launch this activity
       with the file in the intent. Getting from there to the arrival screen
       needs native code for one specific reason: a card arriving from a
       messaging app is a `content://` URI, and `content://` cannot be opened
       by dart:io. Only the platform's ContentResolver can read it.

       So this reads the bytes, writes them to the app's own cache, and hands
       Dart a plain path it can open with File(). The copy is deliberate rather
       than lazy — the permission to read a content:// URI is granted to this
       activity for this launch, and can be gone by the time Dart gets round to
       asking.

       There is no dependency for this. `receive_sharing_intent` and friends do
       the same twenty lines plus a stream abstraction this app does not need,
       and every package added here is another thing to keep compiling against
       a moving Android SDK.
    */
    private val channel = "app.stashit/incoming"

    /** Set on launch or on a new intent; taken exactly once by Dart. */
    private var pending: String? = null

    private var messenger: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pending = copyOf(intent)

        messenger = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    /*
                       Taken rather than read, and cleared here rather than by
                       the caller.

                       Dart asks on start and again on every resume, because it
                       cannot know which of those the file arrived on. Leaving
                       the value behind would mean the arrival screen reopening
                       every time somebody came back to the app, on a card they
                       already dealt with.
                    */
                    "take" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /*
       A second card, tapped while the app is already open.

       Android delivers this to the running activity instead of starting a new
       one, so without this the file would be silently dropped and the app
       would just come to the foreground showing whatever it was showing.
    */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val path = copyOf(intent) ?: return
        pending = path
        messenger?.invokeMethod("arrived", path)
    }

    /**
     * Copies the intent's payload into the cache and returns its path, or null
     * when the intent carries nothing this app should open.
     */
    private fun copyOf(intent: Intent?): String? {
        val uri: Uri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        } ?: return null

        return try {
            /*
               The name is taken from the URI's last segment where there is one,
               and falls back to a fixed name.

               It matters only for the extension: `parseCardBytes` decides what
               a file is from its manifest, never from its name, so a wrong
               guess here cannot let a backup through the card door. The name is
               for the cache directory's benefit, not for the parser's.
            */
            val name = uri.lastPathSegment
                ?.substringAfterLast('/')
                ?.takeIf { it.endsWith(".stashcard") }
                ?: "incoming.stashcard"

            val target = File(cacheDir, name)
            contentResolver.openInputStream(uri).use { input ->
                if (input == null) return null
                target.outputStream().use { output -> input.copyTo(output) }
            }
            target.absolutePath
        } catch (e: Exception) {
            // A file that cannot be read is not an error worth crashing for —
            // Dart shows nothing, and Settings still has the picker.
            null
        }
    }
}
