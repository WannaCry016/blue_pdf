package com.bluepdf.blue_pdf

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.bluepdf.channel/pdf"

    companion object {
        init {
            System.loadLibrary("pdfium")      // Load PDFium first
            System.loadLibrary("native-lib")  // Then your native-lib
        }
    }

    // Native function declarations
    external fun imageToPdfNative(imagePaths: Array<String>, compression: Int, cacheDir: String): String
    external fun mergePdfNative(): String
    external fun encryptPdfNative(): String
    external fun splitPdfNative(): String
    external fun reorderPdfNative(): String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("NativeDemo", "MainActivity created")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            when (call.method) {
                "imageToPdf" -> {
                    val imagePaths = call.argument<List<String>>("paths")?.toTypedArray() ?: emptyArray()
                    val compression = call.argument<Int>("compression") ?: 2
                    val cacheDir = applicationContext.cacheDir.absolutePath
                    val res = imageToPdfNative(imagePaths, compression, cacheDir)
                    result.success(res)
                }
                "mergePdf" -> {
                    val res = mergePdfNative()
                    result.success(res)
                }
                "encryptPdf" -> {
                    val res = encryptPdfNative()
                    result.success(res)
                }
                "splitPdf" -> {
                    val res = splitPdfNative()
                    result.success(res)
                }
                "reorderPdf" -> {
                    val res = reorderPdfNative()
                    result.success(res)
                }
                else -> result.notImplemented()
            }
        }
    }
}
