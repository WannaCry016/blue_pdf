package com.bluepdf.blue_pdf

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var pdfChannel: PdfChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pdfChannel = PdfChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pdfChannel?.dispose()
        pdfChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
