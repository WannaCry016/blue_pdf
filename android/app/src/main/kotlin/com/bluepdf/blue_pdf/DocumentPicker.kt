package com.bluepdf.blue_pdf

import android.app.Activity
import android.content.Intent
import android.net.Uri

/**
 * Opens the system picker and hands back the chosen content URIs without
 * reading them. Copying is a separate job ([FileImporter]), so the app can show
 * progress the moment the picker closes instead of after every file is copied.
 */
class DocumentPicker(private val activity: Activity) {

    private var pending: ((List<Uri>) -> Unit)? = null

    /**
     * Calls [onPicked] on the main thread with the selection in order, or an empty
     * list if the user backs out. Returns false if a picker is already open.
     */
    fun pick(kind: String, multiple: Boolean, onPicked: (List<Uri>) -> Unit): Boolean {
        if (pending != null) return false
        val intent = when (kind) {
            // Opens the photo picker where the device has one, the file browser otherwise.
            "images" -> Intent(Intent.ACTION_GET_CONTENT).setType("image/*")
            "pdf" -> Intent(Intent.ACTION_OPEN_DOCUMENT).setType("application/pdf")
            else -> throw IllegalArgumentException("Unknown kind '$kind'")
        }
            .addCategory(Intent.CATEGORY_OPENABLE)
            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)

        activity.startActivityForResult(intent, REQUEST_CODE)
        pending = onPicked
        return true
    }

    /** Returns true if the result was a pick, which then needs no further handling. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        // Null when the activity was recreated while the picker was open; nobody is waiting.
        val onPicked = pending ?: return true
        pending = null
        onPicked(if (resultCode == Activity.RESULT_OK && data != null) urisOf(data) else emptyList())
        return true
    }

    private fun urisOf(data: Intent): List<Uri> {
        val clip = data.clipData ?: return listOfNotNull(data.data)
        return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
    }

    private companion object {
        const val REQUEST_CODE = 0x4250
    }
}
