// PDF operations built on MuPDF, free of JNI so they can be exercised by
// the on-device test binary in cpp/tests.
#pragma once

#include <functional>
#include <string>
#include <vector>

namespace bluepdf {

// Error codes shared with the Kotlin and Dart layers.
namespace codes {
inline constexpr const char* kPasswordRequired = "PASSWORD_REQUIRED";
inline constexpr const char* kWrongPassword = "WRONG_PASSWORD";
inline constexpr const char* kAlreadyEncrypted = "ALREADY_ENCRYPTED";
inline constexpr const char* kOpenFailed = "OPEN_FAILED";
inline constexpr const char* kProcessFailed = "PROCESS_FAILED";
inline constexpr const char* kWriteFailed = "WRITE_FAILED";
inline constexpr const char* kNoPages = "NO_PAGES";
inline constexpr const char* kInvalidArgument = "INVALID_ARGUMENT";
inline constexpr const char* kOutOfMemory = "OUT_OF_MEMORY";
inline constexpr const char* kCancelled = "CANCELLED";
}  // namespace codes

struct Status {
    std::string code;  // Empty on success.
    std::string message;

    bool ok() const { return code.empty(); }
    static Status Ok() { return {}; }
    static Status Error(const char* code, std::string message) { return {code, std::move(message)}; }
};

enum class PageMode {
    kA4,   // A4 page in the image's orientation, image centred.
    kFit,  // Page matches the image's aspect ratio.
};

struct PdfInfo {
    int page_count = 0;
    bool encrypted = false;  // Needs a user password to open.
};

// Values are shared with the Kotlin and Dart layers.
enum class Stage {
    kProcessing = 0,  // Working through pages or images: `done` of `total`.
    kWriting = 1,     // Writing the output file; `done`/`total` are 0.
};

struct Progress {
    Stage stage = Stage::kProcessing;
    int done = 0;
    int total = 0;
    float fraction = 0;  // Of the whole operation, 0 to 1, never decreasing.
};

// Called on the operation's thread, at most once per item and per 1% of the
// output written. Return false to cancel: the operation then fails with
// codes::kCancelled and leaves no output file behind.
using ProgressFn = std::function<bool(const Progress&)>;

// Opens a PDF, authenticating with `password` when it is protected.
Status InspectPdf(const std::string& path, const std::string& password, PdfInfo* info);

// One page per image. EXIF orientation is honoured, then each image is turned
// clockwise by `rotations[i]` degrees (multiples of 90; may be empty).
// Indices of unreadable images are reported in `skipped`.
Status ImagesToPdf(const std::vector<std::string>& images, const std::vector<int>& rotations,
                   PageMode mode, const std::string& out_path, std::vector<int>* skipped,
                   const ProgressFn& progress = {});

// Copies every page of each input (lossless: links, bookmarks and forms survive).
Status MergePdfs(const std::vector<std::string>& paths, const std::vector<std::string>& passwords,
                 const std::string& out_path, const ProgressFn& progress = {});

// Writes the 0-based `pages` of a document in the given order. `rotations`
// (clockwise degrees, same length as `pages` or empty) are added to each page.
// The source's encryption, if any, is kept.
Status ExtractPages(const std::string& path, const std::string& password,
                    const std::vector<int>& pages, const std::vector<int>& rotations,
                    const std::string& out_path, const ProgressFn& progress = {});

// Protects an unencrypted PDF with AES-256.
Status EncryptPdf(const std::string& path, const std::string& new_password,
                  const std::string& out_path, const ProgressFn& progress = {});

// Renders a 0-based page to a JPEG that is `target_width` pixels wide.
// The most recently rendered document stays open to make thumbnail strips fast.
Status RenderPage(const std::string& path, const std::string& password, int page,
                  int target_width, const std::string& out_path);

}  // namespace bluepdf
