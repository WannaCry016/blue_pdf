#include "pdf_ops.h"

#include <sys/stat.h>

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <unordered_map>
#include <utility>

extern "C" {
#include "mupdf/fitz.h"
#include "mupdf/pdf.h"
}

// MuPDF reports errors with setjmp/longjmp. Inside fz_try blocks only plain C
// values are touched, and every local that is assigned inside a try and read
// in fz_always/fz_catch is marked with fz_var.

namespace bluepdf {
namespace {

constexpr float kA4Short = 595.0f;
constexpr float kA4Long = 842.0f;
constexpr int kMaxRenderSide = 2400;
constexpr size_t kRenderStoreBytes = 64 << 20;
constexpr int kJpegQuality = 85;

class Context {
public:
    Context() : ctx_(fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT)) {
        if (!ctx_) return;
        fz_try(ctx_) fz_register_document_handlers(ctx_);
        fz_catch(ctx_) {
            fz_drop_context(ctx_);
            ctx_ = nullptr;
        }
    }
    ~Context() { fz_drop_context(ctx_); }
    Context(const Context&) = delete;
    Context& operator=(const Context&) = delete;

    fz_context* get() const { return ctx_; }

private:
    fz_context* ctx_;
};

Status NoContext() { return Status::Error(codes::kOutOfMemory, "Could not start the PDF engine"); }

// Must be called from inside fz_catch.
Status CaughtError(fz_context* ctx, const char* fallback_code) {
    int code = FZ_ERROR_NONE;
    const char* raw = fz_convert_error(ctx, &code);
    std::string message = raw ? raw : "Unknown error";
    if (code == FZ_ERROR_ARGUMENT) return Status::Error(codes::kInvalidArgument, message);
    if (code == FZ_ERROR_SYSTEM && message.find("malloc") != std::string::npos) {
        return Status::Error(codes::kOutOfMemory, message);
    }
    return Status::Error(fallback_code, message);
}

int NormalizeRotation(int degrees) {
    int r = ((degrees % 360) + 360) % 360;
    return r - r % 90;
}

// Clockwise rotation of the unit square in MuPDF's y-down image space.
fz_matrix UnitRotation(int degrees) {
    switch (degrees) {
        case 90: return fz_make_matrix(0, 1, -1, 0, 1, 0);
        case 180: return fz_make_matrix(-1, 0, 0, -1, 1, 1);
        case 270: return fz_make_matrix(0, -1, 1, 0, 0, 1);
        default: return fz_identity;
    }
}

// Page box and unit-square placement for an upright image of w x h pixels.
void LayoutImage(PageMode mode, float w, float h, fz_rect* page, fz_matrix* place) {
    if (mode == PageMode::kA4) {
        const bool landscape = w > h;
        const float pw = landscape ? kA4Long : kA4Short;
        const float ph = landscape ? kA4Short : kA4Long;
        const float s = std::min(pw / w, ph / h);
        const float dw = w * s, dh = h * s;
        *page = fz_make_rect(0, 0, pw, ph);
        *place = fz_concat(fz_scale(dw, dh), fz_translate((pw - dw) / 2, (ph - dh) / 2));
    } else {
        const float s = kA4Long / std::max(w, h);
        *page = fz_make_rect(0, 0, w * s, h * s);
        *place = fz_scale(w * s, h * s);
    }
}

pdf_write_options OutputOptions() {
    pdf_write_options opts = pdf_default_write_options;
    opts.do_compress = 1;
    opts.do_compress_images = 1;
    opts.do_compress_fonts = 1;
    opts.do_garbage = 1;
    opts.do_use_objstms = 1;
    return opts;
}

Status SaveDocument(fz_context* ctx, pdf_document* doc, const std::string& out_path,
                    const pdf_write_options& opts) {
    fz_try(ctx) pdf_save_document(ctx, doc, out_path.c_str(), &opts);
    fz_catch(ctx) {
        std::remove(out_path.c_str());
        return CaughtError(ctx, codes::kWriteFailed);
    }
    return Status::Ok();
}

Status OpenPdf(fz_context* ctx, const std::string& path, const std::string& password,
               pdf_document** out) {
    pdf_document* doc = nullptr;
    int needs_password = 0;
    int authenticated = 0;
    fz_var(doc);
    fz_var(needs_password);
    fz_var(authenticated);
    fz_try(ctx) {
        doc = pdf_open_document(ctx, path.c_str());
        needs_password = pdf_needs_password(ctx, doc);
        if (needs_password && !password.empty()) {
            authenticated = pdf_authenticate_password(ctx, doc, password.c_str());
        }
    }
    fz_catch(ctx) {
        pdf_drop_document(ctx, doc);
        return CaughtError(ctx, codes::kOpenFailed);
    }
    if (needs_password && !authenticated) {
        pdf_drop_document(ctx, doc);
        return password.empty()
                   ? Status::Error(codes::kPasswordRequired, "The PDF is password-protected")
                   : Status::Error(codes::kWrongPassword, "The password is incorrect");
    }
    *out = doc;
    return Status::Ok();
}

long long FileMtimeNs(const std::string& path) {
    struct stat st {};
    if (stat(path.c_str(), &st) != 0) return 0;
    return static_cast<long long>(st.st_mtim.tv_sec) * 1000000000LL + st.st_mtim.tv_nsec;
}

struct RenderCache {
    std::mutex mutex;
    fz_context* ctx = nullptr;
    pdf_document* doc = nullptr;
    std::string path;
    std::string password;
    long long mtime = 0;
};

RenderCache& GetRenderCache() {
    static RenderCache cache;
    return cache;
}

}  // namespace

