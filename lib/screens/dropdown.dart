import 'package:flutter/material.dart';

class CustomDropdown extends StatefulWidget {
  final String? selectedTool;
  final Function(String) onChanged;
  final bool isDark;
  final Color textColor;

  const CustomDropdown({
    super.key,
    required this.selectedTool,
    required this.onChanged,
    required this.isDark,
    required this.textColor,
  });

  @override
  State<CustomDropdown> createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  final GlobalKey _dropdownKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  final List<Map<String, dynamic>> tools = [
    {
      "label": "Image to PDF",
      "icon": Icons.image_rounded,
    },
    {
      "label": "Merge PDF",
      "icon": Icons.picture_as_pdf_rounded,
    },
    {
      "label": "Encrypt PDF",
      "icon": Icons.lock_rounded, // 🔐 secure lock icon
    },
    {
      "label": "Unlock PDF",
      "icon": Icons.lock_open_rounded, // 🔓 unlock icon
    },
  ];


  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    final RenderBox renderBox = _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // This GestureDetector captures taps outside the dropdown
          GestureDetector(
            onTap: _removeDropdown,
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.transparent,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            ),
          ),

          // The actual dropdown
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 4,
            width: size.width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  children: tools.map((tool) {
                    return InkWell(
                      onTap: () {
                        widget.onChanged(tool['label']);
                        _removeDropdown();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(tool['icon'], color: Colors.blueAccent, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              tool['label'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: widget.isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }


  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _dropdownKey,
      onTap: _toggleDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_open, size: 20, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.selectedTool ?? "Choose a Tool",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.selectedTool != null
                      ? widget.textColor
                      : Colors.grey.shade600,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 28, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}
