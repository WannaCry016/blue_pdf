#include <jni.h>
#include <string>
#include <android/log.h>
#include <vector>
#include <cstring>
#include <sys/stat.h>
#include <algorithm>

extern "C" {
    #include "mupdf/fitz.h"
    #include "mupdf/pdf.h"
}

#define LOG_TAG "MuPDFNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

// A4 size in points (72 DPI)
#define A4_WIDTH 595.0f
#define A4_HEIGHT 842.0f

// --- Initialize MuPDF ---
fz_context* init_context() {
    fz_context* ctx = fz_new_context(nullptr, nullptr, FZ_STORE_UNLIMITED);
    if (!ctx) {
        LOGI("Failed to create context");
        return nullptr;
    }
    fz_register_document_handlers(ctx);
    return ctx;
}

// --- IMAGE TO PDF ---
extern "C"
JNIEXPORT jstring JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_imageToPdfNative(JNIEnv* env, jobject,
                                                         jobjectArray imagePaths,
                                                         jstring cacheDir,
                                                         jstring pageSizeMode) {
    fz_context* ctx = init_context();
    if (!ctx) return env->NewStringUTF("");

    const char* dir = env->GetStringUTFChars(cacheDir, nullptr);
    const char* mode = env->GetStringUTFChars(pageSizeMode, nullptr);
    std::string outputPath = std::string(dir) + "/output.pdf";

    fz_document_writer* writer = nullptr;

    fz_try(ctx) {
        writer = fz_new_document_writer(ctx, outputPath.c_str(), "pdf", nullptr);
    } fz_catch(ctx) {
        fz_drop_context(ctx);
        env->ReleaseStringUTFChars(cacheDir, dir);
        env->ReleaseStringUTFChars(pageSizeMode, mode);
        return env->NewStringUTF("");
    }

    jsize len = env->GetArrayLength(imagePaths);
    for (int i = 0; i < len; i++) {
        jstring imgPath = (jstring)env->GetObjectArrayElement(imagePaths, i);
        const char* path = env->GetStringUTFChars(imgPath, nullptr);

        fz_try(ctx) {
            fz_image* img = fz_new_image_from_file(ctx, path);
            int img_w = img->w;
            int img_h = img->h;

            fz_rect page_rect;
            fz_matrix m;

            if (strcmp(mode, "A4") == 0) {
                const float A4_W = 595.0f; // 8.27 inch * 72
                const float A4_H = 842.0f; // 11.69 inch * 72
                page_rect = fz_make_rect(0, 0, A4_W, A4_H);

                // Desired DPI (can also be 150, 200, etc.)
                const float dpi = 150.0f;

                // Convert image size in pixels to points (1 inch = 72 points)
                float img_w_pt = (img_w / dpi) * 72.0f;
                float img_h_pt = (img_h / dpi) * 72.0f;

                // Fit image into A4 while maintaining aspect ratio
                float scale_x = A4_W / img_w_pt;
                float scale_y = A4_H / img_h_pt;
                float scale = fminf(scale_x, scale_y);

                // Final scaled image size (optional)
                float final_w = img_w_pt * scale;
                float final_h = img_h_pt * scale;
                
                float offset_x = (A4_W - final_w) / 2.0f;
                float offset_y = (A4_H - final_h) / 2.0f;

                m = fz_translate(offset_x, offset_y);
                m = fz_concat(fz_scale(final_w , final_h), m); 
            } else {
                page_rect = fz_make_rect(0, 0, (float)img_w, (float)img_h);
                m = fz_scale((float)img_w, (float)img_h);
            }

            fz_device* dev = fz_begin_page(ctx, writer, page_rect);
            fz_fill_image(ctx, dev, img, m, 1.0f, fz_default_color_params);
            fz_end_page(ctx, writer);
            fz_drop_image(ctx, img);
        } fz_catch(ctx) {
            LOGI("Failed on image %s", path);
        }

        env->ReleaseStringUTFChars(imgPath, path);
    }

    fz_try(ctx) {
        fz_close_document_writer(ctx, writer);
        fz_drop_document_writer(ctx, writer);
    } fz_catch(ctx) {
        LOGI("Failed to finalize PDF");
    }

    fz_drop_context(ctx);
    env->ReleaseStringUTFChars(cacheDir, dir);
    env->ReleaseStringUTFChars(pageSizeMode, mode);

    return env->NewStringUTF(outputPath.c_str());
}



