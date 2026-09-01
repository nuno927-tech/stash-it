package app.stashit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/*
   ── Three ways into the app, and no data at all ─────────────────────────────

   The only widget that copies nothing out of the encrypted database. Everything
   it draws is a fixed label, so there is nothing here that a launcher could
   leak and nothing to keep in step with the app's contents.

   That is also why it was built first: it exercises the whole pipeline — a
   provider, the manifest entry, size buckets, tap routing back into Flutter —
   without any of the privacy weight the other two carry. If this works on a
   phone, the two that show real records are a data problem rather than an
   Android one.
*/
class QuickAddWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        for (id in ids) {
            manager.updateAppWidget(id, build(context))
        }
    }

    private fun build(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_add)

        views.setOnClickPendingIntent(R.id.quick_add_item, open(context, ADD_ITEM))
        views.setOnClickPendingIntent(R.id.quick_add_paper, open(context, ADD_PAPER))
        views.setOnClickPendingIntent(R.id.quick_add_sub, open(context, ADD_SUB))

        return views
    }

    /*
       One PendingIntent per row, and they must not collide.

       `PendingIntent` identity ignores extras, so three intents differing only
       by an extra would be one intent as far as the system is concerned — every
       row would open whichever was created last. The request code is what makes
       them distinct, and `FLAG_UPDATE_CURRENT` then refreshes the extras of the
       one that already exists rather than handing back a stale copy.
    */
    private fun open(context: Context, what: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra(EXTRA_ADD, what)

            // SINGLE_TOP so a running app is brought forward and given the
            // intent through onNewIntent, rather than a second copy being
            // stacked on the first.
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        return PendingIntent.getActivity(
            context,
            what.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        /** Read by `MainActivity` and passed to Dart. */
        const val EXTRA_ADD = "app.stashit.ADD"

        const val ADD_ITEM = "item"
        const val ADD_PAPER = "paper"
        const val ADD_SUB = "subscription"
    }
}
