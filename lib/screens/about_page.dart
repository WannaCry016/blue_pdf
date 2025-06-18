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
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "About Developer",
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
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
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with gradient ring
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                ),
              ),
              child: const CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 48, color: Color(0xFF1976D2)),
              ),
            ),
            const SizedBox(height: 16),

            // Name & Role
            const Text(
              "Ayushman Pal",
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Indie App Developer",
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'sans-serif',
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),

            // Description
            const Text(
              "Blue PDF is a modern utility tool for managing and editing PDF files. "
              "Feel free to reach out if you have suggestions, feature requests, or questions!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'sans-serif',
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 28),

            // Social / Contact Buttons
            _styledButton(
              label: "GitHub",
              icon: Icons.code,
              color: Colors.black,
              onTap: () => _launchURL("https://github.com/ayushman72"),
            ),
            _styledButton(
              label: "LinkedIn",
              icon: Icons.business_center,
              color: Color(0xFF0077B5),
              onTap: () => _launchURL("https://linkedin.com/in/ayushman-pal"),
            ),
            _styledButton(
              label: "Email",
              icon: Icons.email,
              color: Colors.redAccent,
              onTap: () => _launchURL("mailto:payushman72@gmail.com"),
            ),
            const SizedBox(height: 18),

            // Feature request
            TextButton.icon(
              onPressed: () => _launchURL(
                  "mailto:payushman72@gmail.com?subject=Feature%20Request%20for%20Blue%20PDF"),
              icon: const Icon(Icons.feedback_outlined, size: 20),
              label: const Text("Request a Feature / Report a Bug"),
            ),
            const SizedBox(height: 8),

            // Privacy Policy
            TextButton.icon(
              onPressed: () => _launchURL("https://yourdomain.com/privacy"),
              icon: const Icon(Icons.privacy_tip_outlined, size: 20),
              label: const Text("Privacy Policy"),
            ),
            const SizedBox(height: 32),

            // App Version
            const Text(
              "Blue PDF v1.0.0",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontFamily: 'sans-serif',
              ),
            ),
          ],
        ),
      ),

    );
  }

  Widget _styledButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontFamily: 'sans-serif',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