// --- MERGE PDF --- WORKING
extern "C" JNIEXPORT jstring JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_mergePdfNative(JNIEnv* env, jobject /* this */,
                                                       jobjectArray pdfPaths, jstring cacheDir) {
    LOGI("Merge PDF called");

    fz_context* ctx = init_context();
    if (!ctx) return env->NewStringUTF("");

    const char* dir = env->GetStringUTFChars(cacheDir, nullptr);
    std::string outputPath = std::string(dir) + "/merged.pdf";

    fz_document_writer* writer = nullptr;

    fz_try(ctx) {
        fz_register_document_handlers(ctx);  // Register PDF and other formats
        const char* pdf_options = "compress-images=no,compress-fonts=no";
        writer = fz_new_document_writer(ctx, outputPath.c_str(), "pdf", pdf_options);

        jsize len = env->GetArrayLength(pdfPaths);
        LOGI("Merging %d PDF files", (int)len);

        for (jsize i = 0; i < len; i++) {
            jstring jPath = (jstring) env->GetObjectArrayElement(pdfPaths, i);
            const char* path = env->GetStringUTFChars(jPath, nullptr);

            fz_document* doc = fz_open_document(ctx, path);
            if (!doc) {
                LOGI("Failed to open document: %s", path);
                env->ReleaseStringUTFChars(jPath, path);
                env->DeleteLocalRef(jPath);
                continue;
            }

            int pageCount = fz_count_pages(ctx, doc);
            LOGI("PDF %d has %d pages", (int)i, pageCount);

            for (int j = 0; j < pageCount; j++) {
                fz_page* page = fz_load_page(ctx, doc, j);
                fz_rect bounds = fz_bound_page(ctx, page);

                if (fz_is_empty_rect(bounds)) {
                    LOGI("Page %d in doc %d has empty bounds; skipping", j, (int)i);
                    fz_drop_page(ctx, page);
                    continue;
                }

                fz_device* dev = fz_begin_page(ctx, writer, bounds);
                fz_run_page(ctx, page, dev, fz_identity, nullptr);
                fz_end_page(ctx, writer);
                fz_drop_page(ctx, page);
            }

            fz_drop_document(ctx, doc);
            env->ReleaseStringUTFChars(jPath, path);
            env->DeleteLocalRef(jPath);
        }

        fz_close_document_writer(ctx, writer);
        fz_drop_document_writer(ctx, writer);

    } fz_catch(ctx) {
        LOGI("Error merging PDFs");
        if (writer) fz_drop_document_writer(ctx, writer);
        fz_drop_context(ctx);
        env->ReleaseStringUTFChars(cacheDir, dir);
        return env->NewStringUTF("");
    }

    fz_drop_context(ctx);
    env->ReleaseStringUTFChars(cacheDir, dir);
    return env->NewStringUTF(outputPath.c_str());
}


