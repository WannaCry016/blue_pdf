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

    // Compression levels: 1=Low, 2=Medium, 3=High
    data class CompressionSettings(
        val dpi: Float,
        val jpegQuality: Int,
        val maxWidth: Int,
        val maxHeight: Int,
        val bitmapConfig: Bitmap.Config
    )

    private fun getCompressionSettings(compression: Int): CompressionSettings {
        return when (compression) {
            1 -> CompressionSettings(72f, 60, 800, 1200, Bitmap.Config.RGB_565)      // Low
            2 -> CompressionSettings(150f, 80, 1200, 1800, Bitmap.Config.ARGB_8888)  // Medium
            3 -> CompressionSettings(300f, 95, 2480, 3508, Bitmap.Config.ARGB_8888)  // High (A4 at 300dpi)
            else -> CompressionSettings(150f, 80, 1200, 1800, Bitmap.Config.ARGB_8888) // Default Medium
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PDFBoxResourceLoader.init(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generatePdfFromImages" -> {
                    val paths = call.argument<List<String>>("paths")
                    val compression = call.argument<Int>("compression") ?: 2 // Default medium
                    if (paths != null) {
                        CoroutineScope(Dispatchers.Default).launch {
                            try {
                                val pdfPath = generateOptimizedPdf(paths, compression)
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
                    val compression = call.argument<Int>("compression") ?: 2
                    if (paths.isNullOrEmpty()) {
                        result.error("NO_PATHS", "No PDF paths provided for merging", null)
                        return@setMethodCallHandler
                    }
                    
                    val validPaths = paths.filter { File(it).exists() }
                    if (validPaths.isEmpty()) {
                        result.error("NO_VALID_PATHS", "No valid PDF files found", null)
                        return@setMethodCallHandler
                    }
                    
                    if (validPaths.size == 1) {
                        result.success(validPaths[0])
                        return@setMethodCallHandler
                    }
                    
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val mergedPdfPath = mergePdfsNative(validPaths, compression)
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
                    val compression = call.argument<Int>("compression") ?: 2
                    if (path != null && password != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val encryptedPath = encryptPdfNative(path, password, compression)
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
                    val compression = call.argument<Int>("compression") ?: 2
                    if (path != null && startPage != null && endPage != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val splitPath = splitPdfNative(path, startPage, endPage, compression)
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
                    val compression = call.argument<Int>("compression") ?: 2
                    if (path != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val imagePaths = reorderPdfNative(path, compression)
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

    // --- OPTIMIZED IMAGE TO PDF WITH QUALITY CONTROL ---
    private suspend fun generateOptimizedPdf(paths: List<String>, compression: Int): String = withContext(Dispatchers.IO) {
        val settings = getCompressionSettings(compression)
        val document = PdfDocument()

        try {
            val processedImages = paths.mapIndexed { index, path ->
                async(Dispatchers.Default) {
                    val file = File(path)
                    if (!file.exists()) return@async null

                    // Get original dimensions
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(path, options)
                    
                    if (options.outWidth <= 0 || options.outHeight <= 0) return@async null

                    // Calculate optimal size maintaining aspect ratio
                    val aspectRatio = options.outHeight.toFloat() / options.outWidth
                    val (targetWidth, targetHeight) = if (options.outWidth > options.outHeight) {
                        // Landscape
                        val width = minOf(settings.maxWidth, options.outWidth)
                        Pair(width, (width * aspectRatio).toInt())
                    } else {
                        // Portrait
                        val height = minOf(settings.maxHeight, options.outHeight)
                        Pair((height / aspectRatio).toInt(), height)
                    }

                    // Smart sampling for better quality
                    val sampleSize = calculateOptimalSampleSize(options, targetWidth, targetHeight)
                    
                    val loadOptions = BitmapFactory.Options().apply {
                        inSampleSize = sampleSize
                        inPreferredConfig = settings.bitmapConfig
                        inDither = false
                        inScaled = false
                    }

                    val bitmap = BitmapFactory.decodeFile(path, loadOptions) ?: return@async null
                    
                    // High-quality scaling if needed
                    val finalBitmap = if (bitmap.width != targetWidth || bitmap.height != targetHeight) {
                        Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true).also {
                            if (it != bitmap) bitmap.recycle()
                        }
                    } else bitmap

                    Triple(index, finalBitmap, Pair(targetWidth, targetHeight))
                }
            }.awaitAll().filterNotNull().sortedBy { it.first }

            // Create PDF pages
            processedImages.forEach { (index, bitmap, dimensions) ->
                val pageInfo = PdfDocument.PageInfo.Builder(dimensions.first, dimensions.second, index + 1).create()
                val page = document.startPage(pageInfo)
                page.canvas.drawBitmap(bitmap, 0f, 0f, null)
                document.finishPage(page)
                bitmap.recycle()
            }

            val outputFile = File(context.cacheDir, "optimized_pdf_${System.currentTimeMillis()}.pdf")
            FileOutputStream(outputFile).use { document.writeTo(it) }
            
            return@withContext outputFile.absolutePath
        } finally {
            document.close()
        }
    }

    private fun calculateOptimalSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
        val height = options.outHeight
        val width = options.outWidth
        var inSampleSize = 1

        if (height > reqHeight || width > reqWidth) {
            val halfHeight = height / 2
            val halfWidth = width / 2
            
            // Calculate the largest inSampleSize value that is a power of 2 and keeps both
            // height and width larger than the requested height and width.
            while ((halfHeight / inSampleSize) >= reqHeight && (halfWidth / inSampleSize) >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    // --- OPTIMIZED PDF TO IMAGES WITH QUALITY CONTROL ---
    private suspend fun reorderPdfNative(path: String, compression: Int): List<String> = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val settings = getCompressionSettings(compression)
        
        val memorySettings = if (inputFile.length() > 50 * 1024 * 1024) {
            MemoryUsageSetting.setupTempFileOnly()
        } else {
            MemoryUsageSetting.setupMainMemoryOnly()
        }
        
        PDDocument.load(inputFile, memorySettings).use { document ->
            val renderer = com.tom_roush.pdfbox.rendering.PDFRenderer(document)
            val pageCount = document.numberOfPages
            
            // Batch processing for memory efficiency
            val batchSize = when {
                pageCount > 100 -> 5
                pageCount > 50 -> 8
                else -> 12
            }
            
            val allResults = mutableListOf<Pair<Int, String>>()
            
            // Process in batches
            (0 until pageCount).chunked(batchSize).forEach { batch ->
                val batchResults = batch.map { pageIndex ->
                    async(Dispatchers.Default) {
                        try {
                            // Render at high quality
                            val bitmap = renderer.renderImageWithDPI(
                                pageIndex, 
                                settings.dpi,
                                com.tom_roush.pdfbox.rendering.ImageType.RGB
                            )
                            
                            // Optimize bitmap size if needed
                            val optimizedBitmap = if (bitmap.width > settings.maxWidth || bitmap.height > settings.maxHeight) {
                                val aspectRatio = bitmap.height.toFloat() / bitmap.width
                                val (newWidth, newHeight) = if (bitmap.width > bitmap.height) {
                                    val width = minOf(settings.maxWidth, bitmap.width)
                                    Pair(width, (width * aspectRatio).toInt())
                                } else {
                                    val height = minOf(settings.maxHeight, bitmap.height)
                                    Pair((height / aspectRatio).toInt(), height)
                                }
                                
                                Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true).also {
                                    bitmap.recycle()
                                }
                            } else bitmap
                            
                            val imageFile = File(context.cacheDir, "page_${pageIndex + 1}_${System.nanoTime()}.jpg")
                            
                            FileOutputStream(imageFile).use { out ->
                                optimizedBitmap.compress(Bitmap.CompressFormat.JPEG, settings.jpegQuality, out)
                            }
                            
                            optimizedBitmap.recycle()
                            Pair(pageIndex, imageFile.absolutePath)
                            
                        } catch (e: Exception) {
                            Pair(pageIndex, "")
                        }
                    }
                }.awaitAll().filter { it.second.isNotEmpty() }
                
                allResults.addAll(batchResults)
            }
            
            return@withContext allResults.sortedBy { it.first }.map { it.second }
        }
    }

    // --- UPDATED MERGE WITH COMPRESSION ---
    private suspend fun mergePdfsNative(paths: List<String>, compression: Int): String = withContext(Dispatchers.IO) {
        val outputFile = File(context.cacheDir, "merged_${System.currentTimeMillis()}.pdf")
        val merger = PDFMergerUtility()
        merger.destinationFileName = outputFile.absolutePath
        
        // Optimize based on compression level
        when (compression) {
            1 -> merger.setDocumentMergeMode(PDFMergerUtility.DocumentMergeMode.OPTIMIZE_RESOURCES_MODE)
            2, 3 -> merger.setDocumentMergeMode(PDFMergerUtility.DocumentMergeMode.PDFBOX_LEGACY_MODE)
        }
        
        paths.forEach { merger.addSource(File(it)) }
        
        val memorySettings = if (paths.size > 5 || compression == 1) {
            MemoryUsageSetting.setupTempFileOnly()
        } else {
            MemoryUsageSetting.setupMainMemoryOnly()
        }
        
        merger.mergeDocuments(memorySettings)
        return@withContext outputFile.absolutePath
    }

    // --- UPDATED ENCRYPT WITH COMPRESSION ---
    private suspend fun encryptPdfNative(path: String, password: String, compression: Int): String = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val outputFile = File(context.cacheDir, "encrypted_pdf_${System.currentTimeMillis()}.pdf")

        val memorySettings = if (compression == 1) {
            MemoryUsageSetting.setupTempFileOnly()
        } else {
            MemoryUsageSetting.setupMainMemoryOnly()
        }

        PDDocument.load(inputFile, memorySettings).use { document ->
            val keyLength = if (compression == 3) 256 else 128
            val accessPermission = AccessPermission()
            val protectionPolicy = StandardProtectionPolicy(password, password, accessPermission)
            protectionPolicy.encryptionKeyLength = keyLength
            protectionPolicy.permissions = accessPermission

            document.protect(protectionPolicy)
            document.save(outputFile)
        }

        return@withContext outputFile.absolutePath
    }

    // --- UPDATED SPLIT WITH COMPRESSION ---
    private suspend fun splitPdfNative(path: String, startPage: Int, endPage: Int, compression: Int): String = withContext(Dispatchers.IO) {
        val inputFile = File(path)
        val outputFile = File(context.cacheDir, "split_${System.currentTimeMillis()}.pdf")
        
        val memorySettings = if (inputFile.length() > 50 * 1024 * 1024 || compression == 1) {
            MemoryUsageSetting.setupTempFileOnly()
        } else {
            MemoryUsageSetting.setupMainMemoryOnly()
        }
        
        PDDocument.load(inputFile, memorySettings).use { document ->
            val totalPages = document.numberOfPages
            
            if (startPage < 1 || endPage > totalPages || startPage > endPage) {
                throw Exception("Invalid page range: $startPage-$endPage for PDF with $totalPages pages.")
            }
            
            val splitDoc = PDDocument()
            try {
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
}