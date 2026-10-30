# Project-specific R8 rules.
# JNI methods in PdfNative are kept by the default proguard-android-optimize.txt rules.

# Constructed by name from native code (cpp/native-lib.cpp).
-keep class com.bluepdf.blue_pdf.PdfException {
    <init>(java.lang.String, java.lang.String);
}

# onProgress is looked up by name from native code.
-keep interface com.bluepdf.blue_pdf.PdfProgressListener { *; }
-keepclassmembers class * implements com.bluepdf.blue_pdf.PdfProgressListener {
    boolean onProgress(int, int, int, float);
}
