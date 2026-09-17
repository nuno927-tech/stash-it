package app.stashit

import android.graphics.Bitmap
import android.graphics.BitmapFactory

/*
   ── Reading a PNG without reading all of it ─────────────────────────────────

   Both widget pictures are drawn by Flutter and written to disk by
   lib/io/widget_mirror.dart, then read back here and pushed to the launcher.
   Every one of those was decoded at full resolution first and shrunk after,
   which is the wrong order: the peak memory is the full-size bitmap, and the
   shrinking happens once it has already been paid for.

   Play's pre-launch check named it — "using BitmapFactory without
   downsampling" — and the reason it gives is the right one. The sizes are
   comfortable TODAY. They are comfortable because of a font size chosen in a
   Dart file that knows nothing about this, and the day somebody makes the
   masthead bigger there is nothing here to notice.

   So the bound lives here, next to the decode, rather than in the arithmetic
   of whoever happens to be drawing.
*/
object Bitmaps {

    /**
     * Decodes [path] at roughly [want] pixels wide or less, or null if it is
     * not a picture.
     *
     * ── Two passes, and the first one reads no pixels ───────────────────────
     * `inJustDecodeBounds` makes the first call fill in the dimensions and
     * decode nothing at all, so the size is known before a single byte of
     * image is allocated. That is the whole trick, and it is the only way to
     * choose a sample size honestly: anything else guesses.
     */
    fun atMost(path: String, want: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)

        // A file that is not an image, or one half-written by the mirror while
        // the launcher happened to ask. Null here is the same "no picture yet"
        // the callers already handle.
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleFor(bounds.outWidth, want)
        }

        return BitmapFactory.decodeFile(path, options)
    }

    /**
     * The power of two to divide by so the result is still at least [want]
     * wide.
     *
     * ── Powers of two, because that is what the decoder honours ─────────────
     * `inSampleSize` is rounded down to a power of two by the decoder anyway,
     * so computing anything else would produce a number that does not describe
     * what happens. Doubling until one more step would go under the target
     * gives the smallest image that is still big enough — never one that has
     * to be scaled back UP, which would be worse than not sampling at all.
     */
    fun sampleFor(have: Int, want: Int): Int {
        if (want <= 0 || have <= want) return 1

        var sample = 1
        while (have / (sample * 2) >= want) sample *= 2

        return sample
    }
}
