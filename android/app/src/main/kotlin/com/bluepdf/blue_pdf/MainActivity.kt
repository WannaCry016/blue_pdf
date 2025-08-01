package com.bluepdf.blue_pdf

import android.os.Bundle
import android.util.Log
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONArray

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.bluepdf.channel/pdf"
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    companion object {
        init {
            System.loadLibrary("native-lib")
        }
    }

    // Native function declarations
    private external fun imageToPdfNative(imagePaths: Array<String>, cacheDir: String): String
    private external fun mergePdfNative(pdfPaths: Array<String>, cacheDir: String): String
    private external fun encryptPdfNative(pdfPath: String, password: String, cacheDir: String): String
    private external fun splitPdfNative(path: String, pages: List<Int>, cacheDir: String): String
    private external fun reorderPdfNative(inputPath: String, cacheDir: String): Array<String>
    external fun isPdfEncryptedNative(inputPath: String): Boolean


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("NativeDemo", "MainActivity created")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "imageToPdf" -> {
                    val imagePaths = call.argument<List<String>>("paths")?.toTypedArray() ?: emptyArray()
                    val cacheDir = applicationContext.cacheDir.absolutePath
                    
                    scope.launch {
                        try {
                            val pdfPath = withContext(Dispatchers.IO) {
                                imageToPdfNative(imagePaths, cacheDir)
                            }
                            result.success(pdfPath)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Failed to create PDF: ${e.message}")
                            result.error("PDF_CREATION_FAILED", "Failed to create PDF: ${e.message}", null)
                        }
                    }
                }
                "mergePdf" -> {
                    val pdfPaths = call.argument<List<String>>("paths")?.toTypedArray() ?: emptyArray()
                    val cacheDir = applicationContext.cacheDir.absolutePath

                    scope.launch {
                        try {
                            val encryptedFile = pdfPaths.firstOrNull { isPdfEncryptedNative(it) }
                            if (encryptedFile != null) {
                                result.error("CANNOT_MERGE_ENCRYPTED", "One or more PDFs are encrypted. Please decrypt before merging.", null)
                                return@launch
                            }

                            val pdfPath = withContext(Dispatchers.IO) {
                                mergePdfNative(pdfPaths, cacheDir)
                            }
                            result.success(pdfPath)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Failed to merge PDFs: ${e.message}")
                            result.error("PDF_MERGE_FAILED", "Failed to merge PDFs: ${e.message}", null)
                        }
                    }
                }

                "encryptPdf" -> {
                    val path = call.argument<String>("path") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "Missing path", null)
                    val password = call.argument<String>("password") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "Missing password", null)
                    val cacheDir = applicationContext.cacheDir.absolutePath

                    scope.launch {
                        try {
                            if (isPdfEncryptedNative(path)) {
                                result.error("ALREADY_ENCRYPTED", "PDF is already encrypted", null)
                                return@launch
                            }

                            val res = withContext(Dispatchers.IO) {
                                encryptPdfNative(path, password, cacheDir)
                            }

                            when {
                                res.startsWith("ERROR:") -> result.error("ENCRYPTION_FAILED", res, null)
                                res.isEmpty() -> result.error("EMPTY_RESULT", "No result returned from native code", null)
                                else -> result.success(res)
                            }
                        } catch (e: Exception) {
                            result.error("EXCEPTION", "Exception during encryption: ${e.message}", null)
                        }
                    }
                }

                "splitPdf" -> {
                    val path = call.argument<String>("path") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "Missing path", null)
                    val pages = call.argument<List<Int>>("pages") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "Missing pages", null)
                    val cacheDir = applicationContext.cacheDir.absolutePath

                    scope.launch {
                        try {
                            if (isPdfEncryptedNative(path)) {
                                result.error("CANNOT_SPLIT_ENCRYPTED", "Cannot split an encrypted PDF. Please decrypt it first.", null)
                                return@launch
                            }

                            val res = withContext(Dispatchers.IO) {
                                splitPdfNative(path, pages, cacheDir)
                            }
                            result.success(res)
                        } catch (e: Exception) {
                            result.error("EXCEPTION", e.message, null)
                        }
                    }
                }

                "reorderPdf" -> {
                    val inputPath = call.argument<String>("path")
                    val cacheDir = applicationContext.cacheDir.absolutePath

                    if (inputPath == null) {
                        result.error("INVALID_ARGUMENT", "path is null", null)
                        return@setMethodCallHandler
                    }

                    scope.launch {
                        try {
                            if (isPdfEncryptedNative(inputPath)) {
                                result.error(
                                    "CANNOT_REORDER_ENCRYPTED",
                                    "Cannot reorder an encrypted PDF. Please decrypt it first.",
                                    null
                                )
                                return@launch
                            }

                            // Native call returns String[] directly
                            val imagePaths = withContext(Dispatchers.IO) {
                                reorderPdfNative(inputPath, cacheDir)
                            }

                            // Convert Array<String> to List<String> for Flutter
                            if (imagePaths != null && imagePaths.isNotEmpty()) {
                                Log.d("MainActivity", "Got ${imagePaths.size} image paths from native code")
                                // Explicitly convert to List<String> to ensure type safety
                                val stringList = imagePaths.map { it.toString() }
                                result.success(stringList)
                            } else {
                                Log.e("MainActivity", "Native code returned null or empty array")
                                result.error("REORDER_FAILED", "Failed to get image paths from native code", null)
                            }
                        } catch (e: Exception) {
                            result.error("REORDER_FAILED", e.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}