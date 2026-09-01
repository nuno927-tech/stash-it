package app.stashit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/*
   ── The ring, which is a photograph of itself ───────────────────────────────

   RemoteViews cannot draw an arc. It has no canvas, no custom views and no
   custom drawing of any kind — it is a list of stock widgets the launcher
   inflates in its own process. A dial with three coloured sweeps and a thin
   number in the middle is simply not expressible in it.

   So the app draws its own face into a PNG while it is running, and this shows
   the picture. lib/io/widget_mirror.dart is the other half and says what that
   costs: the ring is as fresh as the last time the app was open.

   Two files arrive, not one — a dark face and a light one. A picture's colours
   are fixed when it is drawn, and the phone can be switched to dark mode while
   the app is not running to notice, so the choice is made here, at the moment
   of drawing, where the launcher's own night setting can be read.
*/
class RingWidget : HomeWidgetProvider() {

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
       Redrawn when somebody resizes it.

       Without this the launcher keeps the bitmap it was given and stretches it,
       so a ring dragged from two cells to four is a 2x2 picture blown up. The
       source PNG is rendered large enough to fill the biggest sensible cell;
       this is what picks how much of it to actually send.
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

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        data: SharedPreferences,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_ring)

        val night = (context.resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        val path = data.getString(if (night) KEY_DARK else KEY_LIGHT, null)
        val face = path?.let { faceFor(it, sideOf(context, manager, id)) }

        if (face != null) {
            views.setImageViewBitmap(R.id.ring_image, face)
        }

        /*
           A screen reader cannot read a PNG. Without this the whole widget
           announces itself as "image", which makes it useless to precisely the
           person who most needs to be told a warranty has lapsed rather than
           shown it.
        */
        data.getString(KEY_WORDS, null)?.let {
            views.setContentDescription(R.id.ring_image, it)
        }

        views.setOnClickPendingIntent(R.id.ring_image, open(context))
        return views
    }

    /**
     * Decodes the rendered face and scales it to the size it will actually be
     * shown at.
     *
     * Not an optimisation. `setImageViewBitmap` sends the bitmap to the
     * launcher through Binder, and a Binder transaction is capped at about a
     * megabyte for the whole process — a 480px square at four bytes a pixel is
     * 920 KB of that on its own, which is close enough to the ceiling that a
     * second widget updating at the same moment can push it over. The symptom
     * is not an exception here; it is the launcher quietly showing nothing.
     */
    private fun faceFor(path: String, side: Int): Bitmap? {
        val file = File(path)
        if (!file.exists()) return null

        val full = BitmapFactory.decodeFile(path) ?: return null
        if (side <= 0 || side >= full.width) return full

        val scaled = Bitmap.createScaledBitmap(full, side, side, true)
        if (scaled != full) full.recycle()
        return scaled
    }

    /** The widget's current width in pixels, as the launcher reports it. */
    private fun sideOf(context: Context, manager: AppWidgetManager, id: Int): Int {
        val dp = manager.getAppWidgetOptions(id)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)

        if (dp <= 0) return 0
        return (dp * context.resources.displayMetrics.density).toInt()
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

    companion object {
        /*
           Written by lib/io/widget_mirror.dart. There is nothing that checks
           these two lists against each other — a rename on one side shows up as
           a blank widget and no error anywhere — so both sides name them in one
           place and say so.
        */
        const val KEY_DARK = "ring_dark"
        const val KEY_LIGHT = "ring_light"
        const val KEY_WORDS = "ring_words"

        /** Distinct from the Quick add rows, which use their own word's hash. */
        const val REQUEST_OPEN = 1
    }
}
