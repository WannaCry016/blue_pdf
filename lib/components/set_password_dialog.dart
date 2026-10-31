import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for a new password, entered twice so a typo can't lock the user out.
/// Returns the password, or null when cancelled.
Future<String?> showSetPasswordDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    // A stray tap outside shouldn't throw away what was typed.
    barrierDismissible: false,
    builder: (_) => const SetPasswordDialog(),
  );
}

class SetPasswordDialog extends StatefulWidget {
  const SetPasswordDialog({super.key});

  @override
  State<SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<SetPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();
  bool _obscured = true;

  /// Mismatch is only reported once the user tries to continue, not while typing.
  bool _showMismatch = false;

  bool get _filled => _password.text.isNotEmpty && _confirm.text.isNotEmpty;
  bool get _matches => _filled && _password.text == _confirm.text;

  @override
  void initState() {
    super.initState();
    _password.addListener(_changed);
    _confirm.addListener(_changed);
  }

  void _changed() => setState(() => _showMismatch = false);

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_filled) return;
    if (!_matches) {
      setState(() => _showMismatch = true);
      _confirmFocus.requestFocus();
      return;
    }
    // Lets password managers offer to save it.
    TextInput.finishAutofillContext();
    Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final visibility = IconButton(
      tooltip: _obscured ? 'Show password' : 'Hide password',
      icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _obscured = !_obscured),
    );

    // Kept to a title and two fields so both stay visible above the keyboard.
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded),
          SizedBox(width: 10),
          // Shrinks rather than overflows with large system font sizes.
          Flexible(child: Text('Protect PDF', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SingleChildScrollView(
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              TextField(
                controller: _password,
                autofocus: true,
                obscureText: _obscured,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _confirmFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: visibility,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                focusNode: _confirmFocus,
                obscureText: _obscured,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  border: const OutlineInputBorder(),
                  errorText: _showMismatch ? "Passwords don't match" : null,
                  suffixIcon: _matches
                      ? Icon(Icons.check_circle_rounded, color: Colors.green.shade600, semanticLabel: 'Passwords match')
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _filled ? _submit : null, child: const Text('Protect')),
      ],
    );
  }
}
