part of '../view/diary_lock_screen.dart';

class DiaryLockSettingsSheet extends StatefulWidget {
  const DiaryLockSettingsSheet({
    super.key,
    this.onLockStateChanged,
  });

  final ValueChanged<bool>? onLockStateChanged;

  @override
  State<DiaryLockSettingsSheet> createState() =>
      _DiaryLockSettingsSheetState();
}

class _DiaryLockSettingsSheetState extends State<DiaryLockSettingsSheet> {
  final _service = DiaryLockService();
  final _currentPin = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();

  bool? _enabled;
  bool _busy = false;
  bool _deviceRecoveryEnabled = true;
  bool _deviceAuthAvailable = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currentPin.dispose();
    _newPin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<bool>([
      _service.isEnabled(),
      _service.isDeviceRecoveryEnabled(),
      _service.isDeviceAuthenticationAvailable(),
    ]);
    if (!mounted) return;
    setState(() {
      _enabled = results[0];
      _deviceRecoveryEnabled = results[1];
      _deviceAuthAvailable = results[2];
    });
  }

  Future<void> _savePin() async {
    if (_newPin.text != _confirmPin.text) {
      _setMessage('The new PIN and confirmation do not match.', isError: true);
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final wasEnabled = _enabled == true;
      String? recoveryCode;
      if (wasEnabled) {
        await _service.changePin(
          currentPin: _currentPin.text,
          newPin: _newPin.text,
        );
      } else {
        recoveryCode = await _service.enable(
          _newPin.text,
          deviceRecoveryEnabled: _deviceRecoveryEnabled,
        );
      }

      if (!mounted) return;
      setState(() {
        _enabled = true;
        _busy = false;
        _message = wasEnabled
            ? 'Diary PIN has been updated.'
            : 'Diary lock is enabled.';
        _messageIsError = false;
        _currentPin.clear();
        _newPin.clear();
        _confirmPin.clear();
      });

      if (recoveryCode != null && mounted) {
        await _showRecoveryCode(recoveryCode);
      }
      if (mounted) widget.onLockStateChanged?.call(true);
    } on DiaryLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.message;
        _messageIsError = true;
      });
    }
  }

  Future<void> _setDeviceRecovery(bool value) async {
    setState(() => _deviceRecoveryEnabled = value);
    if (_enabled == true) {
      await _service.setDeviceRecoveryEnabled(value);
    }
  }

  Future<void> _removeLock() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _service.disableWithCurrentPin(_currentPin.text);
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _busy = false;
        _message = 'Diary lock has been removed.';
        _messageIsError = false;
        _currentPin.clear();
      });
      widget.onLockStateChanged?.call(false);
    } on DiaryLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.message;
        _messageIsError = true;
      });
    }
  }

  Future<void> _regenerateRecoveryCode() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final code = await _service.regenerateRecoveryCode(
        currentPin: _currentPin.text,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _currentPin.clear();
      });
      await _showRecoveryCode(code);
    } on DiaryLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.message;
        _messageIsError = true;
      });
    }
  }

  Future<void> _recoverLocally() async {
    final recovered = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocalRecoverySheet(),
    );
    if (recovered == true && mounted) {
      setState(() {
        _enabled = false;
        _message = 'Local recovery succeeded. The old diary PIN was removed.';
        _messageIsError = false;
      });
      widget.onLockStateChanged?.call(false);
    }
  }

  Future<void> _showRecoveryCode(String recoveryCode) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final neutral = dialogContext.themeColors.neutral;
        return AlertDialog(
          icon: const Icon(Icons.key_rounded, size: 34),
          title: const Text('Save your recovery code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This code is stored only as a secure hash and cannot be shown again. Keep it somewhere private.',
                textAlign: TextAlign.center,
                style: TextStyle(color: neutral.textSecondary),
              ),
              const SizedBox(height: 18),
              SelectableText(
                recoveryCode,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: recoveryCode));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Recovery code copied.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('I saved it'),
            ),
          ],
        );
      },
    );
  }

  void _setMessage(String value, {required bool isError}) {
    setState(() {
      _message = value;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;

    return Container(
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: neutral.divider,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Diary privacy',
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _enabled == true
                  ? 'Change the PIN, update local recovery, or remove the diary lock.'
                  : 'Protect the diary with a local 4–6 digit PIN. No account or internet is used.',
              style: TextStyle(color: neutral.textSecondary),
            ),
            const SizedBox(height: 20),
            if (_enabled == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_enabled == true) ...[
                _PinField(controller: _currentPin, label: 'Current PIN'),
                const SizedBox(height: 12),
              ],
              _PinField(
                controller: _newPin,
                label: _enabled == true ? 'New PIN' : 'Create PIN',
              ),
              const SizedBox(height: 12),
              _PinField(controller: _confirmPin, label: 'Confirm new PIN'),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _deviceRecoveryEnabled,
                onChanged: _busy ? null : _setDeviceRecovery,
                secondary: const Icon(Icons.fingerprint_rounded),
                title: const Text('Allow phone security'),
                subtitle: Text(
                  _deviceAuthAvailable
                      ? 'Use fingerprint, Face ID, or the phone PIN/pattern/passcode.'
                      : 'This device currently has no supported local authentication.',
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _messageIsError
                        ? Theme.of(context).colorScheme.error
                        : Colors.green,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _savePin,
                  icon: const Icon(Icons.enhanced_encryption_rounded),
                  label: Text(
                    _enabled == true ? 'Change PIN' : 'Enable diary lock',
                  ),
                ),
              ),
              if (_enabled == true) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _regenerateRecoveryCode,
                    icon: const Icon(Icons.vpn_key_rounded),
                    label: const Text('Create a new recovery code'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _removeLock,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Remove lock'),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _recoverLocally,
                  icon: const Icon(Icons.health_and_safety_rounded),
                  label: const Text('Forgot PIN? Use local recovery'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
