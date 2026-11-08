import 'package:flutter/material.dart';

import 'app_update_dialog.dart';
import 'app_update_preferences.dart';
import 'app_update_service.dart';

class AppUpdateCoordinator {
  AppUpdateCoordinator._();

  static bool _checking = false;
  static bool _dialogOpen = false;

  static Future<void> checkAndPrompt(
    BuildContext context, {
    bool manual = false,
  }) async {
    if (_checking || _dialogOpen) return;

    // Manual checks are always allowed. The preference only controls the
    // automatic check that runs when DayArk starts.
    if (!manual) {
      final enabled = await AppUpdatePreferences.instance
          .isCheckOnStartupEnabled();
      if (!enabled) return;
    }

    _checking = true;
    try {
      final update = await AppUpdateService.instance.checkForUpdate();
      if (!context.mounted) return;

      if (update == null) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DayArk is up to date.')),
          );
        }
        return;
      }

      _dialogOpen = true;
      try {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => AppUpdateDialog(update: update),
        );
      } finally {
        _dialogOpen = false;
      }
    } on AppUpdateException catch (error) {
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not check for updates right now.'),
          ),
        );
      }
    } finally {
      _checking = false;
    }
  }
}
