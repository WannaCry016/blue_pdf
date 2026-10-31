import 'package:blue_pdf/components/privacy_policy_page.dart';
import 'package:flutter/material.dart' hide LicensePage;
import 'package:url_launcher/url_launcher.dart';
import 'package:blue_pdf/components/license.dart';
import 'package:blue_pdf/services/update_service.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101A30) : Colors.grey[100];
    final cardColor = isDark ? const Color(0xFF1A2236) : Colors.white;
    final borderColor = isDark ? const Color(0xFF232A3B) : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? const Color(0xFFB0B8C1) : Colors.grey;
    final gradientColors = isDark
        ? [const Color(0xFF2979FF), const Color(0xFF536DFE), const Color(0xFF00B8D4)]
        : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("About"),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
      backgroundColor: bgColor,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(cardColor, textColor, secondaryTextColor, isDark),
          const SizedBox(height: 14),
          _buildSupportCard(context, cardColor, textColor, secondaryTextColor, borderColor),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Color cardColor, Color textColor, Color secondaryTextColor, bool isDark) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        child: Column(
          children: [
            const _DeveloperAvatar(size: 84),
            const SizedBox(height: 14),
            Text(
              "Ayushman Pal",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 2),
            Text("Indie Developer", style: TextStyle(fontSize: 13.5, color: secondaryTextColor)),
            const SizedBox(height: 12),
            Text(
              "Thanks for using Blue PDF — a fast and simple utility built with 💙 to help you work with your documents offline. No ads, no nonsense.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 10),
            FutureBuilder<String>(
              future: UpdateService.getCurrentVersion(),
              builder: (context, snapshot) => Text(
                snapshot.hasData ? "Version ${snapshot.data}" : "",
                style: TextStyle(fontSize: 12.5, color: secondaryTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard(
    BuildContext context,
    Color cardColor,
    Color textColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: cardColor,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.bug_report_outlined, color: Colors.blueGrey.shade300),
            title: Text("Bug / Feature Request", style: TextStyle(fontSize: 14.5, color: textColor)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _launchURL("mailto:ayushmanpal@proton.me?subject=Blue%20PDF%20Feedback"),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: Colors.blueGrey.shade300),
            title: Text("Privacy Policy", style: TextStyle(fontSize: 14.5, color: textColor)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()));
            },
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
          ListTile(
            leading: Icon(Icons.verified_user, color: Colors.blueGrey.shade300),
            title: Text("License", style: TextStyle(fontSize: 14.5, color: textColor)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LicensePage()));
            },
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
          ListTile(
            leading: const Icon(Icons.star_rate_outlined, color: Colors.amber),
            title: Text("Rate Us", style: TextStyle(fontSize: 14.5, color: textColor)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _launchURL("https://play.google.com/store/apps/details?id=com.bluepdf.blue_pdf"),
          ),
        ],
      ),
    );
  }
}

/// The developer's picture from `assets/avatar.png`, or a person icon until one is added.
class _DeveloperAvatar extends StatelessWidget {
  const _DeveloperAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: const Color(0xFF1976D2),
      child: Icon(Icons.person, size: size / 2, color: Colors.white),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          'assets/avatar.png',
          fit: BoxFit.cover,
          // Decoded at display size, whatever the source resolution.
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}
