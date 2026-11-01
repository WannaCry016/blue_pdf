/// Checks the split dialog's From and To boxes (1-based, as typed).
///
/// Each box is judged on its own first, so a mistake in one never marks the
/// other as wrong. An empty box is "not finished yet", not an error. Only when
/// both are valid pages is their order checked, and that error goes on the box
/// the user changed last ([editedFrom]).
class PageRange {
  factory PageRange(String fromText, String toText, int pageCount, {bool editedFrom = false}) {
    final (from, fromError) = _page(fromText, pageCount);
    final (to, toError) = _page(toText, pageCount);
    if (from != null && to != null && from > to) {
      return editedFrom
          ? PageRange._(from, to, "Can't be after page $to", null)
          : PageRange._(from, to, null, "Can't be before page $from");
    }
    return PageRange._(from, to, fromError, toError);
  }

  const PageRange._(this.from, this.to, this.fromError, this.toError);

  /// The page in each box when it is a page of this PDF, regardless of order.
  final int? from;
  final int? to;
  final String? fromError;
  final String? toError;

  bool get isValid => from != null && to != null && fromError == null && toError == null;

  /// 0-based page indices from [from] to [to], or empty when not [isValid].
  List<int> get pages => isValid ? [for (var page = from!; page <= to!; page++) page - 1] : const [];

  static (int?, String?) _page(String text, int pageCount) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (null, null);
    final page = int.tryParse(trimmed);
    if (page == null) return (null, 'Enter a number');
    if (page < 1) return (null, 'Pages start at 1');
    if (page > pageCount) return (null, 'Only $pageCount ${pageCount == 1 ? 'page' : 'pages'}');
    return (page, null);
  }
}
