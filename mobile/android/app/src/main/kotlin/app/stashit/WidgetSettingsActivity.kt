package app.stashit

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.CheckBox

/*
   ── Choosing what one widget shows ──────────────────────────────────────────

   Android launches this when a widget with `android:configure` is dropped on
   the home screen, and again if somebody asks to reconfigure one.

   Three rules it has to follow, none of them obvious and all of them the sort
   that produce a widget that never appears:

     The result must carry EXTRA_APPWIDGET_ID back. Without it the launcher has
     no idea which widget was being configured and abandons the placement.

     The result must default to CANCELLED. If this activity is dismissed with
     the back gesture, the widget should not be placed at all — and a default
     of OK would leave a half-configured one behind.

     The widget must be redrawn here. Returning OK tells the launcher the
     placement succeeded; it does not ask the provider for a fresh view, so
     without the update below a newly configured widget shows nothing until
     something else happens to refresh it.

   Plain Android views rather than a Flutter route. This screen is four
   checkboxes, and reaching it through Flutter would mean starting a second
   engine — a second or so of blank screen — every time somebody drops a widget.
*/
class WidgetSettingsActivity : Activity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Cancelled unless the Save button says otherwise. Set before anything
        // that could fail, so an early return leaves the honest answer.
        setResult(RESULT_CANCELED)

        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_widget_settings)

        val items = findViewById<CheckBox>(R.id.settings_items)
        val papers = findViewById<CheckBox>(R.id.settings_papers)
        val subscriptions = findViewById<CheckBox>(R.id.settings_subscriptions)
        val urgent = findViewById<CheckBox>(R.id.settings_urgent)

        // Opened on what this widget already shows, which matters on the second
        // visit: a reconfigure screen that opens on the defaults looks like it
        // has forgotten, and invites somebody to "fix" settings that were fine.
        items.isChecked = WidgetSettings.showsItems(this, widgetId)
        papers.isChecked = WidgetSettings.showsPapers(this, widgetId)
        subscriptions.isChecked = WidgetSettings.showsSubscriptions(this, widgetId)
        urgent.isChecked = WidgetSettings.onlyUrgent(this, widgetId)

        findViewById<Button>(R.id.settings_save).setOnClickListener {
            WidgetSettings.save(
                context = this,
                id = widgetId,
                items = items.isChecked,
                papers = papers.isChecked,
                subscriptions = subscriptions.isChecked,
                onlyUrgent = urgent.isChecked,
            )

            redraw()

            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
            )
            finish()
        }
    }

    /*
       Redrawn here rather than left to the provider's own update cycle, which
       for this widget is "never": updatePeriodMillis is 0 and the app may not
       run again for hours. Somebody who has just chosen what to show should
       see it immediately.
    */
    private fun redraw() = ComingUpWidget.refresh(this, intArrayOf(widgetId))
}