// --- ENCRYPT PDF ---
extern "C" JNIEXPORT jstring JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_encryptPdfNative(JNIEnv* env, jobject /* this */,
                                                         jstring inputPath, jstring password,
                                                         jstring cacheDir) {
    fz_context* ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) return env->NewStringUTF("");

    fz_register_document_handlers(ctx);

    const char* dir = env->GetStringUTFChars(cacheDir, nullptr);
    const char* input = env->GetStringUTFChars(inputPath, nullptr);
    const char* pass = env->GetStringUTFChars(password, nullptr);
    
    std::string inputFile(input);
    std::string outputPath = std::string(dir) + "/encrypted.pdf";
    std::string userPassword(pass);
    
    // Release JNI strings
    env->ReleaseStringUTFChars(cacheDir, dir);
    env->ReleaseStringUTFChars(inputPath, input);
    env->ReleaseStringUTFChars(password, pass);

    pdf_document* doc = nullptr;
    pdf_write_options opts = pdf_default_write_options;
    
    fz_try(ctx) {
        // Open the input PDF
        doc = pdf_open_document(ctx, inputFile.c_str());
        
        // Set up encryption options
        opts.do_encrypt = PDF_ENCRYPT_AES_256;  // Use AES 256-bit encryption
        strncpy(opts.opwd_utf8, userPassword.c_str(), sizeof(opts.opwd_utf8) - 1);
        opts.opwd_utf8[sizeof(opts.opwd_utf8) - 1] = '\0';

        strncpy(opts.upwd_utf8, userPassword.c_str(), sizeof(opts.upwd_utf8) - 1);
        opts.upwd_utf8[sizeof(opts.upwd_utf8) - 1] = '\0';

        
        // Set permissions (allow all operations by default)
        opts.permissions = PDF_PERM_PRINT | PDF_PERM_MODIFY | PDF_PERM_COPY | 
                          PDF_PERM_ANNOTATE | PDF_PERM_FORM | PDF_PERM_ACCESSIBILITY |
                          PDF_PERM_ASSEMBLE | PDF_PERM_PRINT_HQ;
        
        // Additional write options
        opts.do_incremental = 0;        // Full rewrite
        opts.do_ascii = 0;              // Binary output
        opts.do_compress = 1;           // Compress streams
        opts.do_compress_images = 1;    // Compress images
        opts.do_compress_fonts = 1;     // Compress fonts
        opts.do_decompress = 0;         // Don't decompress
        opts.do_garbage = 1;            // Remove unused objects
        opts.do_linear = 0;             // Don't linearize
        opts.do_clean = 1;              // Clean up document
        opts.do_sanitize = 1;           // Sanitize document
        opts.do_pretty = 0;             // Don't pretty print
        
        // Save the encrypted PDF
        pdf_save_document(ctx, doc, outputPath.c_str(), &opts);
        
    }
    fz_always(ctx) {
        if (doc) pdf_drop_document(ctx, doc);
    }
    fz_catch(ctx) {
        fz_drop_context(ctx);
        return env->NewStringUTF("");  // Return empty string on error
    }

    fz_drop_context(ctx);
    return env->NewStringUTF(outputPath.c_str());
}

// Helper function to check if PDF is encrypted
extern "C" JNIEXPORT jboolean JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_isPdfEncryptedNative(JNIEnv* env, jobject /* this */,
                                                            jstring inputPath) {
    fz_context* ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) return JNI_FALSE;

    fz_register_document_handlers(ctx);

    const char* input = env->GetStringUTFChars(inputPath, nullptr);
    std::string inputFile(input);
    env->ReleaseStringUTFChars(inputPath, input);

    pdf_document* doc = nullptr;
    jboolean isEncrypted = JNI_FALSE;
    
    fz_try(ctx) {
        doc = pdf_open_document(ctx, inputFile.c_str());
        isEncrypted = pdf_needs_password(ctx, doc) ? JNI_TRUE : JNI_FALSE;
    }
    fz_always(ctx) {
        if (doc) pdf_drop_document(ctx, doc);
    }
    fz_catch(ctx) {
        // If we can't open it, assume it might be encrypted or corrupted
        isEncrypted = JNI_FALSE;
    }

    fz_drop_context(ctx);
    return isEncrypted;
}