Status InspectPdf(const std::string& path, const std::string& password, PdfInfo* info) {
    Context context;
    fz_context* ctx = context.get();
    if (!ctx) return NoContext();

    pdf_document* doc = nullptr;
    Status st = OpenPdf(ctx, path, password, &doc);
    if (!st.ok()) return st;

    int pages = 0;
    int encrypted = 0;
    fz_var(pages);
    fz_var(encrypted);
    fz_try(ctx) {
        pages = pdf_count_pages(ctx, doc);
        encrypted = pdf_needs_password(ctx, doc);
    }
    fz_always(ctx) pdf_drop_document(ctx, doc);
    fz_catch(ctx) return CaughtError(ctx, codes::kOpenFailed);

    if (pages <= 0) return Status::Error(codes::kNoPages, "The PDF has no pages");
    info->page_count = pages;
    info->encrypted = encrypted != 0;
    return Status::Ok();
}

Status ImagesToPdf(const std::vector<std::string>& images, const std::vector<int>& rotations,
                   PageMode mode, const std::string& out_path, std::vector<int>* skipped) {
    if (images.empty()) return Status::Error(codes::kInvalidArgument, "No images given");

    Context context;
    fz_context* ctx = context.get();
    if (!ctx) return NoContext();

    fz_document_writer* writer = nullptr;
    fz_try(ctx) writer = fz_new_document_writer(ctx, out_path.c_str(), "pdf", "compress,objstms");
    fz_catch(ctx) return CaughtError(ctx, codes::kWriteFailed);

    int written = 0;
    fz_var(written);
    for (size_t i = 0; i < images.size(); ++i) {
        const int rotation = NormalizeRotation(i < rotations.size() ? rotations[i] : 0);
        fz_image* image = nullptr;
        int in_page = 0;
        fz_var(image);
        fz_var(in_page);
        fz_try(ctx) {
            image = fz_new_image_from_file(ctx, images[i].c_str());

            const uint8_t orientation = fz_image_orientation(ctx, image);
            float w = static_cast<float>(image->w);
            float h = static_cast<float>(image->h);
            if (!(orientation == 0 || (orientation & 1) == 1)) std::swap(w, h);
            if (rotation == 90 || rotation == 270) std::swap(w, h);

            fz_matrix unit = fz_concat(fz_image_orientation_matrix(ctx, image), UnitRotation(rotation));
            fz_rect page;
            fz_matrix place;
            LayoutImage(mode, w, h, &page, &place);

            fz_device* dev = fz_begin_page(ctx, writer, page);
            in_page = 1;
            fz_fill_image(ctx, dev, image, fz_concat(unit, place), 1.0f, fz_default_color_params);
            in_page = 0;
            fz_end_page(ctx, writer);
            ++written;
        }
        fz_always(ctx) fz_drop_image(ctx, image);
        fz_catch(ctx) {
            fz_report_error(ctx);
            if (in_page) {
                fz_try(ctx) fz_end_page(ctx, writer);
                fz_catch(ctx) fz_report_error(ctx);
            }
            if (skipped) skipped->push_back(static_cast<int>(i));
        }
    }

    if (written == 0) {
        fz_try(ctx) fz_drop_document_writer(ctx, writer);
        fz_catch(ctx) fz_report_error(ctx);
        std::remove(out_path.c_str());
        return Status::Error(codes::kNoPages, "None of the images could be read");
    }

    fz_try(ctx) fz_close_document_writer(ctx, writer);
    fz_always(ctx) fz_drop_document_writer(ctx, writer);
    fz_catch(ctx) {
        std::remove(out_path.c_str());
        return CaughtError(ctx, codes::kWriteFailed);
    }
    return Status::Ok();
}

