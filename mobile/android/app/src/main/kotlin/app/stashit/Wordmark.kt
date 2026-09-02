package app.stashit

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File

/*
   ── The masthead, drawn by the app and shown by all three widgets ───────────

   It used to be two TextViews per layout — "Stash" in the text colour, "it" in
   gold — set in the app's typeface by a style that had to be split across
   values/ and values-v26/ because `@font/` does not exist below API 26.

   That was four things kept in step by hand (typeface, weight, letter spacing,
   two colours) against a fifth copy drawn in Flutter for the ring, and they did
   not stay in step: the ring's masthead was right and the other two were not.
   There is no way to make a TextView and a Flutter Text agree by inspection.

   So they no longer have to. lib/ui/widget_face.dart draws it, and
   lib/io/widget_mirror.dart renders it to two PNGs — dark ink and light — for
   the same reason the ring has two: a picture's colours are fixed the moment it
   is drawn, and the phone can be switched to dark mode while the app is not
   running to notice. The choice is made here, at the moment of drawing, where
   the launcher's own night setting can be read.

   It is small enough not to need the scaling `RingWidget.faceFor` does: the
   words are about 250 pixels across at 3x, which is a fifth of a megabyte
   through Binder against a budget of about one. The ring, for comparison, is
   2 MB unscaled.
*/
object Wordmark {

    /*
       Written by lib/io/widget_mirror.dart. Nothing checks these two strings
       against each other — a rename on one side is a widget that quietly loses
       its title — so both sides name them in one place and say so.
    */
    const val KEY_DARK = "words_dark"
    const val KEY_LIGHT = "words_light"

    /**
     * The masthead in the ink that suits the phone's current mode, or null
     * before the app has ever run.
     *
     * Null is a real state and not an error: a widget placed on the home screen
     * from the picker is drawn before the app has necessarily been opened since
     * the mirror last wrote. The layouts simply show an empty ImageView, which
     * is a widget with no title rather than a widget that failed — and the next
     * time the app runs, `mirrorWidgets` redraws every provider including this
     * one's.
     */
    fun of(context: Context, data: SharedPreferences): Bitmap? {
        val night = (context.resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        val path = data.getString(if (night) KEY_DARK else KEY_LIGHT, null)
            ?: return null

        if (!File(path).exists()) return null
        return BitmapFactory.decodeFile(path)
    }
}
