// JNI bindings for com.bluepdf.blue_pdf.PdfNative. Failures are raised as
// com.bluepdf.blue_pdf.PdfException(code, message).
#include <jni.h>

#include <cstdint>
#include <string>
#include <vector>

#include "pdf_ops.h"

namespace {

// GetStringUTFChars yields "modified UTF-8", which encodes characters outside
// the BMP (emoji in file names, for example) differently from the file system.
std::string ToUtf8(JNIEnv* env, jstring value) {
    if (!value) return {};
    const jsize len = env->GetStringLength(value);
    const jchar* chars = env->GetStringChars(value, nullptr);
    std::string out;
    out.reserve(static_cast<size_t>(len));
    for (jsize i = 0; i < len; ++i) {
        uint32_t cp = chars[i];
        if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < len && chars[i + 1] >= 0xDC00 &&
            chars[i + 1] <= 0xDFFF) {
            cp = 0x10000 + ((cp - 0xD800) << 10) + (chars[i + 1] - 0xDC00);
            ++i;
        }
        if (cp < 0x80) {
            out += static_cast<char>(cp);
        } else if (cp < 0x800) {
            out += static_cast<char>(0xC0 | (cp >> 6));
            out += static_cast<char>(0x80 | (cp & 0x3F));
        } else if (cp < 0x10000) {
            out += static_cast<char>(0xE0 | (cp >> 12));
            out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
            out += static_cast<char>(0x80 | (cp & 0x3F));
        } else {
            out += static_cast<char>(0xF0 | (cp >> 18));
            out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
            out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
            out += static_cast<char>(0x80 | (cp & 0x3F));
        }
    }
    env->ReleaseStringChars(value, chars);
    return out;
}

std::vector<std::string> ToStrings(JNIEnv* env, jobjectArray array) {
    std::vector<std::string> out;
    if (!array) return out;
    const jsize len = env->GetArrayLength(array);
    out.reserve(static_cast<size_t>(len));
    for (jsize i = 0; i < len; ++i) {
        auto item = static_cast<jstring>(env->GetObjectArrayElement(array, i));
        out.push_back(ToUtf8(env, item));
        env->DeleteLocalRef(item);
    }
    return out;
}

std::vector<int> ToInts(JNIEnv* env, jintArray array) {
    std::vector<int> out;
    if (!array) return out;
    const jsize len = env->GetArrayLength(array);
    out.resize(static_cast<size_t>(len));
    env->GetIntArrayRegion(array, 0, len, reinterpret_cast<jint*>(out.data()));
    return out;
}

jintArray ToIntArray(JNIEnv* env, const std::vector<int>& values) {
    jintArray array = env->NewIntArray(static_cast<jsize>(values.size()));
    if (array && !values.empty()) {
        env->SetIntArrayRegion(array, 0, static_cast<jsize>(values.size()),
                               reinterpret_cast<const jint*>(values.data()));
    }
    return array;
}

// NewStringUTF aborts on malformed input, so messages are reduced to ASCII.
std::string Ascii(const std::string& text) {
    std::string out = text;
    for (char& c : out) {
        if (static_cast<unsigned char>(c) >= 0x80) c = '?';
    }
    return out;
}

void Throw(JNIEnv* env, const bluepdf::Status& status) {
    jclass cls = env->FindClass("com/bluepdf/blue_pdf/PdfException");
    if (!cls) return;
    jmethodID ctor = env->GetMethodID(cls, "<init>", "(Ljava/lang/String;Ljava/lang/String;)V");
    if (!ctor) return;
    jstring code = env->NewStringUTF(status.code.c_str());
    jstring message = env->NewStringUTF(Ascii(status.message).c_str());
    auto error = static_cast<jthrowable>(env->NewObject(cls, ctor, code, message));
    if (error) env->Throw(error);
}

