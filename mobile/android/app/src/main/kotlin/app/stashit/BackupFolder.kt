package app.stashit

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.DocumentsContract
import java.io.File

/*
   ── A folder the app may write to, for as long as it is installed ───────────

   The backup is the only copy of somebody's data that can survive the phone —
   the database is encrypted with a key that never leaves this handset, so a
   lost phone is a lost collection. Until now the only defence was a
   notification asking somebody to do something by hand, which works on the
   people who do things by hand.

   Android's Storage Access Framework is the way to fix that without the app
   growing a network permission, an account or a server. The person picks one
   folder, once; Android hands back a URI and a PERSISTABLE grant that survives
   reboots and app updates; the app writes there on a schedule and never sees
   anything else on the device.

   Which folder is entirely theirs. Internal storage, an SD card, a USB stick,
   or whatever cloud provider publishes a document tree on that phone — Drive,
   Dropbox, OneDrive, a Synology share. The app does not know and does not
   care: it asks the platform for a folder and writes to what comes back. That
   is why there is no list of supported services anywhere in this file.

   ── What it deliberately cannot do ──────────────────────────────────────────

   Read anything. The grant covers one tree and the app only ever writes into
   it, lists its own backups by name, and deletes the ones it wrote. It cannot
   see the rest of the storage, and revoking it is one tap in Android's own
   settings.
*/
object BackupFolder {

    /** Both halves of the grant, in the form `takePersistableUriPermission` wants. */
    private const val GRANT = Intent.FLAG_GRANT_READ_URI_PERMISSION or
        Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    /**
     * The intent that asks for a folder.
     *
     * `FLAG_GRANT_PERSISTABLE_URI_PERMISSION` is the whole point: without it
     * the grant dies with the process, and an automatic backup that only works
     * until the phone is next restarted is worse than none, because it looks
     * like it is working.
     */
    fun picker(): Intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
        addFlags(GRANT or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
    }

    /** Keeps the grant across reboots. Called once, on the way back from the picker. */
    fun keep(context: Context, tree: Uri) {
        context.contentResolver.takePersistableUriPermission(tree, GRANT)
    }

    /** Gives it back. The app should hold no permission it is not using. */
    fun forget(context: Context, tree: String) {
        runCatching {
            context.contentResolver
                .releasePersistableUriPermission(Uri.parse(tree), GRANT)
        }
    }

    /**
     * Whether the grant is still held.
     *
     * ── Held is not the same as reachable ──────────────────────────────────
     *
     * A grant can survive while the folder behind it cannot be written to: a
     * cloud provider signed out, an SD card removed, a folder deleted from the
     * other end. This answers the first question only, cheaply, so Settings can
     * tell "you never chose one" from "you chose one and Android has forgotten
     * it" — usually because the app was reinstalled.
     *
     * Whether a write will actually land is answered by trying, which is what
     * `write` reports and what the Settings line reads.
     */
    fun granted(context: Context, tree: String): Boolean {
        val wanted = Uri.parse(tree)
        return context.contentResolver.persistedUriPermissions.any {
            it.uri == wanted && it.isWritePermission
        }
    }

    /** What to call the folder on screen. Null when it cannot be read. */
    fun label(context: Context, tree: String): String? {
        val uri = folderUri(Uri.parse(tree))

        return query(
            context.contentResolver,
            uri,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
        ) { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }

    /**
     * Copies a file into the folder, replacing any file already there under
     * that name.
     *
     * Returns the name the provider actually gave it, which is not always the
     * name asked for: some providers append an extension of their own choosing
     * based on the mime type. The app reports back what landed rather than what
     * it wanted, because a Settings line that names a file nobody can find is
     * worse than one that names an odd file somebody can.
     *
     * The bytes come from a path rather than through the method channel. A
     * backup with photographs in it is megabytes, and a platform channel is the
     * wrong pipe for that when both ends can see the same filesystem.
     */
    fun write(context: Context, tree: String, name: String, from: String): String? {
        val source = File(from)
        if (!source.exists()) return null

        val resolver = context.contentResolver
        val folder = folderUri(Uri.parse(tree))

        // Replace rather than let the provider make "name (1)". A backup is
        // named for its date, and two files for one day is the confusing
        // outcome, not the safe one.
        childNamed(context, tree, name)?.let { existing ->
            runCatching { DocumentsContract.deleteDocument(resolver, existing) }
        }

        val created = DocumentsContract.createDocument(
            resolver,
            folder,
            "application/octet-stream",
            name,
        ) ?: return null

        resolver.openOutputStream(created)?.use { out ->
            source.inputStream().use { input -> input.copyTo(out) }
        } ?: return null

        return query(
            resolver,
            created,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
        ) { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else name
        }
    }

    /**
     * The names of everything in the folder, newest first.
     *
     * Used to prune old backups. Everything is listed rather than only what
     * matches — the caller decides what is one of ours, in Dart, where it can
     * be tested without a phone.
     */
    fun list(context: Context, tree: String): List<Map<String, Any?>> {
        val treeUri = Uri.parse(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )

        val out = mutableListOf<Map<String, Any?>>()

        query(
            context.contentResolver,
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            ),
        ) { cursor ->
            while (cursor.moveToNext()) {
                out.add(
                    mapOf(
                        "uri" to DocumentsContract
                            .buildDocumentUriUsingTree(treeUri, cursor.getString(0))
                            .toString(),
                        "name" to cursor.getString(1),
                        "at" to if (cursor.isNull(2)) null else cursor.getLong(2),
                    )
                )
            }
        }

        return out
    }

    /** Deletes one document the app wrote. */
    fun delete(context: Context, document: String): Boolean = runCatching {
        DocumentsContract.deleteDocument(
            context.contentResolver,
            Uri.parse(document),
        )
    }.getOrDefault(false)

    /* ------------------------------------------------------------- plumbing */

    /** The tree's own document, which is what `createDocument` wants as a parent. */
    private fun folderUri(tree: Uri): Uri = DocumentsContract.buildDocumentUriUsingTree(
        tree,
        DocumentsContract.getTreeDocumentId(tree),
    )

    private fun childNamed(context: Context, tree: String, name: String): Uri? =
        list(context, tree)
            .firstOrNull { it["name"] == name }
            ?.get("uri")
            ?.let { Uri.parse(it as String) }

    /**
     * A query that always closes its cursor and never throws.
     *
     * Every call here is against a provider in another process which may be
     * signed out, uninstalled or simply gone. None of that is exceptional
     * enough to crash the app that was only trying to make a backup.
     */
    private fun <T> query(
        resolver: ContentResolver,
        uri: Uri,
        columns: Array<String>,
        read: (Cursor) -> T?,
    ): T? = runCatching {
        resolver.query(uri, columns, null, null, null)?.use(read)
    }.getOrNull()
}
