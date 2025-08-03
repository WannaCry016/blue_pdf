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
        title: const Text("Licenses"),
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
            child: ListView(
              children: [
                Text(
                  "Blue PDF",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 10),
                Text(
                  "Blue PDF is an open-source utility application that enables users to perform essential PDF operations such as merging, splitting, encrypting, and converting images to PDF.",
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
                    "MuPDF is a lightweight PDF and XPS viewer and toolkit.\n\n"
                    "© 2006–2024 Artifex Software, Inc.\n"
                    "Licensed under the GNU Affero General Public License (AGPL) v3.\n\n"
                    "Blue PDF uses only the core MuPDF C/C++ libraries for PDF manipulation.\n"
                    "It does *not* include MuPDF’s UI or viewer components.",
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  trailing: Icon(Icons.open_in_new, color: accent),
                  onTap: () => launchUrl(Uri.parse("https://mupdf.com")),
                ),

                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Source Code", style: TextStyle(color: textColor)),
                  subtitle: Text(
                    "This app is open-source under the same AGPL v3 license.\nYou can view and contribute to the source code below.",
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  trailing: Icon(Icons.code, color: accent),
                  onTap: () => launchUrl(Uri.parse("https://github.com/WannaCry016/blue_pdf")),
                ),

                const SizedBox(height: 20),
                Text(
                  "License Compliance",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent),
                ),
                const SizedBox(height: 10),
                Text(
                  "In compliance with the AGPL v3 license, we provide:\n"
                  "• A clear notice of MuPDF usage and licensing.\n"
                  "• Access to the full source code.\n"
                  "• No modification of MuPDF license or terms.\n\n"
                  "If you distribute this app or derivative works, you must also follow the AGPL v3 requirements.",
                  style: TextStyle(fontSize: 14.5, color: secondaryTextColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
