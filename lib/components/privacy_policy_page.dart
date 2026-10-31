import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const lastUpdated = 'October 31, 2026';
  static const contactEmail = 'payushman72@gmail.com';

  static const _sections = [
    (
      icon: Icons.phone_android_rounded,
      title: 'Your files stay on your device',
      body:
          'Every PDF and image you open is processed on your phone by the app\'s built-in PDF engine. '
          'Nothing is uploaded, and the app does not even have permission to use the internet.',
    ),
    (
      icon: Icons.block_rounded,
      title: 'No data collection',
      body:
          'There are no accounts, ads, analytics or tracking. We never see your files, '
          'your usage or who you are.',
    ),
    (
      icon: Icons.key_rounded,
      title: 'Passwords',
      body:
          'Passwords you enter to protect or unlock a PDF are used only for that file, '
          'only while it is processed. They are never stored or shared.',
    ),
    (
      icon: Icons.photo_camera_outlined,
      title: 'Camera',
      body:
          'The camera is the only permission the app asks for, and only when you choose to '
          'capture a page. Photos are used for your PDF and nothing else.',
    ),
    (
      icon: Icons.folder_outlined,
      title: 'Files you open and save',
      body:
          'Files are opened through Android\'s file picker, so the app sees only what you select. '
          'Results are saved to Download/BLUE PDF or a folder you choose, and remain yours after '
          'uninstalling. Working copies are kept in the app\'s private storage and deleted automatically.',
    ),
    (
      icon: Icons.shop_outlined,
      title: 'Google Play',
      body:
          'Update notices and the rating prompt are provided by Google Play. Your rating goes to '
          'Google, not to the app. Google Play may share anonymous crash and performance statistics with '
          'developers, as it does for every app, under Google\'s Privacy Policy.',
    ),
    (
      icon: Icons.update_rounded,
      title: 'Changes to this policy',
      body:
          'If anything here changes, this page will be updated in the app first, '
          'with a new date at the top.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101A30) : Colors.grey[100];
    final cardColor = isDark ? const Color(0xFF1A2236) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bodyColor = isDark ? Colors.white70 : Colors.black87;
    final secondaryTextColor = isDark ? const Color(0xFFB0B8C1) : Colors.grey.shade600;
    final accent = isDark ? const Color(0xFF536DFE) : const Color(0xFF1976D2);
    final gradientColors = isDark
        ? [const Color(0xFF2979FF), const Color(0xFF536DFE), const Color(0xFF00B8D4)]
        : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Privacy Policy'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        // A Container, not a DecoratedBox: with no child it must expand to fill the bar.
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 3,
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
              child: Column(
                children: [
                  Icon(Icons.verified_user_rounded, size: 44, color: accent),
                  const SizedBox(height: 12),
                  Text(
                    'Private by design',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'BLUE PDF works entirely offline. Your documents never leave your phone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5, color: bodyColor),
                  ),
                  const SizedBox(height: 10),
                  Text('Last updated $lastUpdated', style: TextStyle(fontSize: 12.5, color: secondaryTextColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 2,
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final (index, section) in _sections.indexed) ...[
                    if (index > 0)
                      Divider(height: 1, indent: 64, endIndent: 16, color: secondaryTextColor.withValues(alpha: 0.2)),
                    _Section(
                      icon: section.icon,
                      title: section.title,
                      body: section.body,
                      accent: accent,
                      titleColor: textColor,
                      bodyColor: bodyColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 2,
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.mail_outline_rounded, color: accent),
              title: Text('Questions about privacy?', style: TextStyle(fontSize: 14.5, color: textColor)),
              subtitle: Text(contactEmail, style: TextStyle(fontSize: 13, color: secondaryTextColor)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => launchUrl(Uri.parse('mailto:$contactEmail?subject=BLUE%20PDF%20Privacy')),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor),
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(fontSize: 13.5, height: 1.5, color: bodyColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
