import 'package:flutter/material.dart';

/// Tells the user a downloaded update is ready and lets them choose when to
/// restart into it. Stays until they restart or close it.
SnackBar updateReadySnackBar({required VoidCallback onRestart}) => SnackBar(
      behavior: SnackBarBehavior.floating,
      persist: true,
      showCloseIcon: true,
      content: const _UpdateReadyMessage(),
      action: SnackBarAction(label: 'Restart', onPressed: onRestart),
    );

class _UpdateReadyMessage extends StatelessWidget {
  const _UpdateReadyMessage();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.system_update_rounded, size: 20, color: Theme.of(context).colorScheme.onInverseSurface),
        const SizedBox(width: 12),
        const Expanded(child: Text('Update ready. Restart to install.')),
      ],
    );
  }
}
