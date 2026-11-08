import 'package:flutter/material.dart';

/// Collects a backup password without storing it outside the dialog.
///
/// Each dialog owns its controllers. Controllers are disposed by the widget
/// State after the dialog has actually left the widget tree, not as soon as
/// showDialog's Future completes (which can happen during the pop animation).
class BackupPasswordDialog {
  const BackupPasswordDialog._();

  static Future<String?> create(BuildContext context) => showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CreateBackupPasswordDialog(),
      );

  /// [errorText] lets the restore flow explain a failed authentication when
  /// the user retries with a different password. No password is persisted.
  static Future<String?> restore(
    BuildContext context, {
    String? errorText,
  }) =>
      showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RestoreBackupPasswordDialog(errorText: errorText),
      );
}

class _CreateBackupPasswordDialog extends StatefulWidget {
  const _CreateBackupPasswordDialog();

  @override
  State<_CreateBackupPasswordDialog> createState() =>
      _CreateBackupPasswordDialogState();
}

class _CreateBackupPasswordDialogState
    extends State<_CreateBackupPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    if (password.length < 12) {
      setState(() => _error = 'Password must be at least 12 characters.');
    } else if (password != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
    } else {
      Navigator.of(context).pop(password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Encrypt backup'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your database and files will be encrypted with AES-256-GCM. '
              'The backup can be restored on another device using this password. '
              'There is no password recovery. Keep it somewhere safe.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Backup password (12+ characters)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm backup password',
                border: OutlineInputBorder(),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              label: Text(_obscure ? 'Show passwords' : 'Hide passwords'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Continue to save'),
        ),
      ],
    );
  }
}

class _RestoreBackupPasswordDialog extends StatefulWidget {
  const _RestoreBackupPasswordDialog({this.errorText});

  final String? errorText;

  @override
  State<_RestoreBackupPasswordDialog> createState() =>
      _RestoreBackupPasswordDialogState();
}

class _RestoreBackupPasswordDialogState
    extends State<_RestoreBackupPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  String? _validationError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _validationError = 'Enter your backup password.');
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Unlock encrypted backup'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the password used when creating this backup. '
              'No data changes until authentication succeeds.',
            ),
            if (widget.errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              autofocus: true,
              controller: _passwordController,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Backup password',
                border: OutlineInputBorder(),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              label: Text(_obscure ? 'Show password' : 'Hide password'),
            ),
            if (_validationError != null)
              Text(
                _validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Unlock and restore'),
        ),
      ],
    );
  }
}
