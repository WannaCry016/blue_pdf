package com.bluepdf.blue_pdf

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfDocument
import android.os.Bundle
import androidx.annotation.NonNull
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.multipdf.PDFMergerUtility
import com.tom_roush.pdfbox.pdmodel.encryption.AccessPermission
import com.tom_roush.pdfbox.pdmodel.encryption.StandardProtectionPolicy
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException
import com.tom_roush.pdfbox.pdmodel.PDDocument
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "bluepdf.native/Pdf_utility"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PDFBoxResourceLoader.init(applicationContext) // ✅ Initialize PDFBox-Android

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generatePdfFromImages" -> {
                    val paths = call.argument<List<String>>("paths")
                    if (paths != null) {
                        CoroutineScope(Dispatchers.Default).launch {
                            try {
                                val pdfPath = generateCompressedPdfParallel(paths)
                                withContext(Dispatchers.Main) {
                                    result.success(pdfPath)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("PDF_ERROR", e.message, null)
                                }
                            }
                        }
                    } else {
                        result.error("NO_PATHS", "No image paths provided", null)
                    }
                }

                "mergePdfs" -> {
                    val paths = call.argument<List<String>>("paths")
                    if (paths != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val mergedPdfPath = mergePdfsNative(paths)
                                withContext(Dispatchers.Main) {
                                    result.success(mergedPdfPath)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("MERGE_ERROR", "Failed to merge PDFs: ${e.message}", null)
                                }
                            }
                        }
                    } else {
                        result.error("NO_PATHS", "No PDF paths provided for merging", null)
                    }
                }

                "encryptPdf" -> {
                    val path = call.argument<String>("path")
                    val password = call.argument<String>("password")
                    if (path != null && password != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val encryptedPath = encryptPdfNative(path, password)
                                withContext(Dispatchers.Main) {
                                    result.success(encryptedPath)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("ENCRYPT_ERROR", "Failed to encrypt PDF: ${e.message}", null)
                                }
                            }
                        }
                    } else {
                        result.error("MISSING_ARGS", "Missing path or password", null)
                    }
                }

                "unlockPdf" -> {
                    val path = call.argument<String>("path")
                    val password = call.argument<String>("password")

                    if (path != null && password != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val unlockedPath = unlockPdfNative(path, password)
                                withContext(Dispatchers.Main) {
                                    result.success(unlockedPath)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("UNLOCK_ERROR", "Failed to unlock PDF: ${e.message}", null)
                                }
                            }
                        }
                    } else {
                        result.error("MISSING_ARGS", "Missing path or password", null)
                    }
                }

                "splitPdf" -> {
                    val path = call.argument<String>("path")
                    val startPage = call.argument<Int>("startPage")
                    val endPage = call.argument<Int>("endPage")
                    if (path != null && startPage != null && endPage != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val splitPath = splitPdfNative(path, startPage, endPage)
                                withContext(Dispatchers.Main) {
                                    result.success(splitPath)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("SPLIT_ERROR", "Failed to split PDF: ${e.message}", null)
                                }
                            }
                        }
                    } else {
                        result.error("MISSING_ARGS", "Missing path or page range", null)
                    }
                }
                "reorderPdf" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val imagePaths = reorderPdfNative(path)
                                withContext(Dispatchers.Main) {
                                    result.success(imagePaths)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("REORDER_ERROR", "Failed to convert PDF to images: ${e.message}", null)
                                }
                            }
                        }
                    } else {
                        result.error("MISSING_ARGS", "Missing path", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // --- IMAGE TO COMPRESSED PDF ---
    private fun calculateInSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
        val height = options.outHeight
        val width = options.outWidth
        var inSampleSize = 1
        if (height > reqHeight || width > reqWidth) {
            val halfHeight = height / 2
            val halfWidth = width / 2
            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    private suspend fun generateCompressedPdfParallel(paths: List<String>): String = withContext(Dispatchers.IO) {
        val document = PdfDocument()
        val targetWidth = 595

        val scaledBitmaps = paths.mapIndexed { index, path ->
            async(Dispatchers.Default) {
                val file = File(path)
                if (!file.exists()) return@async null

                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, options)

                val aspectRatio = options.outHeight.toFloat() / options.outWidth
                val targetHeight = (targetWidth * aspectRatio).toInt()

                val sampleOptions = BitmapFactory.Options().apply {
                    inSampleSize = calculateInSampleSize(options, targetWidth, targetHeight)
                    inPreferredConfig = Bitmap.Config.RGB_565
                }

                val bitmap = BitmapFactory.decodeFile(path, sampleOptions) ?: return@async null
                val scaled = Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, false)
                if (bitmap != scaled) bitmap.recycle()

                Triple(index, scaled, targetHeight)
            }
        }.awaitAll().filterNotNull().sortedBy { it.first }

        for ((index, scaledBitmap, targetHeight) in scaledBitmaps) {
            val pageInfo = PdfDocument.PageInfo.Builder(targetWidth, targetHeight, index + 1).create()
            val page = document.startPage(pageInfo)
            page.canvas.drawBitmap(scaledBitmap, 0f, 0f, null)
            document.finishPage(page)
            scaledBitmap.recycle()
        }

        val outputFile = File(context.cacheDir, "temp_pdf_${System.currentTimeMillis()}.pdf")
        FileOutputStream(outputFile).use { outputStream ->
            document.writeTo(outputStream)
        }
        document.close()

        return@withContext outputFile.absolutePath
    }

    // --- PDF MERGE FUNCTION ---
    private suspend fun mergePdfsNative(paths: List<String>): String = withContext(Dispatchers.IO) {
        val outputFile = File(context.cacheDir, "merged_pdf_${System.currentTimeMillis()}.pdf")
        val merger = PDFMergerUtility()
        merger.destinationFileName = outputFile.absolutePath

        for (path in paths) {
            val file = File(path)
            if (file.exists()) {
                merger.addSource(file)
            }
        }

        merger.mergeDocuments(MemoryUsageSetting.setupMainMemoryOnly())

        return@withContext outputFile.absolutePath
    }

    private suspend fun encryptPdfNative(path: String, password: String): String = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val outputFile = File(context.cacheDir, "encrypted_pdf_${System.currentTimeMillis()}.pdf")

        PDDocument.load(inputFile).use { document ->
            val keyLength = 128 // or 256 if you want stronger encryption
            val accessPermission = AccessPermission()
            val protectionPolicy = StandardProtectionPolicy(password, password, accessPermission)
            protectionPolicy.encryptionKeyLength = keyLength
            protectionPolicy.permissions = accessPermission

            document.protect(protectionPolicy)
            document.save(outputFile)
        }

        return@withContext outputFile.absolutePath
    }

    private suspend fun unlockPdfNative(path: String, password: String): String = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val outputFile = File(context.cacheDir, "unlocked_pdf_${System.currentTimeMillis()}.pdf")

        try {
            PDDocument.load(inputFile, password).use { document ->
                if (!document.isEncrypted) {
                    throw Exception("PDF is not encrypted.")
                }

                document.setAllSecurityToBeRemoved(true)
                document.save(outputFile)
            }
        } catch (e: InvalidPasswordException) {
            throw Exception("Incorrect password.")
        }

        return@withContext outputFile.absolutePath
    }

    private suspend fun splitPdfNative(path: String, startPage: Int, endPage: Int): String = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val outputFile = File(context.cacheDir, "split_pdf_${System.currentTimeMillis()}.pdf")

        PDDocument.load(inputFile).use { document ->
            val totalPages = document.numberOfPages
            if (startPage < 1 || endPage > totalPages || startPage > endPage) {
                throw Exception("Invalid page range: $startPage-$endPage for PDF with $totalPages pages.")
            }
            val splitDoc = PDDocument()
            for (i in (startPage - 1)..(endPage - 1)) {
                splitDoc.addPage(document.getPage(i))
            }
            splitDoc.save(outputFile)
            splitDoc.close()
        }
        return@withContext outputFile.absolutePath
    }

    private suspend fun reorderPdfNative(path: String): List<String> = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val imagePaths = mutableListOf<String>()
        PDDocument.load(inputFile).use { document ->
            val renderer = com.tom_roush.pdfbox.rendering.PDFRenderer(document)
            val pageCount = document.numberOfPages
            val jobs = (0 until pageCount).map { i ->
                async(Dispatchers.Default) {
                    val bitmap = renderer.renderImageWithDPI(i, 120f, com.tom_roush.pdfbox.rendering.ImageType.RGB) // 120 DPI for speed, RGB image type
                    val imageFile = File(context.cacheDir, "${i + 1}.png")
                    FileOutputStream(imageFile).use { out ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
                    }
                    bitmap.recycle()
                    Pair(i, imageFile.absolutePath)
                }
            }
            // Await all jobs and sort by page index to preserve order
            imagePaths.addAll(jobs.awaitAll().sortedBy { it.first }.map { it.second })
        }
        return@withContext imagePaths
    }


}
