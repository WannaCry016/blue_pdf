/// Parses page ranges such as `1-3, 7, 9-12` (1-based, as typed by the user)
/// into 0-based page indices in the order given. Repeated pages are kept once.
///
/// Throws a [FormatException] whose message can be shown to the user.
List<int> parsePageRanges(String input, int pageCount) {
  final parts = input.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) throw const FormatException('Enter the pages to keep, e.g. 1-3, 7');

  final seen = <int>{};
  final pages = <int>[];
  for (final part in parts) {
    final match = RegExp(r'^(\d+)\s*(?:-\s*(\d+))?$').firstMatch(part);
    if (match == null) throw FormatException('"$part" is not a page or range');

    final start = int.parse(match.group(1)!);
    final end = match.group(2) == null ? start : int.parse(match.group(2)!);
    if (start < 1 || end < 1) throw const FormatException('Pages start at 1');
    if (start > end) throw FormatException('"$part" goes backwards; write it as $end-$start');
    if (end > pageCount) {
      throw FormatException('This PDF has $pageCount ${pageCount == 1 ? 'page' : 'pages'}');
    }

    for (var page = start; page <= end; page++) {
      if (seen.add(page)) pages.add(page - 1);
    }
  }
  return pages;
}