// --- SPLIT PDF ---
// Option 1: Handle ArrayList<Integer> in C++
extern "C" JNIEXPORT jstring JNICALL 
Java_com_bluepdf_blue_1pdf_MainActivity_splitPdfNative(JNIEnv* env, jobject,
                                                        jstring inputPath,
                                                        jobject pagesList,  // Changed to jobject to handle List
                                                        jstring cacheDir,
                                                    jstring outputFilename) {
    const char* input_cstr = env->GetStringUTFChars(inputPath, nullptr);
    const char* cacheDir_cstr = env->GetStringUTFChars(cacheDir, nullptr);

    std::string inputFile(input_cstr);
    std::string cacheDirStr(cacheDir_cstr);
    env->ReleaseStringUTFChars(inputPath, input_cstr);
    env->ReleaseStringUTFChars(cacheDir, cacheDir_cstr);

    std::string outputPath;
    if (outputFilename != nullptr) {
        const char* outputFilename_cstr = env->GetStringUTFChars(outputFilename, nullptr);
        outputPath = cacheDirStr + "/" + outputFilename_cstr;
        env->ReleaseStringUTFChars(outputFilename, outputFilename_cstr);
    } else {
        outputPath = cacheDirStr + "/split_output.pdf";
    }


    // Get List class and methods
    jclass listClass = env->GetObjectClass(pagesList);
    jmethodID sizeMethod = env->GetMethodID(listClass, "size", "()I");
    jmethodID getMethod = env->GetMethodID(listClass, "get", "(I)Ljava/lang/Object;");
    
    if (!sizeMethod || !getMethod) {
        return env->NewStringUTF("");
    }

    jint listSize = env->CallIntMethod(pagesList, sizeMethod);
    if (listSize <= 0) return env->NewStringUTF("");

    // Convert ArrayList<Integer> to vector<int>
    std::vector<int> pages;
    jclass integerClass = env->FindClass("java/lang/Integer");
    jmethodID intValueMethod = env->GetMethodID(integerClass, "intValue", "()I");
    
    for (int i = 0; i < listSize; i++) {
        jobject integerObj = env->CallObjectMethod(pagesList, getMethod, i);
        if (integerObj) {
            jint pageNum = env->CallIntMethod(integerObj, intValueMethod);
            pages.push_back(pageNum);
            env->DeleteLocalRef(integerObj);
        }
    }

    fz_context* ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) return env->NewStringUTF("");

    fz_register_document_handlers(ctx);

    fz_document* doc = nullptr;
    fz_document_writer* writer = nullptr;

    fz_try(ctx) {
        doc = fz_open_document(ctx, inputFile.c_str());
        int totalPages = fz_count_pages(ctx, doc);

        // Create PDF writer with correct signature
        writer = fz_new_document_writer(ctx, outputPath.c_str(), "pdf", nullptr);

        for (size_t i = 0; i < pages.size(); ++i) {
            int pageNumber = pages[i];
            if (pageNumber < 1 || pageNumber > totalPages) continue;

            fz_page* page = fz_load_page(ctx, doc, pageNumber - 1);
            fz_rect bounds = fz_bound_page(ctx, page);

            fz_device* dev = fz_begin_page(ctx, writer, bounds);
            fz_run_page(ctx, page, dev, fz_identity, nullptr);
            fz_end_page(ctx, writer);

            fz_drop_page(ctx, page);
        }

        fz_close_document_writer(ctx, writer);
    }
    fz_always(ctx) {
        if (writer) fz_drop_document_writer(ctx, writer);
        if (doc) fz_drop_document(ctx, doc);
    }
    fz_catch(ctx) {
        fz_drop_context(ctx);
        return env->NewStringUTF("");
    }

    fz_drop_context(ctx);
    return env->NewStringUTF(outputPath.c_str());
}

