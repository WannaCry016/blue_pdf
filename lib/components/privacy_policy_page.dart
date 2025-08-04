// lib/privacy_policy_page.dart
import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  // --- 1. Colors are defined right here. No extra file needed. ---
  static const Color _primaryBlue = Color.fromARGB(255, 6, 42, 71);
  static const Color _accentBlue = Color.fromARGB(255, 95, 144, 185);
  static const Color _successGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Define adaptive colors based on theme
    final Color backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF2F5F8);
    final Color cardColor = isDarkMode ? const Color.fromARGB(255, 29, 41, 51) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white70 : Colors.black87;
    final Color headingColor = isDarkMode ? _accentBlue : _primaryBlue;
    final gradientColors = isDarkMode
        ? [const Color(0xFF2979FF), const Color(0xFF536DFE), const Color(0xFF00B8D4)]
        : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white, // Changed icon color to white
        ),
        title: const Text("Privacy Policy"),
        titleTextStyle: const TextStyle(
          color: Colors.white, // Changed title color to white
          fontSize: 20.0,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Intro Section ---
            Text(
              "Our Commitment to Your Privacy",
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: headingColor),
            ),
            const SizedBox(height: 8),
            Text(
              "Last updated: July 1, 2025", // Use a real date
              style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Text(
              'Blue PDF is built on a foundation of trust. This policy outlines how your information is handled. The short version: everything stays on your device.',
              style: TextStyle(fontSize: 15, height: 1.5, color: textColor),
            ),
            const SizedBox(height: 32),

            // --- Policy Sections in Cards ---
            _buildSection(
              icon: Icons.lock_outline,
              title: "1. Zero Data Collection",
              content: "We do not collect, store, transmit, or sell any of your personal information. Your files, usage patterns, and identity remain completely private and on your device.",
              cardColor: cardColor,
              textColor: textColor,
              headingColor: headingColor,
            ),
            _buildSection(
              icon: Icons.folder_open_outlined,
              title: "2. On-Device File Access",
              content: "The app requests storage access only to let you select images and save your PDFs. All processing happens locally. Nothing is ever uploaded to a server.",
              cardColor: cardColor,
              textColor: textColor,
              headingColor: headingColor,
            ),
            _buildSection(
              icon: Icons.camera_alt_outlined,
              title: "3. Camera Permission",
              content: "Camera access is used only when you actively choose to scan documents or capture images for a new PDF. The camera is never used in the background.",
              cardColor: cardColor,
              textColor: textColor,
              headingColor: headingColor,
            ),
            _buildSection(
              icon: Icons.wifi_off_outlined,
              title: "4. Offline First Design",
              content: "Blue PDF is designed to work completely offline. Internet access is not required for any feature, ensuring your data never leaves your device.",
              cardColor: cardColor,
              textColor: textColor,
              headingColor: headingColor,
            ),
            _buildSection(
              icon: Icons.ads_click,
              title: "5. Advertisements & Analytics",
              content: "This version is 100% ad-free and does not include any analytics trackers. Your experience is clean and private. This policy will be updated if this ever changes.",
              cardColor: cardColor,
              textColor: textColor,
              headingColor: headingColor,
            ),
            _buildSection(
              icon: Icons.contact_mail_outlined,
              title: "6. Contact Us",
              content: "If you have questions or feedback about this Privacy Policy, feel free to contact us at payushman72@gmail.com.",
              cardColor: cardColor,
              textColor: textColor,
              headingColor: headingColor,
            ),
            const SizedBox(height: 24),
            
            // --- Summary Section ---
            _buildSummaryCard(isDarkMode: isDarkMode, textColor: textColor),
          ],
        ),
      ),
    );
  }

  // --- 2. Helper widget for building each "card" section ---
  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required Color cardColor,
    required Color textColor,
    required Color headingColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: cardColor == Colors.white
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: _accentBlue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: TextStyle(height: 1.5, fontSize: 15, color: textColor)),
        ],
      ),
    );
  }
  
  // --- 3. Helper widget for the final summary card ---
  Widget _buildSummaryCard({required bool isDarkMode, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? _primaryBlue.withOpacity(0.3) : _primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryBlue.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: _accentBlue),
              SizedBox(width: 8),
              Text(
                "In Short: Your Privacy is Safe",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _accentBlue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryPoint("No user data is ever collected or stored.", textColor),
          _buildSummaryPoint("All processing happens offline on your device.", textColor),
          _buildSummaryPoint("Permissions are for core features only.", textColor),
          _buildSummaryPoint("The app is ad-free and tracker-free.", textColor),
        ],
      ),
    );
  }

  Widget _buildSummaryPoint(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: _successGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: textColor))),
        ],
      ),
    );
  }
}