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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 14),
          _buildConnectCard(),
          const SizedBox(height: 14),
          _buildSupportCard(context),
          const SizedBox(height: 24),
          _buildAppInfo(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        child: Column(
          children: const [
            CircleAvatar(
              radius: 42,
              backgroundColor: Color(0xFF1976D2),
              child: Icon(Icons.person, size: 42, color: Colors.white),
            ),
            SizedBox(height: 14),
            Text(
              "Ayushman Pal",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 2),
            Text(
              "Indie Developer",
              style: TextStyle(fontSize: 13.5, color: Colors.grey),
            ),
            SizedBox(height: 12),
            Text(
              "Thanks for using Blue PDF — a fast and simple utility built with 💙 to help you work with your documents offline. No ads, no nonsense.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Connect",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                ),
                _buildSocialButton(
                  icon: Icons.business,
                  label: "LinkedIn",
                  color: Color(0xFF0A66C2),
                  onTap: () => _launchURL("https://linkedin.com/in/ayushmanpal"),
                ),
                _buildSocialButton(
                  icon: Icons.email,
                  label: "Email",
                  color: Colors.redAccent,
                  onTap: () => _launchURL("mailto:payushman72@gmail.com"),
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
          Text(label, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.bug_report_outlined, color: Colors.blueGrey),
            title: const Text("Bug / Feature Request", style: TextStyle(fontSize: 14.5)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _launchURL("mailto:payushman72@gmail.com?subject=Blue%20PDF%20Feedback"),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Colors.blueGrey),
            title: const Text("Privacy Policy", style: TextStyle(fontSize: 14.5)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.star_rate_outlined, color: Colors.amber),
            title: const Text("Rate Us", style: TextStyle(fontSize: 14.5)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _launchURL("https://play.google.com/store/apps/details?id=com.bluepdf.app"), // replace with your package
          ),
        ],
      ),
    );
  }


  Widget _buildAppInfo() {
    return Column(
      children: [
        const Text("Blue PDF v1.0.0", style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Built with ", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const Icon(Icons.favorite, color: Colors.red, size: 14),
            const Text(" in Flutter", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(width: 4),
            Image.asset('assets/flutter_logo.png', height: 18),
          ],
        ),
      ],
    );
  }
}