import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:metersystem/core/theme/theme_x.dart';
import 'package:metersystem/services/diary_lock_service.dart';
part '../widget/diary_lock_settings_widgets.dart';
part '../widget/diary_lock_recovery_widgets.dart';

class DiaryUnlockScreen extends StatefulWidget {
  const DiaryUnlockScreen({
    super.key,
    required this.onUnlocked,
  });

  final VoidCallback onUnlocked;

  @override
  State<DiaryUnlockScreen> createState() => _DiaryUnlockScreenState();
}

class _DiaryUnlockScreenState extends State<DiaryUnlockScreen> {
  final _pinController = TextEditingController();
  final _lockService = DiaryLockService();

  bool _busy = false;
  bool _obscure = true;
  bool _deviceAuthAvailable = false;
  bool _deviceRecoveryEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeviceAuthentication();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceAuthentication() async {
    final results = await Future.wait<bool>([
      _lockService.isDeviceAuthenticationAvailable(),
      _lockService.isDeviceRecoveryEnabled(),
    ]);
    if (!mounted) return;
    setState(() {
      _deviceAuthAvailable = results[0];
      _deviceRecoveryEnabled = results[1];
    });
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final valid = await _lockService.verify(_pinController.text.trim());
    if (!mounted) return;
    if (valid) {
      widget.onUnlocked();
      return;
    }

    setState(() {
      _busy = false;
      _error = 'Incorrect PIN. Please try again.';
    });
  }

  Future<void> _unlockWithDevice() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final authenticated = await _lockService.authenticateWithDevice();
      if (!mounted) return;
      if (authenticated) {
        widget.onUnlocked();
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Device authentication was not completed.';
      });
    } on DiaryLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _recover() async {
    final recovered = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocalRecoverySheet(),
    );
    if (recovered == true && mounted) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: neutral.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  _DiaryBookIcon(color: scheme.primary),
                  const SizedBox(height: 28),
                  Text(
                    'Your diary is locked',
                    style: TextStyle(
                      color: neutral.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everything stays on this device. Enter your private PIN to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: neutral.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _pinController,
                    autofocus: true,
                    obscureText: _obscure,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _unlock(),
                    style: TextStyle(
                      color: neutral.textPrimary,
                      fontSize: 22,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Diary PIN',
                      errorText: _error,
                      prefixIcon: const Icon(Icons.password_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                      filled: true,
                      fillColor: neutral.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: neutral.divider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _unlock,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: const Text('Unlock diary'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  if (_deviceAuthAvailable && _deviceRecoveryEnabled) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _unlockWithDevice,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: const Text('Use phone security'),
                      ),
                    ),
                  ],
                  TextButton.icon(
                    onPressed: _busy ? null : _recover,
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Forgot PIN? Recover locally'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

