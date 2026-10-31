package com.bluepdf.blue_pdf

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private val picker = DocumentPicker(this)
    private var pdfChannel: PdfChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pdfChannel = PdfChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger, picker)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pdfChannel?.dispose()
        pdfChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // Results the picker doesn't own still go to plugins through super.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!picker.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
