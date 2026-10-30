// On-device tests for pdf_ops. Build and run with tool/native_test.ps1.
#include <sys/stat.h>

#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <functional>
#include <iterator>
#include <string>
#include <vector>

#include "../pdf_ops.h"

extern "C" {
#include "mupdf/fitz.h"
#include "mupdf/pdf.h"
}

using bluepdf::PageMode;
using bluepdf::PdfInfo;
using bluepdf::Status;

namespace {

int g_failures = 0;
int g_checks = 0;
std::string g_dir;

#define CHECK(cond)                                                              \
    do {                                                                         \
        ++g_checks;                                                              \
        if (!(cond)) {                                                           \
            ++g_failures;                                                        \
            std::printf("  FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);        \
        }                                                                        \
    } while (0)

#define CHECK_OK(status)                                                                    \
    do {                                                                                    \
        const Status s_ = (status);                                                         \
        ++g_checks;                                                                         \
        if (!s_.ok()) {                                                                     \
            ++g_failures;                                                                   \
            std::printf("  FAIL %s:%d: %s -> %s: %s\n", __FILE__, __LINE__, #status,        \
                        s_.code.c_str(), s_.message.c_str());                               \
        }                                                                                   \
    } while (0)

#define CHECK_CODE(status, expected)                                                        \
    do {                                                                                    \
        const Status s_ = (status);                                                         \
        ++g_checks;                                                                         \
        if (s_.code != (expected)) {                                                        \
            ++g_failures;                                                                   \
            std::printf("  FAIL %s:%d: %s -> '%s' (%s), expected '%s'\n", __FILE__,         \
                        __LINE__, #status, s_.code.c_str(), s_.message.c_str(), expected); \
        }                                                                                   \
    } while (0)

std::string P(const char* name) { return g_dir + "/" + name; }

bool Exists(const std::string& path) {
    struct stat st {};
    return stat(path.c_str(), &st) == 0 && st.st_size > 0;
}

struct Ctx {
    fz_context* ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    Ctx() { fz_register_document_handlers(ctx); }
    ~Ctx() { fz_drop_context(ctx); }
};

// Page i is (300 + 10i) x (400 + 10i) points so pages can be identified by size.
void MakeFixturePdf(const std::string& path, const char* user_password) {
    Ctx c;
    fz_context* ctx = c.ctx;
    pdf_document* doc = pdf_create_document(ctx);
    const char* content = "0 0 1 rg 10 10 50 50 re f";
    for (int i = 0; i < 5; ++i) {
        fz_buffer* buf = fz_new_buffer_from_copied_data(
            ctx, reinterpret_cast<const unsigned char*>(content), std::strlen(content));
        pdf_obj* resources = pdf_new_dict(ctx, doc, 1);
        pdf_obj* page = pdf_add_page(ctx, doc, fz_make_rect(0, 0, 300 + 10 * i, 400 + 10 * i), 0,
                                     resources, buf);
        if (i == 0) {
            pdf_obj* annots = pdf_dict_put_array(ctx, page, PDF_NAME(Annots), 1);
            pdf_obj* link = pdf_add_new_dict(ctx, doc, 4);
            pdf_dict_put(ctx, link, PDF_NAME(Type), PDF_NAME(Annot));
            pdf_dict_put(ctx, link, PDF_NAME(Subtype), PDF_NAME(Link));
            pdf_dict_put_rect(ctx, link, PDF_NAME(Rect), fz_make_rect(10, 10, 60, 60));
            pdf_obj* action = pdf_dict_put_dict(ctx, link, PDF_NAME(A), 2);
            pdf_dict_put(ctx, action, PDF_NAME(S), PDF_NAME(URI));
            pdf_dict_put_text_string(ctx, action, PDF_NAME(URI), "https://example.com");
            pdf_array_push(ctx, annots, link);
            pdf_drop_obj(ctx, link);
        }
        pdf_insert_page(ctx, doc, -1, page);
        pdf_drop_obj(ctx, page);
        pdf_drop_obj(ctx, resources);
        fz_drop_buffer(ctx, buf);
    }

    // Page 2 links to page 4 within the document.
    pdf_obj* annots = pdf_dict_put_array(ctx, pdf_lookup_page_obj(ctx, doc, 1), PDF_NAME(Annots), 1);
    pdf_obj* link = pdf_add_new_dict(ctx, doc, 4);
    pdf_dict_put(ctx, link, PDF_NAME(Type), PDF_NAME(Annot));
    pdf_dict_put(ctx, link, PDF_NAME(Subtype), PDF_NAME(Link));
    pdf_dict_put_rect(ctx, link, PDF_NAME(Rect), fz_make_rect(10, 10, 60, 60));
    pdf_obj* dest = pdf_dict_put_array(ctx, link, PDF_NAME(Dest), 2);
    pdf_array_push(ctx, dest, pdf_lookup_page_obj(ctx, doc, 3));
    pdf_array_push(ctx, dest, PDF_NAME(Fit));
    pdf_array_push(ctx, annots, link);
    pdf_drop_obj(ctx, link);

    pdf_write_options opts = pdf_default_write_options;
    if (user_password) {
        opts.do_encrypt = PDF_ENCRYPT_AES_256;
        std::strncpy(opts.upwd_utf8, user_password, sizeof(opts.upwd_utf8) - 1);
        std::strncpy(opts.opwd_utf8, "owner", sizeof(opts.opwd_utf8) - 1);
    }
    pdf_save_document(ctx, doc, path.c_str(), &opts);
    pdf_drop_document(ctx, doc);
}

// 40x20 JPEG: left half red, right half blue. With exif_orientation set, an
// Exif APP1 segment carrying that orientation is inserted after SOI.
void MakeJpeg(const std::string& path, int exif_orientation) {
    {
        Ctx c;
        fz_context* ctx = c.ctx;
        fz_pixmap* pix = fz_new_pixmap(ctx, fz_device_rgb(ctx), 40, 20, nullptr, 0);
        unsigned char* s = fz_pixmap_samples(ctx, pix);
        const int stride = static_cast<int>(fz_pixmap_stride(ctx, pix));
        for (int y = 0; y < 20; ++y) {
            for (int x = 0; x < 40; ++x) {
                unsigned char* px = s + y * stride + x * 3;
                px[0] = x < 20 ? 255 : 0;
                px[1] = 0;
                px[2] = x < 20 ? 0 : 255;
            }
        }
        fz_save_pixmap_as_jpeg(ctx, pix, path.c_str(), 95);
        fz_drop_pixmap(ctx, pix);
    }
    if (!exif_orientation) return;

    std::ifstream in(path, std::ios::binary);
    std::vector<unsigned char> data((std::istreambuf_iterator<char>(in)), {});
    in.close();
    const unsigned char app1[] = {
        0xFF, 0xE1, 0x00, 0x22, 'E', 'x', 'i', 'f', 0, 0,             // APP1, length 34
        'M', 'M', 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,                 // big-endian TIFF
        0x00, 0x01,                                                   // 1 IFD entry
        0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01,               // Orientation, SHORT
        0x00, static_cast<unsigned char>(exif_orientation), 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,                                       // no next IFD
    };
    data.insert(data.begin() + 2, std::begin(app1), std::end(app1));
    std::ofstream out(path, std::ios::binary | std::ios::trunc);
    out.write(reinterpret_cast<const char*>(data.data()), static_cast<std::streamsize>(data.size()));
}

struct PageFacts {
    float w = 0, h = 0;
    int links = 0;
    int link_target = -1;  // Page index an internal link on this page jumps to.
    bool red_on_top = false;  // Top band of the page is mostly red.
    bool red_on_left = false;
};

std::vector<PageFacts> ReadPages(const std::string& path, const char* password = nullptr) {
    std::vector<PageFacts> pages;
    Ctx c;
    fz_context* ctx = c.ctx;
    fz_document* doc = fz_open_document(ctx, path.c_str());
    if (password) fz_authenticate_password(ctx, doc, password);
    const int n = fz_count_pages(ctx, doc);
    for (int i = 0; i < n; ++i) {
        PageFacts f;
        fz_page* page = fz_load_page(ctx, doc, i);
        const fz_rect b = fz_bound_page(ctx, page);
        f.w = b.x1 - b.x0;
        f.h = b.y1 - b.y0;
        fz_link* links = fz_load_links(ctx, page);
        for (fz_link* l = links; l; l = l->next) {
            ++f.links;
            if (l->uri && l->uri[0] == '#') {
                f.link_target = fz_page_number_from_location(
                    ctx, doc, fz_resolve_link(ctx, doc, l->uri, nullptr, nullptr));
            }
        }
        fz_drop_link(ctx, links);

        fz_pixmap* pix = fz_new_pixmap_from_page(ctx, page, fz_identity, fz_device_rgb(ctx), 0);
        const int w = fz_pixmap_width(ctx, pix), h = fz_pixmap_height(ctx, pix);
        const int stride = static_cast<int>(fz_pixmap_stride(ctx, pix));
        const unsigned char* s = fz_pixmap_samples(ctx, pix);
        auto red_at = [&](int x, int y) {
            const unsigned char* px = s + y * stride + x * 3;
            return px[0] > 180 && px[2] < 90;
        };
        f.red_on_top = red_at(w / 2, h / 10) && !red_at(w / 2, h - h / 10);
        f.red_on_left = red_at(w / 10, h / 2) && !red_at(w - w / 10, h / 2);
        fz_drop_pixmap(ctx, pix);
        fz_drop_page(ctx, page);
        pages.push_back(f);
    }
    fz_drop_document(ctx, doc);
    return pages;
}

bool Near(float a, float b) { return std::fabs(a - b) < 0.5f; }

void TestInspect() {
    std::puts("InspectPdf");
    PdfInfo info;
    CHECK_OK(bluepdf::InspectPdf(P("plain.pdf"), "", &info));
    CHECK(info.page_count == 5 && !info.encrypted);

    CHECK_CODE(bluepdf::InspectPdf(P("locked.pdf"), "", &info), bluepdf::codes::kPasswordRequired);
    CHECK_CODE(bluepdf::InspectPdf(P("locked.pdf"), "nope", &info), bluepdf::codes::kWrongPassword);
    info = {};
    CHECK_OK(bluepdf::InspectPdf(P("locked.pdf"), "secret", &info));
    CHECK(info.page_count == 5 && info.encrypted);

    CHECK_CODE(bluepdf::InspectPdf(P("missing.pdf"), "", &info), bluepdf::codes::kOpenFailed);
    CHECK_CODE(bluepdf::InspectPdf(P("red-blue.jpg"), "", &info), bluepdf::codes::kOpenFailed);
}

void TestImagesToPdf() {
    std::puts("ImagesToPdf");
    std::vector<int> skipped;
    const std::string out = P("images.pdf");
    CHECK_OK(bluepdf::ImagesToPdf(
        {P("red-blue.jpg"), P("exif6.jpg"), P("red-blue.jpg"), P("not-an-image.jpg"), P("exif3.jpg")},
        {0, 0, 90, 0, 0}, PageMode::kFit, out, &skipped));
    CHECK(skipped.size() == 1 && skipped[0] == 3);

    const auto pages = ReadPages(out);
    CHECK(pages.size() == 4);
    if (pages.size() == 4) {
        CHECK(Near(pages[0].w, 842) && Near(pages[0].h, 421));  // Landscape image, Fit.
        CHECK(pages[0].red_on_left);
        CHECK(Near(pages[1].w, 421) && Near(pages[1].h, 842));  // Exif 6 shows portrait.
        CHECK(pages[1].red_on_top);
        CHECK(Near(pages[2].w, 421) && Near(pages[2].h, 842));  // Rotated 90 clockwise.
        CHECK(pages[2].red_on_top);
        CHECK(Near(pages[3].w, 842) && Near(pages[3].h, 421));  // Exif 3 is upside down.
        CHECK(!pages[3].red_on_left);
    }

    CHECK_OK(bluepdf::ImagesToPdf({P("red-blue.jpg"), P("exif6.jpg")}, {}, PageMode::kA4,
                                  P("images-a4.pdf"), &skipped));
    const auto a4 = ReadPages(P("images-a4.pdf"));
    CHECK(a4.size() == 2);
    if (a4.size() == 2) {
        CHECK(Near(a4[0].w, 842) && Near(a4[0].h, 595));
        CHECK(Near(a4[1].w, 595) && Near(a4[1].h, 842));
    }

    skipped.clear();
    CHECK_CODE(bluepdf::ImagesToPdf({P("not-an-image.jpg")}, {}, PageMode::kA4, P("none.pdf"), &skipped),
               bluepdf::codes::kNoPages);
    CHECK(!Exists(P("none.pdf")));
}

void TestExtractPages() {
    std::puts("ExtractPages");
    CHECK_OK(bluepdf::ExtractPages(P("plain.pdf"), "", {4, 0, 2}, {}, P("extract.pdf")));
    auto pages = ReadPages(P("extract.pdf"));
    CHECK(pages.size() == 3);
    if (pages.size() == 3) {
        CHECK(Near(pages[0].w, 340) && Near(pages[1].w, 300) && Near(pages[2].w, 320));
        CHECK(pages[1].links == 1);  // The link on the original first page survives.
    }

    CHECK_OK(bluepdf::ExtractPages(P("plain.pdf"), "", {1, 0}, {90, 270}, P("rotated.pdf")));
    pages = ReadPages(P("rotated.pdf"));
    CHECK(pages.size() == 2);
    if (pages.size() == 2) {
        CHECK(Near(pages[0].w, 410) && Near(pages[0].h, 310));
        CHECK(Near(pages[1].w, 400) && Near(pages[1].h, 300));
    }

    CHECK_OK(bluepdf::ExtractPages(P("locked.pdf"), "secret", {3}, {}, P("locked-part.pdf")));
    PdfInfo info;
    CHECK_CODE(bluepdf::InspectPdf(P("locked-part.pdf"), "", &info), bluepdf::codes::kPasswordRequired);
    CHECK_OK(bluepdf::InspectPdf(P("locked-part.pdf"), "secret", &info));
    CHECK(info.page_count == 1);

    CHECK_CODE(bluepdf::ExtractPages(P("plain.pdf"), "", {5}, {}, P("bad.pdf")),
               bluepdf::codes::kInvalidArgument);
    CHECK_CODE(bluepdf::ExtractPages(P("locked.pdf"), "", {0}, {}, P("bad.pdf")),
               bluepdf::codes::kPasswordRequired);
}

void TestMerge() {
    std::puts("MergePdfs");
    CHECK_OK(bluepdf::MergePdfs({P("plain.pdf"), P("locked.pdf")}, {"", "secret"}, P("merged.pdf")));
    const auto pages = ReadPages(P("merged.pdf"));
    CHECK(pages.size() == 10);
    if (pages.size() == 10) {
        CHECK(Near(pages[0].w, 300) && Near(pages[4].w, 340) && Near(pages[5].w, 300));
        CHECK(pages[0].links == 1 && pages[5].links == 1);
        // Internal links jump to the same page of their own document after merging.
        CHECK(pages[1].link_target == 3 && pages[6].link_target == 8);
    }
    PdfInfo info;
    CHECK_OK(bluepdf::InspectPdf(P("merged.pdf"), "", &info));  // Merged output is unprotected.

    CHECK_CODE(bluepdf::MergePdfs({P("plain.pdf"), P("locked.pdf")}, {}, P("bad.pdf")),
               bluepdf::codes::kPasswordRequired);
    CHECK_CODE(bluepdf::MergePdfs({P("missing.pdf")}, {}, P("bad.pdf")), bluepdf::codes::kOpenFailed);
}

void TestEncrypt() {
    std::puts("EncryptPdf");
    CHECK_OK(bluepdf::EncryptPdf(P("plain.pdf"), "pässword", P("encrypted.pdf")));
    PdfInfo info;
    CHECK_CODE(bluepdf::InspectPdf(P("encrypted.pdf"), "", &info), bluepdf::codes::kPasswordRequired);
    CHECK_OK(bluepdf::InspectPdf(P("encrypted.pdf"), "pässword", &info));
    CHECK(info.page_count == 5);
    const auto pages = ReadPages(P("encrypted.pdf"), "pässword");
    CHECK(pages.size() == 5 && pages[0].links == 1);

    CHECK_CODE(bluepdf::EncryptPdf(P("locked.pdf"), "x", P("bad.pdf")), bluepdf::codes::kAlreadyEncrypted);
    CHECK_CODE(bluepdf::EncryptPdf(P("plain.pdf"), "", P("bad.pdf")), bluepdf::codes::kInvalidArgument);
}

int JpegWidth(const std::string& path) {
    Ctx c;
    fz_image* image = fz_new_image_from_file(c.ctx, path.c_str());
    const int w = image->w;
    fz_drop_image(c.ctx, image);
    return w;
}

void TestRender() {
    std::puts("RenderPage");
    CHECK_OK(bluepdf::RenderPage(P("plain.pdf"), "", 0, 200, P("thumb0.jpg")));
    CHECK(Exists(P("thumb0.jpg")) && JpegWidth(P("thumb0.jpg")) == 200);
    CHECK_OK(bluepdf::RenderPage(P("plain.pdf"), "", 4, 340, P("thumb4.jpg")));
    CHECK(JpegWidth(P("thumb4.jpg")) == 340);
    CHECK_OK(bluepdf::RenderPage(P("locked.pdf"), "secret", 1, 150, P("thumb-locked.jpg")));
    CHECK_CODE(bluepdf::RenderPage(P("locked.pdf"), "", 1, 150, P("bad.jpg")),
               bluepdf::codes::kPasswordRequired);
    CHECK_CODE(bluepdf::RenderPage(P("plain.pdf"), "", 9, 150, P("bad.jpg")),
               bluepdf::codes::kInvalidArgument);
    CHECK(!Exists(P("bad.jpg")));
}

using bluepdf::Progress;
using bluepdf::Stage;

// Records progress events and cancels on the first one matching `cancel_if`.
struct Recorder {
    std::vector<Progress> events;
    std::function<bool(const Progress&)> cancel_if;

    bluepdf::ProgressFn Fn() {
        return [this](const Progress& p) {
            events.push_back(p);
            return !(cancel_if && cancel_if(p));
        };
    }

    bool Monotonic() const {
        for (size_t i = 1; i < events.size(); ++i) {
            if (events[i].fraction < events[i - 1].fraction) return false;
        }
        return true;
    }

    bool Finished() const { return !events.empty() && events.back().fraction == 1.0f; }

    bool Saw(Stage stage, int done = -1, int total = -1) const {
        for (const auto& e : events) {
            if (e.stage == stage && (done < 0 || e.done == done) && (total < 0 || e.total == total)) return true;
        }
        return false;
    }
};

void TestProgress() {
    std::puts("Progress");
    Recorder merge;
    CHECK_OK(bluepdf::MergePdfs({P("plain.pdf"), P("locked.pdf")}, {"", "secret"}, P("p-merged.pdf"),
                                merge.Fn()));
    CHECK(merge.Monotonic() && merge.Finished());
    CHECK(merge.Saw(Stage::kProcessing, 1, 10) && merge.Saw(Stage::kProcessing, 10, 10));
    CHECK(merge.Saw(Stage::kWriting));

    Recorder images;
    std::vector<int> skipped;
    CHECK_OK(bluepdf::ImagesToPdf({P("red-blue.jpg"), P("not-an-image.jpg"), P("exif6.jpg")}, {},
                                  PageMode::kA4, P("p-images.pdf"), &skipped, images.Fn()));
    CHECK(images.Monotonic() && images.Finished());
    CHECK(images.Saw(Stage::kProcessing, 2, 3) && images.Saw(Stage::kProcessing, 3, 3));

    Recorder reorder;
    CHECK_OK(bluepdf::ExtractPages(P("plain.pdf"), "", {4, 3, 2, 1, 0}, {}, P("p-reorder.pdf"), reorder.Fn()));
    CHECK(reorder.Monotonic() && reorder.Finished() && reorder.Saw(Stage::kWriting));

    Recorder encrypt;
    CHECK_OK(bluepdf::EncryptPdf(P("plain.pdf"), "pw", P("p-encrypted.pdf"), encrypt.Fn()));
    CHECK(encrypt.Finished() && !encrypt.Saw(Stage::kProcessing));

    // Cancelling stops the work and leaves no output behind, whatever the stage.
    Recorder merge_cancel;
    merge_cancel.cancel_if = [](const Progress& p) { return p.done == 3; };
    CHECK_CODE(bluepdf::MergePdfs({P("plain.pdf"), P("plain.pdf")}, {}, P("p-cancel1.pdf"), merge_cancel.Fn()),
               bluepdf::codes::kCancelled);
    CHECK(!Exists(P("p-cancel1.pdf")) && !merge_cancel.Saw(Stage::kProcessing, 4));

    Recorder write_cancel;
    write_cancel.cancel_if = [](const Progress& p) { return p.stage == Stage::kWriting; };
    CHECK_CODE(bluepdf::ExtractPages(P("plain.pdf"), "", {0, 1}, {}, P("p-cancel2.pdf"), write_cancel.Fn()),
               bluepdf::codes::kCancelled);
    CHECK(!Exists(P("p-cancel2.pdf")) && !write_cancel.Finished());

    Recorder image_cancel;
    image_cancel.cancel_if = [](const Progress&) { return true; };
    CHECK_CODE(bluepdf::ImagesToPdf({P("red-blue.jpg"), P("exif6.jpg")}, {}, PageMode::kFit, P("p-cancel3.pdf"),
                                    &skipped, image_cancel.Fn()),
               bluepdf::codes::kCancelled);
    CHECK(!Exists(P("p-cancel3.pdf")) && image_cancel.events.size() == 1);
}

}  // namespace

int main(int argc, char** argv) {
    g_dir = argc > 1 ? argv[1] : ".";
    MakeFixturePdf(P("plain.pdf"), nullptr);
    MakeFixturePdf(P("locked.pdf"), "secret");
    MakeJpeg(P("red-blue.jpg"), 0);
    MakeJpeg(P("exif6.jpg"), 6);
    MakeJpeg(P("exif3.jpg"), 3);
    std::ofstream(P("not-an-image.jpg")) << "this is not an image";

    TestInspect();
    TestImagesToPdf();
    TestExtractPages();
    TestMerge();
    TestEncrypt();
    TestRender();
    TestProgress();

    std::printf("%d/%d checks passed\n", g_checks - g_failures, g_checks);
    return g_failures == 0 ? 0 : 1;
}
