// lib/about_page.dart

import 'package:blue_pdf/screens/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // Keep the URL launcher function
  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Optional: Show a snackbar or dialog on error
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // The AppBar looks great, let's keep it!
        appBar: AppBar(
          // 1. To style the back button and any other icons in the AppBar
        iconTheme: const IconThemeData(
          color: Colors.white, // Changed icon color to white
        ),
        // 2. To style the title text
        title: const Text("About Blue PDF"),
        titleTextStyle: const TextStyle(
          color: Colors.white, // Changed title color to white
          fontSize: 20.0,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 6, 42, 71),
                Color.fromARGB(255, 95, 144, 185),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      // Use a light background for a cleaner look
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildConnectCard(),
          const SizedBox(height: 16),
          _buildSupportCard(context),
          const SizedBox(height: 32),
          _buildAppInfo(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: const [
            CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF1976D2),
              child: Icon(Icons.person, size: 50, color: Colors.white),
              // Pro-tip: Replace with your photo:
              // backgroundImage: AssetImage('assets/your_photo.jpg'),
            ),
            SizedBox(height: 16),
            Text(
              "Ayushman Pal",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              "Indie App Developer",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 12),
            Text(
              "Thank you for using Blue PDF! If you have any feedback or suggestions, feel free to reach out.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Connect with me",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialButton(
                  icon: Icons.code, // Using a generic icon for GitHub
                  label: "GitHub",
                  color: Colors.black87,
                  onTap: () => _launchURL("https://github.com/WannaCry016"),
                ),
                _buildSocialButton(
                  icon: Icons.business, // A more generic business icon
                  label: "LinkedIn",
                  color: const Color(0xFF0A66C2),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.bug_report_outlined, color: Colors.blueGrey),
            title: const Text("Report a Bug / Request a Feature"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _launchURL(
                "mailto:payushman72@gmail.com?subject=Blue%20PDF%20Feedback"),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Colors.blueGrey),
            title: const Text("Privacy Policy"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Column(
      children: [
        const Text(
          "Blue PDF v1.0.0",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Made with ",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const Icon(Icons.favorite, color: Colors.red, size: 16),
            const Text(
              " using ",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Image.asset(
              'assets/flutter_logo.png', // Make sure you have this asset
              height: 20,
            ),
          ],
        ),
      ],
    );
  }
}