package com.bluepdf.blue_pdf

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.media.ExifInterface
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Prepares photos for PDF pages the way scanner and converter apps do: at most [MAX_SIDE]
 * pixels on the long side (about 250 dpi on A4, sharp in print) and JPEG quality [QUALITY].
 * Images that are already that compact are used untouched, so they lose nothing.
 */
class ImageOptimizer(private val cacheDir: File) {

    private val dispatcher = Dispatchers.Default.limitedParallelism(PARALLEL)

    /**
     * Returns, in order, the path to use for each image, and a directory of temporary files
     * to delete once the PDF is written. [onDone] gets the number finished; false cancels.
     */
    suspend fun optimize(paths: List<String>, onDone: (Int) -> Boolean): Pair<List<String>, File> {
        val dir = File(cacheDir, "optimized/${System.nanoTime()}").apply { mkdirs() }
        val cancelled = AtomicBoolean(false)
        val finished = AtomicInteger()
        val result = coroutineScope {
            paths.mapIndexed { index, path ->
                async(dispatcher) {
                    val out = if (cancelled.get()) path else optimizeOne(path, File(dir, "$index.jpg"))
                    if (!onDone(finished.incrementAndGet())) cancelled.set(true)
                    out
                }
            }.awaitAll()
        }
        if (cancelled.get()) {
            dir.deleteRecursively()
            throw PdfException("CANCELLED", "Cancelled")
        }
        return result to dir
    }

    private fun optimizeOne(path: String, target: File): String {
        val source = File(path)
        try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            val width = bounds.outWidth
            val height = bounds.outHeight
            // Unreadable or a format Android can't decode (TIFF): MuPDF reads or reports it.
            if (width <= 0 || height <= 0 || bounds.outMimeType !in REENCODABLE) return path

            val longSide = max(width, height)
            val bytesPerPixel = source.length().toDouble() / (width.toLong() * height)
            if (longSide <= MAX_SIDE && bytesPerPixel <= COMPACT_BYTES_PER_PIXEL) return path

            var sample = 1
            while (longSide / (sample * 2) >= MAX_SIDE) sample *= 2
            val decoded = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: return path

            var page: Bitmap = decoded
            try {
                page = upright(decoded, MAX_SIDE.toFloat() / max(decoded.width, decoded.height), orientationOf(path, bounds))
                FileOutputStream(target).use { page.compress(Bitmap.CompressFormat.JPEG, QUALITY, it) }
            } finally {
                if (page !== decoded) page.recycle()
                decoded.recycle()
            }

            // Re-encoding a compact image can gain too little to be worth a generation of loss.
            if (longSide <= MAX_SIDE && target.length() > source.length() * MIN_SAVING) {
                target.delete()
                return path
            }
            return target.path
        } catch (e: Exception) {
            Log.w(TAG, "Using the original of $path", e)
        } catch (e: OutOfMemoryError) {
            Log.w(TAG, "Using the original of $path", e)
        }
        target.delete()
        return path
    }

    /**
     * Scales by [scale] (if below 1), applies the EXIF [orientation] and flattens transparency
     * onto white. Returns [bitmap] itself when nothing changes; never recycles it.
     */
    private fun upright(bitmap: Bitmap, scale: Float, orientation: Int): Bitmap {
        val matrix = Matrix()
        if (scale < 1f) matrix.setScale(scale, scale)
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.postRotate(90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.postRotate(-90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
        }
        val transformed = if (matrix.isIdentity) bitmap else Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        if (!transformed.hasAlpha()) return transformed

        val flat = Bitmap.createBitmap(transformed.width, transformed.height, Bitmap.Config.ARGB_8888)
        Canvas(flat).apply {
            drawColor(Color.WHITE)
            drawBitmap(transformed, 0f, 0f, null)
        }
        if (transformed !== bitmap) transformed.recycle()
        return flat
    }

    // Only JPEGs carry orientation that MuPDF would otherwise apply itself.
    private fun orientationOf(path: String, bounds: BitmapFactory.Options): Int =
        if (bounds.outMimeType != "image/jpeg") {
            ExifInterface.ORIENTATION_NORMAL
        } else {
            try {
                ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            } catch (e: Exception) {
                ExifInterface.ORIENTATION_NORMAL
            }
        }

    companion object {
        private const val TAG = "ImageOptimizer"
        const val MAX_SIDE = 3000
        const val QUALITY = 85

        // A quality-85 photo is about 0.15-0.35 bytes per pixel; well above that is
        // near-lossless JPEG or PNG, which shrinks a lot when re-encoded.
        private const val COMPACT_BYTES_PER_PIXEL = 0.45
        private const val MIN_SAVING = 0.9
        private const val PARALLEL = 3
        private val REENCODABLE = setOf("image/jpeg", "image/png", "image/webp", "image/bmp", "image/x-ms-bmp")
    }
}
