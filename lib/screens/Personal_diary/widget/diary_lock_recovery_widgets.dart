part of '../view/diary_lock_screen.dart';

class LocalRecoverySheet extends StatefulWidget {
  const LocalRecoverySheet({super.key});

  @override
  State<LocalRecoverySheet> createState() => _LocalRecoverySheetState();
}

class _LocalRecoverySheetState extends State<LocalRecoverySheet> {
  final _codeController = TextEditingController();
  final _lockService = DiaryLockService();

  bool _busy = false;
  bool _deviceAuthAvailable = false;
  bool _deviceRecoveryEnabled = false;
  bool _hasRecoveryCode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<bool>([
      _lockService.isDeviceAuthenticationAvailable(),
      _lockService.isDeviceRecoveryEnabled(),
      _lockService.hasRecoveryCode(),
    ]);
    if (!mounted) return;
    setState(() {
      _deviceAuthAvailable = results[0];
      _deviceRecoveryEnabled = results[1];
      _hasRecoveryCode = results[2];
    });
  }

  Future<void> _recoverWithDevice() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final recovered = await _lockService.recoverWithDeviceAuthentication();
      if (!mounted) return;
      if (!recovered) {
        setState(() {
          _busy = false;
          _error = 'Device authentication was not completed.';
        });
        return;
      }
      Navigator.pop(context, true);
    } on DiaryLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _recoverWithCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the recovery code.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _lockService.disableWithRecoveryCode(code);
      if (mounted) Navigator.pop(context, true);
    } on DiaryLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
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
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recover diary access',
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Recovery happens only on this phone. No SMS, Firebase, account, or internet connection is used.',
              style: TextStyle(color: neutral.textSecondary),
            ),
            if (_deviceAuthAvailable && _deviceRecoveryEnabled) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _recoverWithDevice,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Verify with phone security'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              enabled: _hasRecoveryCode && !_busy,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                LengthLimitingTextInputFormatter(19),
              ],
              decoration: InputDecoration(
                labelText: 'Recovery code',
                hintText: 'ABCD-EFGH-JKLM-NPQR',
                prefixIcon: const Icon(Icons.vpn_key_rounded),
                border: const OutlineInputBorder(),
                helperText: _hasRecoveryCode
                    ? 'Use the code shown when the diary lock was enabled.'
                    : 'No recovery code exists for this older lock. Use phone security.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _busy || !_hasRecoveryCode ? null : _recoverWithCode,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset_rounded),
                label: const Text('Use recovery code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryBookIcon extends StatelessWidget {
  const _DiaryBookIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 190,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          topLeft: Radius.circular(5),
          bottomLeft: Radius.circular(5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 13,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              color: Colors.white.withValues(alpha: .22),
            ),
          ),
          const Center(
            child: Icon(Icons.lock_rounded, color: Colors.white, size: 48),
          ),
          const Positioned(
            left: 28,
            right: 18,
            bottom: 24,
            child: Text(
              'PRIVATE\nDIARY',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinField extends StatefulWidget {
  const _PinField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  State<_PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<_PinField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        counterText: '',
        labelText: widget.label,
        prefixIcon: const Icon(Icons.password_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
