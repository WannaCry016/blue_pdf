#include <jni.h>
#include <string>
#include <android/log.h>

#define LOG_TAG "NativeDemo"
#define LOGI(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

// --- IMAGE TO PDF ---
extern "C"
JNIEXPORT jstring JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_imageToPdfNative(JNIEnv *env, jobject /* this */, jobjectArray imagePaths, jint compression, jstring cacheDir) {
    int numImages = env->GetArrayLength(imagePaths);
    const char* cacheDirStr = env->GetStringUTFChars(cacheDir, nullptr);
    LOGI("Image to PDF called with %d images, compression=%d, cacheDir=%s", numImages, compression, cacheDirStr);
    // Construct output file path
    char outputPath[512];
    snprintf(outputPath, sizeof(outputPath), "%s/image_to_pdf_%lld.pdf", cacheDirStr, (long long)time(nullptr));
    // Log image paths
    for (int i = 0; i < numImages; ++i) {
        jstring jPath = (jstring) env->GetObjectArrayElement(imagePaths, i);
        const char* path = env->GetStringUTFChars(jPath, nullptr);
        LOGI("Image %d: %s", i, path);
        env->ReleaseStringUTFChars(jPath, path);
        env->DeleteLocalRef(jPath);
    }
    // TODO: Implement PDFium logic to create PDF at outputPath
    env->ReleaseStringUTFChars(cacheDir, cacheDirStr);
    return env->NewStringUTF(outputPath);
}

// --- MERGE PDF ---
extern "C"
JNIEXPORT jstring JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_mergePdfNative(JNIEnv *env, jobject /* this */) {
    LOGI("Merge PDF called");
    return env->NewStringUTF("Merge PDF done (native stub)");
}

// --- ENCRYPT PDF ---
extern "C"
JNIEXPORT jstring JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_encryptPdfNative(JNIEnv *env, jobject /* this */) {
    LOGI("Encrypt PDF called");
    return env->NewStringUTF("Encrypt PDF done (native stub)");
}

// --- SPLIT PDF ---
extern "C"
JNIEXPORT jstring JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_splitPdfNative(JNIEnv *env, jobject /* this */) {
    LOGI("Split PDF called");
    return env->NewStringUTF("Split PDF done (native stub)");
}

// --- REORDER PDF ---
extern "C"
JNIEXPORT jstring JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_reorderPdfNative(JNIEnv *env, jobject /* this */) {
    LOGI("Reorder PDF called");
    return env->NewStringUTF("Reorder PDF done (native stub)");
}