// Forwards progress to PdfProgressListener.onProgress(stage, done, total, fraction),
// whose return value says whether to keep going. Valid for the current JNI call only.
bluepdf::ProgressFn ToProgress(JNIEnv* env, jobject listener) {
    if (!listener) return {};
    jclass cls = env->GetObjectClass(listener);
    jmethodID method = env->GetMethodID(cls, "onProgress", "(IIIF)Z");
    env->DeleteLocalRef(cls);
    if (!method) {
        env->ExceptionClear();
        return {};
    }
    return [env, listener, method](const bluepdf::Progress& p) {
        const jboolean keep_going = env->CallBooleanMethod(
            listener, method, static_cast<jint>(p.stage), p.done, p.total, p.fraction);
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
            return true;
        }
        return keep_going == JNI_TRUE;
    };
}

}  // namespace

#define PDF_NATIVE(name) Java_com_bluepdf_blue_1pdf_PdfNative_##name

extern "C" JNIEXPORT jintArray JNICALL
PDF_NATIVE(inspect)(JNIEnv* env, jobject, jstring path, jstring password) {
    bluepdf::PdfInfo info;
    const auto status = bluepdf::InspectPdf(ToUtf8(env, path), ToUtf8(env, password), &info);
    if (!status.ok()) {
        Throw(env, status);
        return nullptr;
    }
    return ToIntArray(env, {info.page_count, info.encrypted ? 1 : 0});
}

extern "C" JNIEXPORT jintArray JNICALL
PDF_NATIVE(imagesToPdf)(JNIEnv* env, jobject, jobjectArray images, jintArray rotations,
                        jboolean fitToImage, jstring outPath, jobject progress) {
    std::vector<int> skipped;
    const auto status = bluepdf::ImagesToPdf(
        ToStrings(env, images), ToInts(env, rotations),
        fitToImage ? bluepdf::PageMode::kFit : bluepdf::PageMode::kA4, ToUtf8(env, outPath), &skipped,
        ToProgress(env, progress));
    if (!status.ok()) {
        Throw(env, status);
        return nullptr;
    }
    return ToIntArray(env, skipped);
}

extern "C" JNIEXPORT void JNICALL
PDF_NATIVE(merge)(JNIEnv* env, jobject, jobjectArray paths, jobjectArray passwords, jstring outPath,
                  jobject progress) {
    const auto status = bluepdf::MergePdfs(ToStrings(env, paths), ToStrings(env, passwords),
                                           ToUtf8(env, outPath), ToProgress(env, progress));
    if (!status.ok()) Throw(env, status);
}

extern "C" JNIEXPORT void JNICALL
PDF_NATIVE(extractPages)(JNIEnv* env, jobject, jstring path, jstring password, jintArray pages,
                         jintArray rotations, jstring outPath, jobject progress) {
    const auto status = bluepdf::ExtractPages(ToUtf8(env, path), ToUtf8(env, password),
                                              ToInts(env, pages), ToInts(env, rotations),
                                              ToUtf8(env, outPath), ToProgress(env, progress));
    if (!status.ok()) Throw(env, status);
}

extern "C" JNIEXPORT void JNICALL
PDF_NATIVE(encrypt)(JNIEnv* env, jobject, jstring path, jstring newPassword, jstring outPath,
                    jobject progress) {
    const auto status = bluepdf::EncryptPdf(ToUtf8(env, path), ToUtf8(env, newPassword),
                                            ToUtf8(env, outPath), ToProgress(env, progress));
    if (!status.ok()) Throw(env, status);
}

extern "C" JNIEXPORT void JNICALL
PDF_NATIVE(renderPage)(JNIEnv* env, jobject, jstring path, jstring password, jint page, jint width,
                       jstring outPath) {
    const auto status = bluepdf::RenderPage(ToUtf8(env, path), ToUtf8(env, password), page, width,
                                            ToUtf8(env, outPath));
    if (!status.ok()) Throw(env, status);
}