namespace {

// Pages of one source document as they land in the merged document.
struct GraftedPages {
    std::unordered_map<int, int> index_by_src_num;  // Source page object number -> page index.
    std::vector<pdf_obj*> dst;                      // Borrowed from the merged document.
};

bool IsName(fz_context* ctx, pdf_obj* obj, pdf_obj* name) { return pdf_name_eq(ctx, obj, name) != 0; }

// Re-points an internal destination at the merged page. Returns null (and the
// caller drops the link) when the target is not a page of the same document.
pdf_obj* RemapDestination(fz_context* ctx, pdf_document* src, pdf_document* dst, pdf_graft_map* map,
                          const GraftedPages& pages, pdf_obj* dest) {
    if (pdf_is_name(ctx, dest) || pdf_is_string(ctx, dest)) dest = pdf_lookup_dest(ctx, src, dest);
    if (pdf_is_dict(ctx, dest)) dest = pdf_dict_get(ctx, dest, PDF_NAME(D));
    const int len = pdf_array_len(ctx, dest);
    if (len == 0) return nullptr;
    pdf_obj* target = pdf_array_get(ctx, dest, 0);
    if (!pdf_is_indirect(ctx, target)) return nullptr;
    const auto found = pages.index_by_src_num.find(pdf_to_num(ctx, target));
    if (found == pages.index_by_src_num.end()) return nullptr;

    pdf_obj* out = pdf_new_array(ctx, dst, len);
    pdf_array_push(ctx, out, pages.dst[found->second]);
    for (int i = 1; i < len; ++i) {
        pdf_array_push_drop(ctx, out, pdf_graft_mapped_object(ctx, map, pdf_array_get(ctx, dest, i)));
    }
    return out;
}

// pdf_graft_mapped_page copies page content but not /Annots, so links,
// highlights and comments are copied here. Form fields are left out: their
// names live in each document's AcroForm and would clash when combined.
// Keys that point at other pages or annotations (/P, /Parent, /Popup, /IRT,
// action chains) are not grafted, as that would pull in copies of whole page trees.
void CopyAnnotations(fz_context* ctx, pdf_document* src, pdf_document* dst, pdf_graft_map* map,
                     const GraftedPages& pages, pdf_obj* src_page, pdf_obj* dst_page) {
    pdf_obj* annots = pdf_dict_get(ctx, src_page, PDF_NAME(Annots));
    const int count = pdf_array_len(ctx, annots);
    if (count == 0) return;
    pdf_obj* dst_annots = pdf_dict_put_array(ctx, dst_page, PDF_NAME(Annots), count);

    for (int i = 0; i < count; ++i) {
        pdf_obj* annot = pdf_array_get(ctx, annots, i);
        pdf_obj* subtype = pdf_dict_get(ctx, annot, PDF_NAME(Subtype));
        if (!pdf_is_dict(ctx, annot) || IsName(ctx, subtype, PDF_NAME(Widget)) ||
            IsName(ctx, subtype, PDF_NAME(Popup))) {
            continue;
        }

        const int keys = pdf_dict_len(ctx, annot);
        pdf_obj* copy = pdf_new_dict(ctx, dst, keys);
        bool keep = true;
        for (int k = 0; k < keys && keep; ++k) {
            pdf_obj* key = pdf_dict_get_key(ctx, annot, k);
            pdf_obj* val = pdf_dict_get_val(ctx, annot, k);
            if (IsName(ctx, key, PDF_NAME(P)) || IsName(ctx, key, PDF_NAME(Parent)) ||
                IsName(ctx, key, PDF_NAME(Popup)) || IsName(ctx, key, PDF_NAME(IRT)) ||
                IsName(ctx, key, PDF_NAME(StructParent))) {
                continue;
            }
            pdf_obj* action_type = pdf_dict_get(ctx, val, PDF_NAME(S));
            if (IsName(ctx, key, PDF_NAME(Dest)) ||
                (IsName(ctx, key, PDF_NAME(A)) && IsName(ctx, action_type, PDF_NAME(GoTo)))) {
                pdf_obj* dest = IsName(ctx, key, PDF_NAME(Dest)) ? val : pdf_dict_get(ctx, val, PDF_NAME(D));
                pdf_obj* remapped = RemapDestination(ctx, src, dst, map, pages, dest);
                if (!remapped) {
                    keep = false;
                } else if (IsName(ctx, key, PDF_NAME(Dest))) {
                    pdf_dict_put_drop(ctx, copy, key, remapped);
                } else {
                    pdf_obj* action = pdf_dict_put_dict(ctx, copy, key, 2);
                    pdf_dict_put(ctx, action, PDF_NAME(S), PDF_NAME(GoTo));
                    pdf_dict_put_drop(ctx, action, PDF_NAME(D), remapped);
                }
            } else if (IsName(ctx, key, PDF_NAME(A))) {
                pdf_obj* action = pdf_dict_put_dict(ctx, copy, key, pdf_dict_len(ctx, val));
                for (int a = 0; a < pdf_dict_len(ctx, val); ++a) {
                    pdf_obj* action_key = pdf_dict_get_key(ctx, val, a);
                    if (IsName(ctx, action_key, PDF_NAME(Next))) continue;
                    pdf_dict_put_drop(ctx, action, action_key,
                                      pdf_graft_mapped_object(ctx, map, pdf_dict_get_val(ctx, val, a)));
                }
            } else {
                pdf_dict_put_drop(ctx, copy, key, pdf_graft_mapped_object(ctx, map, val));
            }
        }
        if (keep) {
            pdf_dict_put(ctx, copy, PDF_NAME(P), dst_page);
            pdf_array_push_drop(ctx, dst_annots, pdf_add_object(ctx, dst, copy));
        }
        pdf_drop_obj(ctx, copy);
    }
    if (pdf_array_len(ctx, dst_annots) == 0) pdf_dict_del(ctx, dst_page, PDF_NAME(Annots));
}

}  // namespace