// REORDER PDF
extern "C"
JNIEXPORT jobjectArray JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_reorderPdfNative(JNIEnv* env, jobject thiz,
                                                          jstring inputPath,
                                                          jstring cacheDir) {
    const char* input_cstr = env->GetStringUTFChars(inputPath, nullptr);
    const char* cacheDir_cstr = env->GetStringUTFChars(cacheDir, nullptr);
    std::string inputFile(input_cstr);
    std::string cacheDirStr(cacheDir_cstr);

    env->ReleaseStringUTFChars(inputPath, input_cstr);
    env->ReleaseStringUTFChars(cacheDir, cacheDir_cstr);

    fz_context* ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) {
        LOGI("Failed to create MuPDF context");
        return env->NewObjectArray(0, env->FindClass("java/lang/String"), nullptr);
    }

    fz_register_document_handlers(ctx);
    fz_set_aa_level(ctx, 8); // anti-aliasing
    fz_set_text_aa_level(ctx, 8); // text anti-aliasing

    fz_document* doc = nullptr;
    fz_try(ctx) {
        doc = fz_open_document(ctx, inputFile.c_str());
    } fz_catch(ctx) {
        LOGI("Failed to open document: %s", inputFile.c_str());
        fz_drop_context(ctx);
        return env->NewObjectArray(0, env->FindClass("java/lang/String"), nullptr);
    }

    int totalPages = fz_count_pages(ctx, doc);
    std::vector<std::string> imagePaths;
    float scaleFactor = 2.0f;  // 2x scale for higher resolution

    for (int i = 0; i < totalPages; ++i) {
        fz_page* page = nullptr;
        fz_pixmap* pix = nullptr;
        fz_device* dev = nullptr;

        fz_try(ctx) {
            page = fz_load_page(ctx, doc, i);
            fz_rect bounds = fz_bound_page(ctx, page);

            if (fz_is_empty_rect(bounds) || (bounds.x1 - bounds.x0) < 10 || (bounds.y1 - bounds.y0) < 10) {
                LOGI("Page %d has empty or very small bounds, skipping", i + 1);
                continue;
            }

            fz_matrix ctm = fz_scale(scaleFactor, scaleFactor);
            fz_irect bbox = fz_round_rect(fz_transform_rect(bounds, ctm));

            pix = fz_new_pixmap_with_bbox(ctx, fz_device_rgb(ctx), bbox, nullptr, 0);
            fz_clear_pixmap_with_value(ctx, pix, 0xFF);

            fz_matrix transform = fz_identity;
            dev = fz_new_draw_device(ctx, transform, pix);

            fz_run_page(ctx, page, dev, ctm, nullptr);
            fz_close_device(ctx, dev);

            std::string outPath = cacheDirStr + "/page_" + std::to_string(i + 1) + ".png";
            fz_save_pixmap_as_png(ctx, pix, outPath.c_str());
            imagePaths.push_back(outPath);

        } fz_always(ctx) {
            if (dev) fz_drop_device(ctx, dev);
            if (pix) fz_drop_pixmap(ctx, pix);
            if (page) fz_drop_page(ctx, page);
        } fz_catch(ctx) {
            LOGI("Error rendering page %d", i + 1);
            continue;
        }
    }

    fz_drop_document(ctx, doc);
    fz_drop_context(ctx);

    jclass stringClass = env->FindClass("java/lang/String");
    jobjectArray result = env->NewObjectArray(static_cast<jsize>(imagePaths.size()), stringClass, nullptr);

    for (size_t i = 0; i < imagePaths.size(); ++i) {
        jstring path = env->NewStringUTF(imagePaths[i].c_str());
        env->SetObjectArrayElement(result, static_cast<jsize>(i), path);
        env->DeleteLocalRef(path);
    }

    return result;
}


// RENDER PDF PAGE
extern "C"
JNIEXPORT jstring JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_renderPdfPageNative(
        JNIEnv *env, jobject thiz,
        jstring inputPath,
        jint pageNumber,
        jstring cacheDir) {

    const char* input_cstr = env->GetStringUTFChars(inputPath, nullptr);
    const char* cacheDir_cstr = env->GetStringUTFChars(cacheDir, nullptr);
    std::string inputFile(input_cstr);
    std::string cacheDirStr(cacheDir_cstr);

    env->ReleaseStringUTFChars(inputPath, input_cstr);
    env->ReleaseStringUTFChars(cacheDir, cacheDir_cstr);

    fz_context* ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) {
        LOGI("Failed to create MuPDF context");
        return env->NewStringUTF("");
    }

    fz_register_document_handlers(ctx);
    fz_set_aa_level(ctx, 8);
    fz_set_text_aa_level(ctx, 8);

    fz_document* doc = nullptr;
    fz_try(ctx) {
        doc = fz_open_document(ctx, inputFile.c_str());
    } fz_catch(ctx) {
        LOGI("Failed to open document");
        fz_drop_context(ctx);
        return env->NewStringUTF("");
    }

    int totalPages = fz_count_pages(ctx, doc);
    if (pageNumber < 0 || pageNumber >= totalPages) {
        fz_drop_document(ctx, doc);
        fz_drop_context(ctx);
        return env->NewStringUTF("");
    }

    fz_page* page = nullptr;
    fz_pixmap* pix = nullptr;
    fz_device* dev = nullptr;
    std::string outPath;

    float scaleFactor = 1.0f;

    fz_try(ctx) {
        page = fz_load_page(ctx, doc, pageNumber);
        fz_rect bounds = fz_bound_page(ctx, page);
        fz_matrix ctm = fz_scale(scaleFactor, scaleFactor);
        fz_irect bbox = fz_round_rect(fz_transform_rect(bounds, ctm));

        pix = fz_new_pixmap_with_bbox(ctx, fz_device_rgb(ctx), bbox, nullptr, 0);
        fz_clear_pixmap_with_value(ctx, pix, 0xFF);

        dev = fz_new_draw_device(ctx, fz_identity, pix);
        fz_run_page(ctx, page, dev, ctm, nullptr);
        fz_close_device(ctx, dev);

        outPath = cacheDirStr + "/page_" + std::to_string(pageNumber + 1) + ".png";
        fz_save_pixmap_as_png(ctx, pix, outPath.c_str());

    } fz_always(ctx) {
        if (dev) fz_drop_device(ctx, dev);
        if (pix) fz_drop_pixmap(ctx, pix);
        if (page) fz_drop_page(ctx, page);
    } fz_catch(ctx) {
        LOGI("Error rendering page %d", pageNumber);
        outPath = "";
    }

    fz_drop_document(ctx, doc);
    fz_drop_context(ctx);

    return env->NewStringUTF(outPath.c_str());
}

