package app.stashit

import android.content.Context

/**
 * What one widget on the home screen has been told to show.
 *
 * ── Per widget, not per app ────────────────────────────────────────────────
 *
 * Somebody can have two Coming up widgets: one showing everything, one showing
 * only what needs attention. So these are keyed by the launcher's widget id
 * rather than stored once, and every read and write below carries that id.
 *
 * ── A separate file from the payload ───────────────────────────────────────
 *
 * The payload lives in home_widget's own preferences, written by Dart and
 * overwritten wholesale on every change. These are the user's choices and are
 * written by the settings screen, so they live somewhere the app cannot
 * casually stamp on.
 *
 * ── Defaults that survive an upgrade ───────────────────────────────────────
 *
 * A widget outlives the version of the app that placed it. Every getter below
 * defaults to "show it", so a setting added later reads as on rather than as
 * a widget that mysteriously went blank after an update.
 */
object WidgetSettings {

    private const val FILE = "app.stashit.widgets"

    private fun prefs(context: Context) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun showsItems(context: Context, id: Int): Boolean =
        prefs(context).getBoolean(key(id, "items"), true)

    fun showsPapers(context: Context, id: Int): Boolean =
        prefs(context).getBoolean(key(id, "papers"), true)

    fun showsSubscriptions(context: Context, id: Int): Boolean =
        prefs(context).getBoolean(key(id, "subscriptions"), true)

    /**
     * Whether things that are simply fine are worth a row.
     *
     * Off by default. A home screen list of what runs out next is more useful
     * showing the next six things than the next six URGENT things — somebody
     * who wanted only alarms would be better served by the notifications this
     * app already sends.
     */
    fun onlyUrgent(context: Context, id: Int): Boolean =
        prefs(context).getBoolean(key(id, "urgent"), false)

    fun accepts(context: Context, id: Int, kind: String): Boolean = when (kind) {
        "item" -> showsItems(context, id)
        "paper" -> showsPapers(context, id)
        "subscription" -> showsSubscriptions(context, id)
        // A kind this version has never heard of comes from a newer app. Show
        // it: a widget that silently drops rows is worse than one showing
        // something it cannot name.
        else -> true
    }

    fun save(
        context: Context,
        id: Int,
        items: Boolean,
        papers: Boolean,
        subscriptions: Boolean,
        onlyUrgent: Boolean,
    ) {
        prefs(context).edit()
            .putBoolean(key(id, "items"), items)
            .putBoolean(key(id, "papers"), papers)
            .putBoolean(key(id, "subscriptions"), subscriptions)
            .putBoolean(key(id, "urgent"), onlyUrgent)
            .apply()
    }

    /**
     * Called when a widget is removed from the home screen.
     *
     * Without this the file grows by four entries every time somebody adds and
     * removes a widget, forever, and a new widget can be handed the id — and
     * therefore the settings — of one deleted months ago.
     */
    fun forget(context: Context, ids: IntArray) {
        val editor = prefs(context).edit()
        for (id in ids) {
            for (name in listOf("items", "papers", "subscriptions", "urgent")) {
                editor.remove(key(id, name))
            }
        }
        editor.apply()
    }

    private fun key(id: Int, name: String) = "widget_${id}_$name"
}