Status MergePdfs(const std::vector<std::string>& paths, const std::vector<std::string>& passwords,
                 const std::string& out_path) {
    if (paths.empty()) return Status::Error(codes::kInvalidArgument, "No PDFs given");

    Context context;
    fz_context* ctx = context.get();
    if (!ctx) return NoContext();

    pdf_document* merged = nullptr;
    fz_try(ctx) merged = pdf_create_document(ctx);
    fz_catch(ctx) return CaughtError(ctx, codes::kWriteFailed);

    Status st;
    for (size_t i = 0; i < paths.size() && st.ok(); ++i) {
        pdf_document* src = nullptr;
        st = OpenPdf(ctx, paths[i], i < passwords.size() ? passwords[i] : std::string(), &src);
        if (!st.ok()) {
            st.message = "File " + std::to_string(i + 1) + ": " + st.message;
            break;
        }

        GraftedPages pages;
        pdf_graft_map* map = nullptr;
        fz_var(map);
        fz_try(ctx) {
            map = pdf_new_graft_map(ctx, merged);
            const int base = pdf_count_pages(ctx, merged);
            const int count = pdf_count_pages(ctx, src);
            pages.dst.reserve(count);
            for (int p = 0; p < count; ++p) {
                pdf_graft_mapped_page(ctx, map, -1, src, p);
                pages.index_by_src_num[pdf_to_num(ctx, pdf_lookup_page_obj(ctx, src, p))] = p;
                pages.dst.push_back(pdf_lookup_page_obj(ctx, merged, base + p));
            }
            // After all pages are in place, so links can point forwards.
            for (int p = 0; p < count; ++p) {
                CopyAnnotations(ctx, src, merged, map, pages, pdf_lookup_page_obj(ctx, src, p), pages.dst[p]);
            }
        }
        fz_always(ctx) {
            pdf_drop_graft_map(ctx, map);
            pdf_drop_document(ctx, src);
        }
        fz_catch(ctx) st = CaughtError(ctx, codes::kProcessFailed);
    }

    if (st.ok()) {
        pdf_write_options opts = OutputOptions();
        st = SaveDocument(ctx, merged, out_path, opts);
    }
    pdf_drop_document(ctx, merged);
    return st;
}

