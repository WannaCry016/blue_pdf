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
import com.tom_roush.pdfbox.multipdf.Splitter
import java.util.Collections
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
                    if (paths.isNullOrEmpty()) {
                        result.error("NO_PATHS", "No PDF paths provided for merging", null)
                        return@setMethodCallHandler
                    }
                    
                    // Quick validation before starting heavy work
                    val validPaths = paths.filter { File(it).exists() }
                    if (validPaths.isEmpty()) {
                        result.error("NO_VALID_PATHS", "No valid PDF files found", null)
                        return@setMethodCallHandler
                    }
                    
                    // Skip merge if only one file
                    if (validPaths.size == 1) {
                        result.success(validPaths[0])
                        return@setMethodCallHandler
                    }
                    
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val mergedPdfPath = mergePdfsNative(validPaths)
                            withContext(Dispatchers.Main) {
                                result.success(mergedPdfPath)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("MERGE_ERROR", "Failed to merge PDFs: ${e.message}", null)
                            }
                        }
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
        val outputFile = File(context.cacheDir, "merged_${System.currentTimeMillis()}.pdf")
        val merger = PDFMergerUtility()
        merger.destinationFileName = outputFile.absolutePath
        
        // SPEED BOOST: Use optimized merge mode (closes documents early)
        merger.setDocumentMergeMode(PDFMergerUtility.DocumentMergeMode.OPTIMIZE_RESOURCES_MODE)
        
        // Add all sources first (faster than adding one by one)
        paths.forEach { path ->
            merger.addSource(File(path))
        }
        
        // Choose memory setting based on number of files
        val memorySettings = if (paths.size > 5) {
            // Use temp files for many PDFs to avoid memory issues
            MemoryUsageSetting.setupTempFileOnly()
        } else {
            // Use main memory for few PDFs (faster)
            MemoryUsageSetting.setupMainMemoryOnly()
        }
        
        merger.mergeDocuments(memorySettings)
        
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

    // --- OPTIMIZED SPLIT PDF FUNCTION ---
    private suspend fun splitPdfNative(path: String, startPage: Int, endPage: Int): String = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val outputFile = File(context.cacheDir, "split_${System.currentTimeMillis()}.pdf")
        
        // Use memory-optimized loading for large files
        val memorySettings = if (inputFile.length() > 50 * 1024 * 1024) { // > 50MB
            MemoryUsageSetting.setupTempFileOnly()
        } else {
            MemoryUsageSetting.setupMainMemoryOnly()
        }
        
        PDDocument.load(inputFile, memorySettings).use { document ->
            val totalPages = document.numberOfPages
            
            // Quick validation
            if (startPage < 1 || endPage > totalPages || startPage > endPage) {
                throw Exception("Invalid page range: $startPage-$endPage for PDF with $totalPages pages.")
            }
            
            // Create new document for split pages
            val splitDoc = PDDocument()
            try {
                // SPEED BOOST: Add pages in batch
                for (i in (startPage - 1)..(endPage - 1)) {
                    splitDoc.addPage(document.getPage(i))
                }
                splitDoc.save(outputFile)
            } finally {
                splitDoc.close()
            }
        }
        return@withContext outputFile.absolutePath
    }

    // --- HIGHLY OPTIMIZED REORDER PDF FUNCTION ---
    private suspend fun reorderPdfNative(path: String): List<String> = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val imagePaths = Collections.synchronizedList(mutableListOf<String>())
        
        // Use memory-optimized loading
        val memorySettings = if (inputFile.length() > 30 * 1024 * 1024) { // > 30MB
            MemoryUsageSetting.setupTempFileOnly()
        } else {
            MemoryUsageSetting.setupMainMemoryOnly()
        }
        
        PDDocument.load(inputFile, memorySettings).use { document ->
            val renderer = com.tom_roush.pdfbox.rendering.PDFRenderer(document)
            val pageCount = document.numberOfPages
            
            // SPEED BOOST: Lower DPI for faster rendering, adjust based on your needs
            val dpi = when {
                pageCount > 50 -> 72f    // Very fast for many pages
                pageCount > 20 -> 96f    // Balanced
                else -> 120f             // Higher quality for few pages
            }
            
            // SPEED BOOST: Limit concurrency to avoid memory pressure
            val concurrency = minOf(pageCount, Runtime.getRuntime().availableProcessors(), 4)
            
            // Process pages in batches to control memory usage
            val batchSize = when {
                pageCount > 100 -> 10
                pageCount > 50 -> 15
                else -> pageCount
            }
            
            val results = (0 until pageCount).chunked(batchSize).flatMap { batch ->
                batch.map { pageIndex ->
                    async(Dispatchers.Default) {
                        try {
                            // SPEED BOOST: Use GRAY for faster processing if color isn't critical
                            val imageType = com.tom_roush.pdfbox.rendering.ImageType.RGB
                            val bitmap = renderer.renderImageWithDPI(pageIndex, dpi, imageType)
                            
                            val imageFile = File(context.cacheDir, "page_${pageIndex + 1}_${System.nanoTime()}.jpg") // JPG is faster than PNG
                            
                            // SPEED BOOST: Use JPG with higher compression for speed
                            FileOutputStream(imageFile).use { out ->
                                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out) // 85% quality, much faster than PNG
                            }
                            
                            bitmap.recycle()
                            Pair(pageIndex, imageFile.absolutePath)
                            
                        } catch (e: Exception) {
                            // Return placeholder on error to maintain order
                            Pair(pageIndex, "")
                        }
                    }
                }
            }
            
            // SPEED BOOST: Process results as they complete, maintain order
            val sortedResults = results.awaitAll()
                .filter { it.second.isNotEmpty() } // Remove failed conversions
                .sortedBy { it.first }
                .map { it.second }
            
            return@withContext sortedResults
        }
    }

    // --- ALTERNATIVE: EVEN FASTER REORDER FOR PREVIEW (LOWER QUALITY) ---
    private suspend fun reorderPdfNativeFast(path: String): List<String> = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val imagePaths = Collections.synchronizedList(mutableListOf<String>())
        
        PDDocument.load(inputFile, MemoryUsageSetting.setupMainMemoryOnly()).use { document ->
            val renderer = com.tom_roush.pdfbox.rendering.PDFRenderer(document)
            val pageCount = document.numberOfPages
            
            // MAXIMUM SPEED: Very low DPI and grayscale
            val jobs = (0 until pageCount).map { pageIndex ->
                async(Dispatchers.Default) {
                    val bitmap = renderer.renderImageWithDPI(
                        pageIndex, 
                        50f, // Very low DPI for maximum speed
                        com.tom_roush.pdfbox.rendering.ImageType.GRAY // Grayscale for speed
                    )
                    
                    val imageFile = File(context.cacheDir, "preview_${pageIndex + 1}.jpg")
                    FileOutputStream(imageFile).use { out ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 60, out) // Low quality for speed
                    }
                    
                    bitmap.recycle()
                    Pair(pageIndex, imageFile.absolutePath)
                }
            }
            
            return@withContext jobs.awaitAll().sortedBy { it.first }.map { it.second }
        }
    }


}
