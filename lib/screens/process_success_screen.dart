import 'dart:io';
import 'package:flutter/material.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:share_plus/share_plus.dart';
import 'about_page.dart';
import 'home_screen.dart' show kDarkAccent, kDarkBg, kDarkBorder, kDarkCard, kDarkPrimary, kDarkSecondaryText, kDarkTeal;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../components/brand_title.dart';
import '../components/save_pdf.dart' show SavedPdf;
import '../utils/cache_cleaner.dart';
import '../pdf/pdf_engine.dart';
import '../services/review_prompt.dart';
import '../utils/saved_location.dart';

class ProcessSuccessScreen extends ConsumerStatefulWidget {
  final SavedPdf saved;

  const ProcessSuccessScreen({super.key, required this.saved});

  @override
  ConsumerState<ProcessSuccessScreen> createState() => _ProcessSuccessScreenState();
}

class _FileDetails {
  const _FileDetails({required this.name, this.size, this.folder});
  final String name;
  final String? size;
  final String? folder;
}

class _ProcessSuccessScreenState extends ConsumerState<ProcessSuccessScreen> with SingleTickerProviderStateMixin {
  late final Future<_FileDetails> _details = _loadDetails();

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mergePdfFilesProvider.notifier).clear();
      ref.read(imageToPdfFilesProvider.notifier).clear();
      ref.read(encryptPdfFilesProvider.notifier).clear();
      ref.read(splitPdfFilesProvider.notifier).clear();
      ref.read(reorderPdfFilesProvider.notifier).clear();
    });
    ReviewPrompt.instance
        .onSuccessfulSave(stillVisible: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false))
        .ignore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isAnimating || _entrance.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  /// The picker lets the user rename the file and Downloads saves clashes as
  /// "name (1).pdf", so ask the provider for the real name first.
  Future<_FileDetails> _loadDetails() async {
    final saved = widget.saved;
    SavedDocument document = const SavedDocument();
    try {
      document = await PdfEngine.describeSaved(saved.location);
    } catch (e) {
      debugPrint('Could not describe saved file: $e');
    }
    int? size = document.size;
    if (size == null) {
      try {
        size = await File(saved.localPath).length();
      } catch (_) {}
    }
    return _FileDetails(
      name: document.name ?? saved.fileName,
      size: size == null ? null : formatFileSize(size),
      folder: saved.folder ?? savedFolder(saved.location),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    // The job is done and saved, so its inputs, result and thumbnails can go.
    clearCache(before: DateTime.now()).ignore();
    super.dispose();
  }

  Future<void> _open() async {
    final messenger = ScaffoldMessenger.of(context);
    final file = File(widget.saved.localPath);
    if (!await file.exists()) {
      messenger.showSnackBar(const SnackBar(content: Text("The preview copy is no longer available.")));
      return;
    }
    final result = await OpenFilex.open(file.path, type: "application/pdf");
    if (result.type != ResultType.done) {
      debugPrint('Could not open file: ${result.message}');
      messenger.showSnackBar(const SnackBar(content: Text("No app is available to open PDFs.")));
    }
  }

  Future<void> _share() async {
    final file = File(widget.saved.localPath);
    if (!await file.exists()) return;
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]));
    } catch (e) {
      debugPrint('Share failed: $e');
    }
  }

  /// Fades and lifts [child] in during the [start]–[end] part of the entrance.
  Widget _reveal(double start, double end, Widget child) {
    final animation = CurvedAnimation(parent: _entrance, curve: Interval(start, end, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTab = MediaQuery.sizeOf(context).shortestSide >= 600;
    final bgColor = isDark ? kDarkBg : const Color(0xFFECEFF1);
    final cardColor = isDark ? kDarkCard : Colors.white;
    final borderColor = isDark ? kDarkBorder : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? kDarkSecondaryText : Colors.grey.shade600;
    final accent = isDark ? kDarkAccent : const Color(0xFF1976D2);
    final gradientColors = isDark ? [kDarkPrimary, kDarkAccent, kDarkTeal] : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];
    final gradient = LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: isTab ? 70 : 50,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: gradient)),
        automaticallyImplyLeading: false,
        title: isTab ? const BrandTitle(logoSize: 40, fontSize: 28) : const BrandTitle(),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "About Developer",
            icon: Icon(Icons.info_outline, color: Colors.white, size: isTab ? 30 : 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isTab ? 48 : 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  _SuccessBadge(animation: _entrance, gradient: gradient, glow: accent, size: isTab ? 112 : 92),
                  SizedBox(height: isTab ? 32 : 26),
                  _reveal(
                    0.3,
                    0.8,
                    Column(
                      children: [
                        Text(
                          'PDF saved',
                          style: TextStyle(fontSize: isTab ? 30 : 24, fontWeight: FontWeight.w700, color: textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your file is ready to open or share.',
                          style: TextStyle(fontSize: isTab ? 17 : 15, color: secondaryTextColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isTab ? 32 : 28),
                  _reveal(
                    0.4,
                    0.9,
                    FutureBuilder<_FileDetails>(
                      future: _details,
                      builder: (context, snapshot) => _FileCard(
                        details: snapshot.data ?? _FileDetails(name: widget.saved.fileName),
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  SizedBox(height: isTab ? 32 : 24),
                  _reveal(
                    0.5,
                    1,
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _GradientButton(
                                gradient: gradient,
                                glow: accent,
                                icon: Icons.open_in_new_rounded,
                                label: 'Open',
                                onPressed: _open,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _share,
                                icon: const Icon(Icons.share_rounded, size: 20),
                                label: const Text('Share'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accent,
                                  backgroundColor: accent.withValues(alpha: isDark ? 0.12 : 0.06),
                                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                                  minimumSize: const Size.fromHeight(_buttonHeight),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                          icon: const Icon(Icons.home_rounded, size: 20),
                          label: const Text('Back to home'),
                          style: TextButton.styleFrom(
                            foregroundColor: secondaryTextColor,
                            minimumSize: const Size.fromHeight(_buttonHeight),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _buttonHeight = 52.0;
const _buttonRadius = 14.0;

/// A check in a gradient disc that pops in, with a soft halo that spreads behind it.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({required this.animation, required this.gradient, required this.glow, required this.size});

  final Animation<double> animation;
  final Gradient gradient;
  final Color glow;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(parent: animation, curve: const Interval(0, 0.55, curve: Curves.easeOutBack));
    final halo = CurvedAnimation(parent: animation, curve: const Interval(0.15, 0.8, curve: Curves.easeOut));
    return Semantics(
      label: 'Saved',
      child: SizedBox.square(
        dimension: size * 1.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(halo),
              child: FadeTransition(
                opacity: halo,
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: glow.withValues(alpha: 0.12)),
                ),
              ),
            ),
            ScaleTransition(
              scale: pop,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                  boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: size * 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.details,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.isDark,
  });

  final _FileDetails details;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color secondaryTextColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const pdfRed = Color(0xFFE53935);
    final meta = TextStyle(fontSize: 13, color: secondaryTextColor);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: pdfRed.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: pdfRed, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (details.size != null || details.folder != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (details.size != null) Text(details.size!, style: meta),
                      if (details.size != null && details.folder != null)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('•', style: meta)),
                      if (details.folder != null) ...[
                        Icon(Icons.folder_rounded, size: 15, color: secondaryTextColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(details.folder!, style: meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.gradient,
    required this.glow,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Gradient gradient;
  final Color glow;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(_buttonRadius),
        boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(_buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
