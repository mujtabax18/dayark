import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/theme_x.dart';
import 'app_release_notes.dart';
import 'app_update_model.dart';
import 'app_update_preferences.dart';
import 'app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.update,
  });

  final AppUpdateInfo update;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  final AppUpdateService _service = AppUpdateService.instance;

  bool _busy = false;
  bool _linuxReadyToRestart = false;
  double? _progress;
  String? _status;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final update = widget.update;

    return PopScope(
      canPop: !_busy && !_linuxReadyToRestart,
      child: AlertDialog(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.system_update_alt_rounded),
                SizedBox(width: 10),
                Expanded(child: Text('DayArk update available')),
              ],
            ),
            if (_busy || _linuxReadyToRestart) ...[
              const SizedBox(height: 14),
              if (_busy) LinearProgressIndicator(value: _progress),
              const SizedBox(height: 7),
              Row(
                children: [
                  if (_progress != null) ...[
                    Text(
                      '${((_progress! * 100).clamp(0, 100)).round()}%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _status ?? 'Preparing update…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: neutral.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${update.currentVersion}  →  ${update.latestVersion}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${update.assetName} • ${update.formattedSize}',
                  style: TextStyle(color: neutral.textSecondary),
                ),
                if (update.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'What’s new',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  AppReleaseNotes(markdown: update.releaseNotes),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  Platform.isAndroid
                      ? 'Android will ask for installer confirmation. Existing data is preserved when the app ID and signing key remain unchanged.'
                      : Platform.isWindows
                          ? 'Windows will open the DayArk installer. Follow its prompts to update the existing installation. Save your work first.'
                          : 'Linux will replace the current AppImage after DayArk closes, then reopen the app. Keep the AppImage in a writable folder such as ~/Applications.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: neutral.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: (_busy || _linuxReadyToRestart) ? null : _neverShowAgain,
            child: const Text('Never show again'),
          ),
          TextButton(
            onPressed: (_busy || _linuxReadyToRestart) ? null : () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : (_linuxReadyToRestart ? _closeToInstall : _downloadAndInstall),
            icon: Icon(_linuxReadyToRestart ? Icons.restart_alt_rounded : Icons.download_rounded),
            label: Text(_linuxReadyToRestart ? 'Close & install update' : 'Download & install'),
          ),
        ],
      ),
    );
  }

  Future<void> _neverShowAgain() async {
    await AppUpdatePreferences.instance.setCheckOnStartup(false);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _error = null;
    });

    try {
      if (Platform.isAndroid) {
        var allowed = await _service.hasInstallPermission();
        if (!allowed) {
          final shouldOpenSettings = await _showInstallPermissionExplanation();
          if (shouldOpenSettings != true || !mounted) return;

          allowed = await _service.requestInstallPermission();
          if (!mounted) return;
          if (!allowed) {
            setState(() {
              _error = 'Installation permission is disabled. Open Install unknown apps '
                  'for DayArk, allow this source and try again.';
            });
            return;
          }
        }
      }

      setState(() {
        _busy = true;
        _progress = 0;
        _status = 'Downloading ${widget.update.assetName}…';
      });

      final package = await _service.downloadUpdate(
        widget.update,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? received / total : null;
            if (total > 0) {
              final percent = ((received / total) * 100).clamp(0, 100).round();
              _status = 'Downloading… $percent%';
            } else {
              _status = 'Downloading update…';
            }
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _progress = null;
        _status = Platform.isAndroid
            ? 'Verified. Opening Android installer…'
            : Platform.isWindows
                ? 'Verified. Opening Windows installer…'
                : 'Verified. Preparing Linux update…';
      });

      if (Platform.isAndroid) {
        await _service.installApk(package);
        if (mounted) Navigator.of(context).pop();
      } else if (Platform.isWindows) {
        await _service.installWindowsSetup(package);
        if (mounted) Navigator.of(context).pop();
      } else if (Platform.isLinux) {
        await _service.scheduleLinuxAppImageInstall(package);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _linuxReadyToRestart = true;
          _progress = null;
          _status = 'Ready. Save your work, then press Close & install update. DayArk will reopen.';
        });
      }
    } on AppUpdateException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _status = null;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _status = null;
        _error = 'Could not install the update: $error';
      });
    }
  }

  void _closeToInstall() {
    // The detached updater waits for this process to exit, replaces only the
    // user-writable AppImage, and launches the verified new AppImage.
    exit(0);
  }

  Future<bool?> _showInstallPermissionExplanation() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Allow DayArk to install updates'),
        content: const Text(
          'Android requires your approval before an app installed outside the Play Store can open an APK installer.\n\n'
          'On the next screen, enable “Allow from this source” for DayArk, then return to the app. This permission is only used when you choose to install a DayArk update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }
}
