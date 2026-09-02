package app.stashit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/*
   ── What runs out next ──────────────────────────────────────────────────────

   The one widget built from real views rather than from a rendered picture,
   and the reason is what a list IS. Dragging a list taller means "show me
   more". A picture can only get bigger — the same three rows in larger type —
   which turns the most natural gesture on a home screen into a disappointment.

   So the lines cross as JSON and this lays them out, which is also what lets it
   count how many will actually fit in the cell somebody chose.

   ── What is in the JSON, and what is deliberately not ───────────────────────

   A title, a countdown, and a tone: "fine", "soon", "late_". That is the whole
   payload. No prices, no serial numbers, no notes, no photographs — see
   lib/logic/widget_payload.dart, which decides it, and the privacy policy,
   which promises it. Everything here is a plaintext copy living outside the
   encrypted database, because that is what a widget requires, so the copy is
   kept to exactly the face on the screen.

   The tone travels as a NAME. A colour would be a second copy of the palette
   and the one nobody remembers to change when the theme moves.
*/
class ComingUpWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                id,
                build(context, appWidgetManager, id, widgetData),
            )
        }
    }

    /*
       Resized, which for this widget is a real question rather than a redraw.

       How many rows fit is a function of how tall the cell is, and only the
       launcher knows that. Without this, a widget dragged from three rows to
       six would keep showing three.
    */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)

        appWidgetManager.updateAppWidget(
            appWidgetId,
            build(
                context,
                appWidgetManager,
                appWidgetId,
                HomeWidgetPlugin.getData(context),
            ),
        )
    }

    /*
       Removed from the home screen.

       Its settings go with it. Otherwise the preferences file grows by four
       entries every time somebody adds and removes a widget, and — worse — a
       new widget can be handed the id of one deleted months ago, along with
       whatever that one had been told to show.
    */
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        WidgetSettings.forget(context, appWidgetIds)
    }

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        data: SharedPreferences,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_coming_up)
        // The whole card opens the app, not just the caption — a list of
        // things running out is not a place to hunt for the tap target.
        views.setOnClickPendingIntent(R.id.coming_up_root, open(context))
        views.setOnClickPendingIntent(R.id.coming_up_settings, settings(context, id))

        // The masthead, drawn by the app so all three widgets show the same
        // one. Null before the app has ever run — see `Wordmark.of`.
        Wordmark.of(context, data)?.let {
            views.setImageViewBitmap(R.id.coming_up_wordmark, it)
        }

        val payload = data.getString(KEY, null)?.let {
            runCatching { JSONObject(it) }.getOrNull()
        }

        /*
           Filtered HERE, not in Dart, because one payload is written for the
           whole phone and every widget on the home screen has its own
           settings — somebody can have one showing everything and another
           showing only subscriptions. See WidgetSettings.
        */
        val lines = wanted(context, id, payload?.optJSONArray("lines"))
        val room = roomFor(context, manager, id)
        val showing = minOf(lines.size, room, ROWS.size)

        /*
           The empty sentence comes from Dart, because which emptiness this is
           depends on the database: "Nothing stashed yet" is fixed by adding
           something and "Nothing coming up" is not, and the wrong one sends
           somebody to the wrong place.
        */
        if (showing == 0) {
            views.setViewVisibility(R.id.coming_up_empty, View.VISIBLE)

            val nothingChosen = !WidgetSettings.showsItems(context, id) &&
                !WidgetSettings.showsPapers(context, id) &&
                !WidgetSettings.showsSubscriptions(context, id)

            views.setTextViewText(
                R.id.coming_up_empty,
                if (nothingChosen) {
                    // Only this side knows the boxes were unticked, and it is
                    // the one emptiness fixed by the settings screen rather
                    // than by adding something to the app.
                    context.getString(R.string.widget_nothing_chosen)
                } else {
                    payload?.optString("empty")?.takeIf { it.isNotEmpty() }
                        ?: context.getString(R.string.widget_coming_up_label)
                },
            )
        } else {
            views.setViewVisibility(R.id.coming_up_empty, View.GONE)
        }

        for ((index, row) in ROWS.withIndex()) {
            if (index >= showing) {
                views.setViewVisibility(row.container, View.GONE)
                continue
            }

            val line = lines[index]
            views.setViewVisibility(row.container, View.VISIBLE)
            views.setTextViewText(row.title, line.optString("title"))
            views.setTextViewText(row.value, line.optString("value"))
            views.setTextViewText(row.unit, line.optString("unit"))

            // ContextCompat, not context.getColor: that one starts at API 23
            // and this app still supports older phones.
            val tone = ContextCompat.getColor(context, colourOf(line.optString("tone")))
            views.setTextColor(row.value, tone)
        }

        return views
    }

    /**
     * The lines this particular widget was told to show.
     *
     * Two questions, in the order somebody would ask them: is this a kind I
     * want, and — if the widget is set to only what needs attention — is it
     * actually pressing? "fine" is the tone for something with months left.
     */
    private fun wanted(
        context: Context,
        id: Int,
        all: JSONArray?,
    ): List<JSONObject> {
        if (all == null) return emptyList()

        val urgentOnly = WidgetSettings.onlyUrgent(context, id)
        val kept = mutableListOf<JSONObject>()

        for (index in 0 until all.length()) {
            val line = all.optJSONObject(index) ?: continue

            if (!WidgetSettings.accepts(context, id, line.optString("kind"))) {
                continue
            }
            if (urgentOnly && line.optString("tone") == "fine") continue

            kept.add(line)
        }

        return kept
    }

    /**
     * How many rows the cell has room for.
     *
     * Each row is about 28dp with its padding, under a masthead of about 40.
     * Deliberately conservative: a row that half fits is clipped by the
     * launcher where nothing can see it, and one row of white space looks
     * intentional while half a row looks broken.
     */
    private fun roomFor(context: Context, manager: AppWidgetManager, id: Int): Int {
        val dp = manager.getAppWidgetOptions(id)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)

        if (dp <= 0) return 3
        return ((dp - MASTHEAD_DP) / ROW_DP).coerceIn(1, ROWS.size)
    }

    /** A tone name from the payload becomes a colour from our own resources. */
    private fun colourOf(tone: String): Int = when (tone) {
        "fine" -> R.color.widget_moss
        "soon" -> R.color.widget_honey
        "late_" -> R.color.widget_ember
        // An unknown tone is a payload from a newer version of the app than
        // this launcher has drawn before. Muted is the honest answer: it shows
        // the countdown without claiming to know how urgent it is.
        else -> R.color.widget_muted
    }

    /**
     * Opens this widget's settings, from the widget.
     *
     * The launcher has its own way in — long-press, then a reconfigure button —
     * and it cannot be relied on. It is an Android 12 feature, several
     * launchers never show it, and a widget placed before the app declared
     * itself reconfigurable never gains it. Settings nobody can reach are not
     * settings.
     *
     * The request code is the widget id, and has to be: PendingIntent identity
     * ignores extras, so two widgets would otherwise share one intent and the
     * second cog would open the first widget's settings.
     */
    private fun settings(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, WidgetSettingsActivity::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_CONFIGURE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        return PendingIntent.getActivity(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun open(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        return PendingIntent.getActivity(
            context,
            REQUEST_OPEN,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** One row's four ids, so the loop above can stay a loop. */
    private data class Row(
        val container: Int,
        val title: Int,
        val value: Int,
        val unit: Int,
    )

    companion object {

        /**
         * Redraw specific widgets now.
         *
         * Used by the settings screen, which cannot wait for the provider's
         * own update cycle: `updatePeriodMillis` is 0 and the app may not run
         * again for hours. Somebody who has just chosen what to show should
         * see it before the screen closes.
         */
        fun refresh(context: Context, ids: IntArray) {
            val manager = AppWidgetManager.getInstance(context)
            val provider = ComingUpWidget()

            provider.onUpdate(context, manager, ids, HomeWidgetPlugin.getData(context))
        }

        /** Written by lib/io/widget_mirror.dart as `comingUpKey`. */
        const val KEY = "coming_up"

        /** Distinct from RingWidget's and from each Quick add row's. */
        const val REQUEST_OPEN = 2

        private const val ROW_DP = 28
        private const val MASTHEAD_DP = 44

        /*
           Six, matching `widgetMaxLines` in lib/logic/widget_payload.dart.

           RemoteViews cannot build a view in a loop, so every row this reaches
           by id has to exist in the XML by id — which is why the layout is six
           copies of the same eleven lines. If that number ever changes it has
           to change in three places, and this comment is the only thing that
           will say so.
        */
        private val ROWS = listOf(
            Row(R.id.row_0, R.id.row_0_title, R.id.row_0_value, R.id.row_0_unit),
            Row(R.id.row_1, R.id.row_1_title, R.id.row_1_value, R.id.row_1_unit),
            Row(R.id.row_2, R.id.row_2_title, R.id.row_2_value, R.id.row_2_unit),
            Row(R.id.row_3, R.id.row_3_title, R.id.row_3_value, R.id.row_3_unit),
            Row(R.id.row_4, R.id.row_4_title, R.id.row_4_value, R.id.row_4_unit),
            Row(R.id.row_5, R.id.row_5_title, R.id.row_5_value, R.id.row_5_unit),
        )
    }
}
