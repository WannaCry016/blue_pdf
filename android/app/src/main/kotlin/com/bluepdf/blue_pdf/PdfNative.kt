package com.bluepdf.blue_pdf

/** Raised by native code; [code] is one of the codes in cpp/pdf_ops.h. */
class PdfException(val code: String, message: String) : Exception(message)

/** MuPDF operations implemented in cpp/pdf_ops.cpp. All calls block; never call them on the main thread. */
object PdfNative {
    init {
        System.loadLibrary("native-lib")
    }

    /** Returns `[pageCount, encrypted (0/1)]`. */
    external fun inspect(path: String, password: String?): IntArray

    /** Returns the indices of images that could not be read. */
    external fun imagesToPdf(images: Array<String>, rotations: IntArray, fitToImage: Boolean, outPath: String): IntArray

    external fun merge(paths: Array<String>, passwords: Array<String?>, outPath: String)

    external fun extractPages(path: String, password: String?, pages: IntArray, rotations: IntArray, outPath: String)

    external fun encrypt(path: String, newPassword: String, outPath: String)

    external fun renderPage(path: String, password: String?, page: Int, width: Int, outPath: String)
}