// PDF PAGE COUNT
extern "C"
JNIEXPORT jint JNICALL
Java_com_bluepdf_blue_1pdf_MainActivity_getPdfPageCountNative(JNIEnv *env, jobject /* this */,
                                                              jstring pdfPath_) {
    // Input validation
    if (!pdfPath_) {
        LOGI("Error: PDF path is null");
        return -1;
    }

    const char *pdfPath = env->GetStringUTFChars(pdfPath_, 0);
    if (!pdfPath) {
        LOGI("Error: Failed to get UTF chars from PDF path");
        return -1;
    }

    LOGI("Attempting to get page count for PDF: %s", pdfPath);

    // Create MuPDF context
    fz_context *ctx = fz_new_context(NULL, NULL, FZ_STORE_UNLIMITED);
    if (!ctx) {
        LOGI("Error: Failed to create MuPDF context");
        env->ReleaseStringUTFChars(pdfPath_, pdfPath);
        return -1;
    }

    LOGI("MuPDF context created successfully");

    jint pageCount = -1;
    fz_document *doc = NULL;

    fz_try(ctx) {
        LOGI("Registering document handlers...");
        fz_register_document_handlers(ctx);
        LOGI("Document handlers registered successfully");

        LOGI("Opening PDF document: %s", pdfPath);
        doc = fz_open_document(ctx, pdfPath);
        if (!doc) {
            LOGI("Error: Failed to open PDF document - document is null");
            fz_throw(ctx, FZ_ERROR_GENERIC, "Document is null after opening");
        }
        LOGI("PDF document opened successfully");

        LOGI("Counting pages...");
        pageCount = fz_count_pages(ctx, doc);
        LOGI("Page count retrieved successfully: %d pages", pageCount);

        // Validate page count
        if (pageCount <= 0) {
            LOGI("Warning: Invalid page count returned: %d", pageCount);
            pageCount = -1;
        }

    }
    fz_catch(ctx) {
        const char *error_msg = fz_caught_message(ctx);
        int error_code = fz_caught(ctx);
        LOGI("Error in MuPDF operation - Code: %d, Message: %s", error_code, error_msg ? error_msg : "Unknown error");
        
        // Log specific error types
        switch (error_code) {
            case FZ_ERROR_GENERIC:
                LOGI("Error type: Generic error");
                break;
            case FZ_ERROR_SYNTAX:
                LOGI("Error type: Syntax error in PDF");
                break;
            case FZ_ERROR_TRYLATER:
                LOGI("Error type: Try later (resource busy)");
                break;
            case FZ_ERROR_ABORT:
                LOGI("Error type: Operation aborted");
                break;
            default:
                LOGI("Error type: Unknown error code %d", error_code);
                break;
        }
        
        pageCount = -1;
    }

    // Cleanup
    if (doc) {
        LOGI("Dropping document...");
        fz_drop_document(ctx, doc);
        LOGI("Document dropped successfully");
    }

    LOGI("Dropping MuPDF context...");
    fz_drop_context(ctx);
    LOGI("MuPDF context dropped successfully");

    // Release JNI string
    env->ReleaseStringUTFChars(pdfPath_, pdfPath);
    LOGI("JNI string resources released");

    LOGI("Final result - Page count: %d", pageCount);
    return pageCount;
}