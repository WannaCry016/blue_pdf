import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LicensePage extends StatelessWidget {
  const LicensePage({super.key});

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
        title: const Text("License"),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Blue PDF",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 10),
                Text(
                  "An open-source PDF utility app that lets you merge, split, encrypt, and convert images to PDF files with ease.",
                  style: TextStyle(fontSize: 16, color: secondaryTextColor),
                ),
                const SizedBox(height: 20),
                Text(
                  "Open Source Licenses",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("MuPDF", style: TextStyle(color: textColor)),
                  subtitle: Text(
                    "Used for PDF operations.\nLicensed under AGPL v3.",
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  trailing: Icon(Icons.open_in_new, color: accent),
                  onTap: () {
                    launchUrl(Uri.parse("https://mupdf.com"));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Source Code", style: TextStyle(color: textColor)),
                  subtitle: Text(
                    "GitHub Repository",
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  trailing: Icon(Icons.code, color: accent),
                  onTap: () {
                    launchUrl(Uri.parse("https://github.com/WannaCry016/blue_pdf"));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// MuPDF License Notice

// This app uses the MuPDF library, © Artifex Software Inc.
// MuPDF is licensed under the GNU Affero General Public License (AGPL) v3.
// We only use the MuPDF C/C++ library for PDF processing.
// We do not use MuPDF’s viewer or UI components.