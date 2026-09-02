package app.stashit

import android.appwidget.AppWidgetManager
import android.content.ComponentName
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

    /*
       ── And the same again for the Quick add widget ──────────────────────────

       A widget row hands over a word — "item", "paper", "subscription" — rather
       than a file. It rides the same channel and the same take-once rule, for
       the same reason: Dart asks on start and on resume because it cannot know
       which of those the tap arrived on, and a value left behind would reopen
       the add sheet every time somebody came back to the app.
    */
    private var pendingAdd: String? = null

    private var messenger: MethodChannel? = null

    /*
       ── The folder picker is the one call that has to wait ──────────────────

       Everything else on this channel answers immediately. Choosing a backup
       folder opens Android's own picker, which is another activity, and the
       answer arrives in `onActivityResult` some seconds later — after the
       person has browsed, or changed their mind, or gone to make tea.

       So the `Result` is parked here and completed there. One at a time: a
       second request while a picker is open is a stale one, and answering it
       with null is kinder than leaving Dart waiting on a future that never
       resolves.
    */
    private var pendingFolder: MethodChannel.Result? = null

    /*
       ── `this` inside the handler is not the activity ────────────────────────

       The channel is built with `.apply { setMethodCallHandler { ... } }`, and
       inside an `apply` the receiver is the MethodChannel. So a bare `this`
       passed to anything wanting a Context compiles to a type error — and
       nothing catches it until an Android build, because the Dart analyzer
       never reads Kotlin.

       Every call in the handler that needs a Context says `this@MainActivity`
       out loud for that reason.
    */

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pending = copyOf(intent)
        pendingAdd = intent?.getStringExtra(QuickAddWidget.EXTRA_ADD)

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

                    "takeAdd" -> {
                        result.success(pendingAdd)
                        pendingAdd = null
                    }

                    /*
                       ── Asking the launcher to place a widget ─────────────────

                       Widgets are the one part of this app that lives somewhere
                       the app cannot reach: adding one means long-pressing the
                       home screen, finding a picker, scrolling to S. Settings
                       could only ever have described that.

                       Android 8.0 added `requestPinAppWidget`, which asks the
                       launcher to do it — the launcher shows its own confirm
                       dialog, so this is a request and not a grab. minSdk is 26,
                       so there is no version to guard against; what there IS to
                       guard against is a launcher that does not implement it,
                       which is what `isRequestPinAppWidgetSupported` answers.
                       Settings asks that first and falls back to the sentence.
                    */
                    "canPin" -> result.success(
                        AppWidgetManager.getInstance(this@MainActivity)
                            .isRequestPinAppWidgetSupported
                    )

                    "pin" -> {
                        val which = call.arguments as? String
                        val provider = when (which) {
                            "ring" -> RingWidget::class.java
                            "comingUp" -> ComingUpWidget::class.java
                            "quickAdd" -> QuickAddWidget::class.java
                            else -> null
                        }

                        if (provider == null) {
                            result.success(false)
                        } else {
                            val manager = AppWidgetManager.getInstance(this@MainActivity)
                            /*
                               No callback intent.

                               The third argument is a PendingIntent fired once
                               the widget is placed, and there is nothing this
                               app wants to do at that moment: the widget draws
                               itself from the mirror that is already written.
                               An unused callback is a broadcast receiver to keep
                               alive for no reason.
                            */
                            val target = ComponentName(this@MainActivity, provider)
                            result.success(
                                manager.requestPinAppWidget(target, null, null)
                            )
                        }
                    }

                    /* ------------------------------------ the backup folder */

                    "pickFolder" -> {
                        pendingFolder?.success(null)
                        pendingFolder = result
                        startActivityForResult(BackupFolder.picker(), PICK_FOLDER)
                    }

                    "folderGranted" -> result.success(
                        BackupFolder.granted(this@MainActivity, call.arguments as String)
                    )

                    "folderLabel" -> result.success(
                        BackupFolder.label(this@MainActivity, call.arguments as String)
                    )

                    "forgetFolder" -> {
                        BackupFolder.forget(this@MainActivity, call.arguments as String)
                        result.success(true)
                    }

                    "writeToFolder" -> result.success(
                        BackupFolder.write(
                            this@MainActivity,
                            call.argument<String>("tree")!!,
                            call.argument<String>("name")!!,
                            call.argument<String>("from")!!,
                        )
                    )

                    "listFolder" -> result.success(
                        BackupFolder.list(this@MainActivity, call.arguments as String)
                    )

                    "deleteInFolder" -> result.success(
                        BackupFolder.delete(this@MainActivity, call.arguments as String)
                    )

                    else -> result.notImplemented()
                }
            }
        }
    }

    /*
       Back from the folder picker.

       `RESULT_OK` with a URI is the only success. Everything else — cancelled,
       backed out of, a provider that failed to open — resolves null, and Dart
       reads that as "nothing was chosen" rather than as a failure worth
       reporting: somebody who changed their mind has not hit a problem.
    */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_FOLDER) return

        val waiting = pendingFolder ?: return
        pendingFolder = null

        val tree = if (resultCode == RESULT_OK) data?.data else null
        if (tree == null) {
            waiting.success(null)
            return
        }

        // Before anything else: without this the grant lasts until the process
        // dies, and the next backup would fail with a permission the app
        // appears to hold.
        runCatching { BackupFolder.keep(this, tree) }

        waiting.success(tree.toString())
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

        val add = intent.getStringExtra(QuickAddWidget.EXTRA_ADD)
        if (add != null) {
            pendingAdd = add
            messenger?.invokeMethod("add", add)
            return
        }

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

    companion object {
        /*
           The request code for the folder picker.

           Deliberately far from anything the plugins use — image_picker,
           file_picker and local_auth all run activities through this same
           activity, and a collision would hand one of them our result or hand
           us theirs. `onActivityResult` checks for this number and returns
           immediately on anything else.
        */
        private const val PICK_FOLDER = 4201
    }
}
