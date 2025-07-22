import 'package:blue_pdf/screens/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final accent = isDark ? const Color(0xFF2979FF) : const Color(0xFF1976D2);
    final gradientColors = isDark
        ? [const Color(0xFF2979FF), const Color(0xFF536DFE), const Color(0xFF00B8D4)]
        : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("About"),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      backgroundColor: bgColor,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(cardColor, textColor, secondaryTextColor, isDark),
          const SizedBox(height: 14),
          _buildConnectCard(cardColor, textColor, secondaryTextColor),
          const SizedBox(height: 14),
          _buildSupportCard(context, cardColor, textColor, secondaryTextColor, borderColor),
          const SizedBox(height: 24),
          _buildAppInfo(textColor, secondaryTextColor),
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
            const CircleAvatar(
              radius: 42,
              backgroundColor: Color(0xFF1976D2),
              child: Icon(Icons.person, size: 42, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              "Ayushman Pal",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 2),
            Text(
              "Indie Developer",
              style: TextStyle(fontSize: 13.5, color: secondaryTextColor),
            ),
            const SizedBox(height: 12),
            Text(
              "Thanks for using Blue PDF — a fast and simple utility built with 💙 to help you work with your documents offline. No ads, no nonsense.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectCard(Color cardColor, Color textColor, Color secondaryTextColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Connect",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSocialButton(
                  icon: Icons.code,
                  label: "GitHub",
                  color: Colors.black87,
                  onTap: () => _launchURL("https://github.com/WannaCry016"),
                  textColor: textColor,
                ),
                _buildSocialButton(
                  icon: Icons.business,
                  label: "LinkedIn",
                  color: Color(0xFF0A66C2),
                  onTap: () => _launchURL("https://linkedin.com/in/ayushmanpal"),
                  textColor: textColor,
                ),
                _buildSocialButton(
                  icon: Icons.email,
                  label: "Email",
                  color: Colors.redAccent,
                  onTap: () => _launchURL("mailto:ayushmanpal@proton.me"),
                  textColor: textColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 22,
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12.5, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context, Color cardColor, Color textColor, Color secondaryTextColor, Color borderColor) {
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
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

  Widget _buildAppInfo(Color textColor, Color secondaryTextColor) {
    return Column(
      children: [
        Text("Blue PDF v1.0.0", style: TextStyle(color: secondaryTextColor, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Built with ", style: TextStyle(color: secondaryTextColor, fontSize: 13)),
            const Icon(Icons.favorite, color: Colors.red, size: 14),
            Text(" in Flutter", style: TextStyle(color: secondaryTextColor, fontSize: 13)),
            const SizedBox(width: 4),
            Image.asset('assets/flutter_logo.png', height: 18),
          ],
        ),
      ],
    );
  }
}