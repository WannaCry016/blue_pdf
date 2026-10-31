package com.bluepdf.blue_pdf

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

/** A picked document: its content URI, a display name with an extension, and its size if known. */
data class PickedFile(val uri: Uri, val name: String, val size: Long?)

/** Copies picked documents into the cache, a few at a time, so MuPDF can open them by path. */
class FileImporter(private val resolver: ContentResolver, private val cacheDir: File) {

    private val copyDispatcher = Dispatchers.IO.limitedParallelism(PARALLEL_COPIES)

    fun describe(uri: Uri): PickedFile {
        var name: String? = null
        var size: Long? = null
        try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
                if (it.moveToFirst()) {
                    val nameColumn = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeColumn = it.getColumnIndex(OpenableColumns.SIZE)
                    if (nameColumn >= 0 && !it.isNull(nameColumn)) name = it.getString(nameColumn)
                    if (sizeColumn >= 0 && !it.isNull(sizeColumn)) size = it.getLong(sizeColumn).takeIf { s -> s >= 0 }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not describe $uri", e)
        }
        return PickedFile(uri, withExtension(name ?: uri.lastPathSegment ?: "file", uri), size)
    }

    /**
     * Returns a cache path for each file, in order, or null for any that couldn't be read.
     * Progress counts finished files and, when every size is known, fills by bytes copied.
     */
    suspend fun import(files: List<PickedFile>, progress: PdfProgressListener?): List<String?> {
        val dir = File(cacheDir, "picked/${System.nanoTime()}").apply { mkdirs() }
        val totalBytes = if (files.all { it.size != null }) files.sumOf { it.size!! } else 0L
        val cancelled = AtomicBoolean(false)
        val lock = Any()
        var copiedBytes = 0L
        var finished = 0

        fun report(bytes: Int = 0, fileDone: Boolean = false): Boolean = synchronized(lock) {
            copiedBytes += bytes
            if (fileDone) finished++
            val fraction = if (totalBytes > 0) copiedBytes.toFloat() / totalBytes else finished.toFloat() / files.size
            if (progress?.onProgress(STAGE_PROCESSING, finished, files.size, fraction.coerceAtMost(1f)) == false) {
                cancelled.set(true)
            }
            !cancelled.get()
        }

        report()
        val paths = coroutineScope {
            files.mapIndexed { index, file ->
                async(copyDispatcher) {
                    if (cancelled.get()) return@async null
                    val target = File(dir, "${index}_${safeFileName(file.name)}")
                    val copied = copy(file.uri, target) { bytes -> report(bytes) }
                    report(fileDone = true)
                    if (copied) target.path else null
                }
            }.awaitAll()
        }
        if (cancelled.get()) {
            dir.deleteRecursively()
            throw PdfException("CANCELLED", "Import cancelled")
        }
        return paths
    }

    /** Streams [uri] into [target]; [onBytes] returning false stops the copy. Cache files need no fsync. */
    private fun copy(uri: Uri, target: File, onBytes: (Int) -> Boolean): Boolean {
        try {
            val input = resolver.openInputStream(uri) ?: return false
            input.use { source ->
                FileOutputStream(target).use { sink ->
                    val buffer = ByteArray(BUFFER_SIZE)
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) return true
                        sink.write(buffer, 0, read)
                        if (!onBytes(read)) break
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not copy $uri", e)
        }
        target.delete()
        return false
    }

    private fun withExtension(name: String, uri: Uri): String {
        if (name.substringAfterLast('.', "").isNotEmpty()) return name
        val extension = resolver.getType(uri)?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
        return if (extension == null) name else "$name.$extension"
    }

    private fun safeFileName(name: String): String =
        name.replace(Regex("""[\\/:*?"<>|\x00-\x1f]"""), "_").takeLast(MAX_NAME_LENGTH)

    private companion object {
        const val TAG = "FileImporter"
        const val STAGE_PROCESSING = 0
        const val PARALLEL_COPIES = 4
        const val BUFFER_SIZE = 64 * 1024
        const val MAX_NAME_LENGTH = 120
    }
}
