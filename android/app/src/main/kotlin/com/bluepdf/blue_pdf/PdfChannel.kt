package com.bluepdf.blue_pdf

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicInteger

/** Serves `com.bluepdf.channel/pdf`. Every operation runs off the main thread. */
class PdfChannel(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    private val cacheDir: File = context.cacheDir
    private val contentResolver: ContentResolver = context.contentResolver
    private val channel = MethodChannel(messenger, NAME)
    private val jobs = PdfJobs(messenger)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    // Native rendering keeps one document open between calls, so renders are serialised.
    private val renderDispatcher = Dispatchers.IO.limitedParallelism(1)
    private val outputCounter = AtomicInteger()

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        jobs.dispose()
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "inspect" -> run(call, result) {
                val info = PdfNative.inspect(call.requireString("path"), call.argument("password"))
                mapOf("pageCount" to info[0], "encrypted" to (info[1] == 1))
            }

            "imagesToPdf" -> runJob(call, result) { progress ->
                val out = newOutputFile("images")
                val skipped = PdfNative.imagesToPdf(
                    call.requireStrings("paths").toTypedArray(),
                    call.ints("rotations"),
                    call.argument<Boolean>("fitToImage") ?: false,
                    out.path,
                    progress,
                )
                mapOf("path" to out.path, "skipped" to skipped.toList())
            }

            "merge" -> runJob(call, result) { progress ->
                val out = newOutputFile("merged")
                val passwords = call.argument<List<String?>>("passwords").orEmpty()
                PdfNative.merge(
                    call.requireStrings("paths").toTypedArray(),
                    passwords.toTypedArray(),
                    out.path,
                    progress,
                )
                out.path
            }

            "extractPages" -> runJob(call, result) { progress ->
                val out = newOutputFile("pages")
                PdfNative.extractPages(
                    call.requireString("path"),
                    call.argument("password"),
                    call.ints("pages"),
                    call.ints("rotations"),
                    out.path,
                    progress,
                )
                out.path
            }

            "encrypt" -> runJob(call, result) { progress ->
                val out = newOutputFile("protected")
                PdfNative.encrypt(call.requireString("path"), call.requireString("newPassword"), out.path, progress)
                out.path
            }

            "cancel" -> {
                jobs.cancel(call.requireInt("jobId"))
                result.success(null)
            }

            "renderPage" -> run(call, result, renderDispatcher) { renderPage(call) }

            "describeSaved" -> run(call, result) { describeSaved(Uri.parse(call.requireString("uri"))) }

            else -> result.notImplemented()
        }
    }

    /** Like [run], reporting progress for the call's optional `jobId`. */
    private fun runJob(call: MethodCall, result: MethodChannel.Result, block: (PdfProgressListener?) -> Any?) {
        val jobId = call.argument<Number>("jobId")?.toInt()
        val job = jobs.start(jobId)
        run(call, result) {
            try {
                block(job?.listener)
            } finally {
                jobs.finish(jobId)
            }
        }
    }

    private fun run(
        call: MethodCall,
        result: MethodChannel.Result,
        dispatcher: CoroutineDispatcher = Dispatchers.IO,
        block: () -> Any?,
    ) {
        scope.launch {
            try {
                result.success(withContext(dispatcher) { block() })
            } catch (e: PdfException) {
                result.error(e.code, e.message, null)
            } catch (e: IllegalArgumentException) {
                result.error("INVALID_ARGUMENT", e.message, null)
            } catch (e: OutOfMemoryError) {
                result.error("OUT_OF_MEMORY", e.message, null)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "${call.method} failed", e)
                result.error("UNKNOWN", e.message, null)
            }
        }
    }

    /** Renders are cached by source identity, page and width, so repeated thumbnails are free. */
    private fun renderPage(call: MethodCall): String {
        val path = call.requireString("path")
        val page = call.requireInt("page")
        val width = call.requireInt("width")
        val source = File(path)

        val dir = File(cacheDir, "thumbs").apply { mkdirs() }
        val key = sha1("$path|${source.lastModified()}|${source.length()}|$page|$width")
        val out = File(dir, "$key.jpg")
        if (out.length() > 0) return out.path

        val partial = File(dir, "$key.part")
        PdfNative.renderPage(path, call.argument("password"), page, width, partial.path)
        if (!partial.renameTo(out)) throw IllegalStateException("Could not store rendered page")
        return out.path
    }

    private fun describeSaved(uri: Uri): Map<String, Any?> {
        val columns = arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val name = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val size = cursor.getColumnIndex(OpenableColumns.SIZE)
                return mapOf(
                    "name" to if (name >= 0 && !cursor.isNull(name)) cursor.getString(name) else null,
                    "size" to if (size >= 0 && !cursor.isNull(size)) cursor.getLong(size) else null,
                )
            }
        }
        return emptyMap()
    }

    private fun newOutputFile(prefix: String): File {
        val dir = File(cacheDir, "outputs").apply { mkdirs() }
        return File(dir, "${prefix}_${System.currentTimeMillis()}_${outputCounter.incrementAndGet()}.pdf")
    }

    private fun MethodCall.requireString(key: String): String =
        argument<String>(key) ?: throw IllegalArgumentException("Missing '$key'")

    private fun MethodCall.requireStrings(key: String): List<String> =
        argument<List<String>>(key) ?: throw IllegalArgumentException("Missing '$key'")

    private fun MethodCall.requireInt(key: String): Int =
        argument<Number>(key)?.toInt() ?: throw IllegalArgumentException("Missing '$key'")

    private fun MethodCall.ints(key: String): IntArray = when (val value = argument<Any>(key)) {
        null -> IntArray(0)
        is IntArray -> value
        is List<*> -> IntArray(value.size) { (value[it] as Number).toInt() }
        else -> throw IllegalArgumentException("'$key' must be a list of integers")
    }

    private fun sha1(text: String): String =
        MessageDigest.getInstance("SHA-1").digest(text.toByteArray()).joinToString("") { "%02x".format(it) }

    private companion object {
        const val NAME = "com.bluepdf.channel/pdf"
        const val TAG = "PdfChannel"
    }
}
