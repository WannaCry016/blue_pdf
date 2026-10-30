import 'package:flutter/material.dart';

/// Asks for the password of a protected PDF. [verify] is called for each
/// attempt; the dialog stays open on a wrong password and returns the
/// accepted password, or null when the user skips the file.
Future<String?> showPdfPasswordDialog(
  BuildContext context, {
  required String fileName,
  required Future<bool> Function(String password) verify,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PdfPasswordDialog(fileName: fileName, verify: verify),
  );
}

class _PdfPasswordDialog extends StatefulWidget {
  const _PdfPasswordDialog({required this.fileName, required this.verify});

  final String fileName;
  final Future<bool> Function(String password) verify;

  @override
  State<_PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<_PdfPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscured = true;
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text;
    if (password.isEmpty || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final accepted = await widget.verify(password);
    if (!mounted) return;
    if (accepted) {
      Navigator.pop(context, password);
    } else {
      setState(() {
        _checking = false;
        _error = 'Incorrect password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.lock_outline_rounded),
      title: const Text('Password required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${widget.fileName}" is protected. Enter its password to use it.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscured,
            enabled: !_checking,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: _error,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscured ? 'Show password' : 'Hide password',
                icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context),
          child: const Text('Skip file'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: _checking
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Unlock'),
        ),
      ],
    );
  }
}
