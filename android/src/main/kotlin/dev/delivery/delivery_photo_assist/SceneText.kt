package dev.delivery.delivery_photo_assist

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.RectF
import android.os.SystemClock
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayInputStream
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import java.util.concurrent.Executors
import java.text.Normalizer
import kotlin.math.min

class SceneTextScanner {
    private val recognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    private val executor = Executors.newSingleThreadExecutor()
    private var busy = false
    private var closed = false
    private var lastStart = -10000L
    private var lastResult = -10000L
    private var latest: Map<String, Any> = emptyMap()
    private var enabled = true
    private var intervalMs = 1000L

    @Synchronized fun configure(enabled: Boolean, intervalMs: Long) {
        this.enabled = enabled
        this.intervalMs = maxOf(1000L, intervalMs)
        if (!enabled) { latest = emptyMap(); lastResult = -10000L }
    }

    @Synchronized fun observe(bitmap: Bitmap, rotation: Int, mirror: Boolean, parcels: List<RectF>) {
        val now = SystemClock.elapsedRealtime()
        if (closed || !enabled || busy || now-lastStart < intervalMs) return
        busy = true; lastStart = now
        val scale = min(1.0, 1024.0/maxOf(bitmap.width, bitmap.height))
        val small = Bitmap.createScaledBitmap(bitmap, (bitmap.width*scale).toInt(), (bitmap.height*scale).toInt(), true)
        // Own the copy before the camera releases its frame; all OCR work runs separately.
        val owned = small.copy(Bitmap.Config.ARGB_8888, false)
        if (small !== bitmap) small.recycle()
        executor.execute {
            val started = System.nanoTime()
            val matrix = Matrix().apply { postRotate(rotation.toFloat()); if (mirror) postScale(-1f, 1f) }
            val upright = if (rotation == 0 && !mirror) owned else Bitmap.createBitmap(owned, 0, 0, owned.width, owned.height, matrix, true)
            try {
                val text = Tasks.await(recognizer.process(InputImage.fromBitmap(upright, 0)))
                val packet = packet(text, upright.width, upright.height, parcels, (System.nanoTime()-started)/1e6)
                synchronized(this) { if (!closed) { latest = packet; lastResult = now } }
            } catch (_: Exception) {
                synchronized(this) { latest = mapOf("lines" to emptyList<Any>(), "status" to "unavailable"); lastResult = now }
            } finally {
                if (upright !== owned) upright.recycle()
                owned.recycle()
                synchronized(this) { busy = false }
            }
        }
    }

    @Synchronized fun snapshot(): Map<String, Any> {
        if (!enabled) return mapOf("lines" to emptyList<Any>(), "status" to "disabled")
        val age = SystemClock.elapsedRealtime()-lastResult
        return if (age <= 1500 && !closed) latest + ("ageMs" to age) else mapOf("lines" to emptyList<Any>(), "status" to "pending")
    }

    @Synchronized fun close() {
        if (closed) return
        closed = true
        // Queue cleanup behind any active scan, so Tasks.await can finish safely.
        executor.execute { recognizer.close() }
        executor.shutdown()
    }

    companion object {
        private fun packet(text: Text, width: Int, height: Int, parcels: List<RectF>, ms: Double): Map<String, Any> {
            val lines = text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                val value = line.text.trim()
                val branding = Normalizer.normalize(value, Normalizer.Form.NFD).replace(Regex("\\p{M}"), "").uppercase().filter { it.isLetterOrDigit() }
                if (branding == "UMALL") return@mapNotNull null
                val r = line.boundingBox ?: return@mapNotNull null
                val box = RectF(r.left.toFloat()/width, r.top.toFloat()/height, r.right.toFloat()/width, r.bottom.toFloat()/height)
                if (value.length !in 1..32 || (value.length == 1 && !value[0].isDigit()) || box.height() < .012f) return@mapNotNull null
                if (parcels.any { p ->
                    val intersection = RectF(box)
                    intersection.intersect(p) && intersection.width()*intersection.height() > box.width()*box.height()*.5f
                }) return@mapNotNull null
                mapOf("text" to value, "box" to listOf(box.left, box.top, box.right, box.bottom))
            }.take(24)
            return mapOf("lines" to lines, "processingMs" to ms, "status" to "available", "scope" to "possible_text_clues; not verified location")
        }

        fun jpeg(bytes: ByteArray): Map<String, Any> {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            val options = BitmapFactory.Options().apply {
                inSampleSize = 1
                while (bounds.outWidth/inSampleSize > 1024 || bounds.outHeight/inSampleSize > 1024) inSampleSize *= 2
            }
            val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) ?: return emptyMap()
            val exif = ExifInterface(ByteArrayInputStream(bytes))
            val matrix = Matrix().apply { postRotate(exif.rotationDegrees.toFloat()); if (exif.isFlipped) postScale(-1f, 1f) }
            val image = if (exif.rotationDegrees == 0 && !exif.isFlipped) decoded else Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
            val recognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            return try {
                val started = System.nanoTime()
                val text = Tasks.await(recognizer.process(InputImage.fromBitmap(image, 0)))
                packet(text, image.width, image.height, emptyList(), (System.nanoTime()-started)/1e6)
            } finally { if (image !== decoded) image.recycle(); decoded.recycle(); recognizer.close() }
        }
    }
}