Status ExtractPages(const std::string& path, const std::string& password,
                    const std::vector<int>& pages, const std::vector<int>& rotations,
                    const std::string& out_path) {
    if (pages.empty()) return Status::Error(codes::kInvalidArgument, "No pages selected");
    if (!rotations.empty() && rotations.size() != pages.size()) {
        return Status::Error(codes::kInvalidArgument, "Rotations do not match pages");
    }

    Context context;
    fz_context* ctx = context.get();
    if (!ctx) return NoContext();

    pdf_document* doc = nullptr;
    Status st = OpenPdf(ctx, path, password, &doc);
    if (!st.ok()) return st;

    fz_try(ctx) {
        const int count = pdf_count_pages(ctx, doc);
        for (size_t i = 0; i < pages.size(); ++i) {
            if (pages[i] < 0 || pages[i] >= count) {
                fz_throw(ctx, FZ_ERROR_ARGUMENT, "Page %d is out of range (1-%d)", pages[i] + 1, count);
            }
        }
        // Structure trees are dropped: they can carry text from removed pages.
        pdf_rearrange_pages(ctx, doc, static_cast<int>(pages.size()), pages.data(),
                            PDF_CLEAN_STRUCTURE_DROP);
        for (size_t i = 0; i < rotations.size(); ++i) {
            const int rotation = NormalizeRotation(rotations[i]);
            if (rotation == 0) continue;
            pdf_obj* page = pdf_lookup_page_obj(ctx, doc, static_cast<int>(i));
            const int current = pdf_to_int(ctx, pdf_dict_get_inheritable(ctx, page, PDF_NAME(Rotate)));
            pdf_dict_put_int(ctx, page, PDF_NAME(Rotate), NormalizeRotation(current + rotation));
        }
    }
    fz_catch(ctx) st = CaughtError(ctx, codes::kProcessFailed);

    if (st.ok()) {
        pdf_write_options opts = OutputOptions();
        st = SaveDocument(ctx, doc, out_path, opts);
    }
    pdf_drop_document(ctx, doc);
    return st;
}

Status EncryptPdf(const std::string& path, const std::string& new_password,
                  const std::string& out_path) {
    if (new_password.empty()) return Status::Error(codes::kInvalidArgument, "Password is empty");

    Context context;
    fz_context* ctx = context.get();
    if (!ctx) return NoContext();

    pdf_document* doc = nullptr;
    Status st = OpenPdf(ctx, path, std::string(), &doc);
    if (st.code == codes::kPasswordRequired) {
        return Status::Error(codes::kAlreadyEncrypted, "The PDF is already password-protected");
    }
    if (!st.ok()) return st;

    pdf_write_options opts = OutputOptions();
    if (new_password.size() >= sizeof(opts.upwd_utf8)) {
        pdf_drop_document(ctx, doc);
        return Status::Error(codes::kInvalidArgument, "Password is too long");
    }
    opts.do_encrypt = PDF_ENCRYPT_AES_256;
    opts.permissions = PDF_PERM_PRINT | PDF_PERM_MODIFY | PDF_PERM_COPY | PDF_PERM_ANNOTATE |
                       PDF_PERM_FORM | PDF_PERM_ACCESSIBILITY | PDF_PERM_ASSEMBLE |
                       PDF_PERM_PRINT_HQ;
    std::strncpy(opts.upwd_utf8, new_password.c_str(), sizeof(opts.upwd_utf8) - 1);
    std::strncpy(opts.opwd_utf8, new_password.c_str(), sizeof(opts.opwd_utf8) - 1);

    st = SaveDocument(ctx, doc, out_path, opts);
    pdf_drop_document(ctx, doc);
    return st;
}

Status RenderPage(const std::string& path, const std::string& password, int page,
                  int target_width, const std::string& out_path) {
    if (page < 0 || target_width <= 0) {
        return Status::Error(codes::kInvalidArgument, "Invalid page or width");
    }
    const float width = static_cast<float>(std::min(target_width, kMaxRenderSide));

    RenderCache& cache = GetRenderCache();
    std::lock_guard<std::mutex> lock(cache.mutex);

    if (!cache.ctx) {
        fz_context* ctx = fz_new_context(nullptr, nullptr, kRenderStoreBytes);
        if (!ctx) return NoContext();
        int failed = 0;
        fz_try(ctx) fz_register_document_handlers(ctx);
        fz_catch(ctx) failed = 1;
        if (failed) {
            fz_drop_context(ctx);
            return NoContext();
        }
        cache.ctx = ctx;
    }
    fz_context* ctx = cache.ctx;

    const long long mtime = FileMtimeNs(path);
    if (!cache.doc || cache.path != path || cache.mtime != mtime || cache.password != password) {
        pdf_drop_document(ctx, cache.doc);
        cache.doc = nullptr;
        pdf_document* doc = nullptr;
        Status st = OpenPdf(ctx, path, password, &doc);
        if (!st.ok()) return st;
        cache.doc = doc;
        cache.path = path;
        cache.password = password;
        cache.mtime = mtime;
    }
    fz_document* doc = &cache.doc->super;

    fz_page* loaded = nullptr;
    fz_pixmap* pix = nullptr;
    fz_var(loaded);
    fz_var(pix);
    Status st;
    fz_try(ctx) {
        if (page >= fz_count_pages(ctx, doc)) {
            fz_throw(ctx, FZ_ERROR_ARGUMENT, "Page %d is out of range", page + 1);
        }
        loaded = fz_load_page(ctx, doc, page);
        const fz_rect bounds = fz_bound_page(ctx, loaded);
        const float page_w = bounds.x1 - bounds.x0;
        const float page_h = bounds.y1 - bounds.y0;
        if (page_w <= 0 || page_h <= 0) fz_throw(ctx, FZ_ERROR_FORMAT, "Page has no size");
        float scale = width / page_w;
        if (page_h * scale > kMaxRenderSide) scale = kMaxRenderSide / page_h;
        pix = fz_new_pixmap_from_page(ctx, loaded, fz_scale(scale, scale), fz_device_rgb(ctx), 0);
        fz_save_pixmap_as_jpeg(ctx, pix, out_path.c_str(), kJpegQuality);
    }
    fz_always(ctx) {
        fz_drop_pixmap(ctx, pix);
        fz_drop_page(ctx, loaded);
    }
    fz_catch(ctx) {
        std::remove(out_path.c_str());
        st = CaughtError(ctx, codes::kProcessFailed);
    }
    return st;
}

}  // namespace bluepdf
