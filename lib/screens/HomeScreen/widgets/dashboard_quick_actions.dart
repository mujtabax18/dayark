import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../../../core/design/app_tokens.dart';
import '../../../models/ExpenseItem.dart';
import '../../../models/dashboard_summary.dart';
import '../../../models/meter.dart';
import '../../../screens/Expenses/controller/ExpensesController.dart';
import '../../../screens/Multimedia/MultimediaDashboard.dart';
import '../../../screens/Personal_diary/widget/DiaryEntrySheet.dart';
import '../../../screens/Grocery/Grocery/controller/grocery_controller.dart'
    as grocery;
import '../../../screens/habitTracker/controller/habit_tracker_controller.dart';
import '../../../screens/loan/khata_account_form_sheet.dart';
import '../../../screens/loan/loan_controller.dart';
import '../../../screens/meter/MeterList/controller/meter_provider.dart';
import '../../../screens/meter/meterreading/widgets/AddReadingWidget.dart';
import '../../../screens/scanner/view/scanner_gallery_screen.dart';
import '../../../screens/pill_reminder/pill_home/provider/pill_home_provider.dart';
import '../../../utlis/app_router.dart';
import '../../../utlis/platform_capabilities.dart';
import '../../../utlis/constant.dart';
import '../controller/dashboard_provider.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';

part 'parts/dashboard_quick_actions_quick_selection_sheet.dart';
part 'parts/dashboard_quick_actions_meter_selection_sheet.dart';

Future<void> showQuickExpenseSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QuickExpenseSheet(),
  );
  ref.invalidate(homeDashboardProvider);
}

Future<void> showQuickMeterReading(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(meterServiceProvider);
  final meters = await service.getAllMeters(includeInactive: false);
  if (!context.mounted) return;

  if (meters.isEmpty) {
    openResponsiveModule(context, RoutesStr.meterList);
    return;
  }

  final meter = await showModalBottomSheet<Meter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MeterSelectionSheet(meters: meters),
  );
  if (meter == null || !context.mounted) return;

  final meterId = meter.id;
  if (meterId == null) return;

  // The form now needs the complete reading history. It uses the selected
  // reading date to locate its chronological previous and next readings.
  final readings = await service.getReadingsForMeter(meterId);
  final tariffSlabs = await service.getTariffSlabs(meterId);
  final baselineAnchor = await service.getBaselineAnchor(meterId);
  if (!context.mounted) return;

  final reading = await showReadingFormSheet(
    context: context,
    meter: meter,
    readings: readings,
    tariffSlabs: tariffSlabs,
    baselineAnchor: baselineAnchor,
  );
  if (reading == null) return;

  final insertedId = await service.addReading(reading);

  // Keep quick-add behavior identical to the meter detail screen: the first
  // reading becomes the baseline only when no baseline already exists.
  if (meter.baseline == null && readings.isEmpty) {
    await service.updateMeterBaseline(
      meterId,
      reading.value,
      baselineDate: reading.date,
      readingId: insertedId,
    );
  }

  await ref.read(meterProvider.notifier).loadMeters();
  final meterRevision = ref.read(meterDataRevisionProvider.notifier);
  meterRevision.state = meterRevision.state + 1;
  ref.invalidate(meterReadingsOverviewProvider);
  ref.invalidate(meterBaselineAnchorsOverviewProvider);
  ref.invalidate(meterTariffSlabsOverviewProvider);
  ref.invalidate(homeDashboardProvider);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Reading added for ${meter.name}.')),
  );
}

Future<void> showQuickLoanForm(
  BuildContext context,
  WidgetRef ref,
) async {
  final account = await showKhataAccountForm(context);
  if (account == null) return;
  try {
    final id = await ref.read(loanServiceProvider).addLoan(account);
    refreshKhata(ref, loanId: id);
    ref.invalidate(homeDashboardProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${account.entityName} added to Digital Khata.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to add loan: $error')),
    );
  }
}

Future<void> showMediaQuickActions(
  BuildContext context,
  WidgetRef ref,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Add or edit image'),
              subtitle: const Text('Choose an image and open the editor'),
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Add or edit PDF'),
              subtitle: const Text('Choose a PDF and open the editor'),
              onTap: () => Navigator.pop(sheetContext, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.video_settings_outlined),
              title: const Text('Add or edit video'),
              subtitle: const Text('Choose a video and open the editor'),
              onTap: () => Navigator.pop(sheetContext, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.perm_media_outlined),
              title: const Text('Open Media Studio'),
              onTap: () => Navigator.pop(sheetContext, 'studio'),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MultimediaDashboard(
        initialAction: action == 'studio' ? null : action,
      ),
    ),
  );
  ref.invalidate(homeDashboardProvider);
}

Future<void> openQuickDiary(BuildContext context, WidgetRef ref) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => DiaryEntrySheet(initialDate: DateTime.now()),
    ),
  );
  ref.invalidate(homeDashboardProvider);
}

Future<void> openQuickScanner(BuildContext context, WidgetRef ref) async {
  if (!documentScannerCaptureSupported) {
    await openResponsiveModule(context, RoutesStr.scannerGallery);
    ref.invalidate(homeDashboardProvider);
    return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => const ScannerGalleryScreen(startWithCamera: true),
    ),
  );
  ref.invalidate(homeDashboardProvider);
}

Future<void> showQuickHabitUpdate(
  BuildContext context,
  WidgetRef ref,
  HabitHomeSummary summary,
) async {
  final habits = summary.items
      .where((habit) => habit.canComplete && !habit.isCompleted)
      .toList(growable: false);

  if (habits.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All available habits are completed.'),
      ),
    );
    return;
  }

  final selected = await showModalBottomSheet<HabitHomeItem>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _QuickSelectionSheet<HabitHomeItem>(
      title: 'Complete a habit',
      items: habits,
      itemBuilder: (habit) {
        final habitColor = Color(habit.colorValue);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: habitColor.withValues(alpha: 0.14),
            child: CenteredFaIcon(
              FontAwesomeIcons.check,
              color: habitColor,
              size: 18,
            ),
          ),
          title: Text(habit.title),
          subtitle: Text(
            habit.description?.trim().isNotEmpty == true
                ? habit.description!.trim()
                : habit.category,
          ),
          trailing: const Icon(
            Icons.check_circle_outline_rounded,
          ),
          onTap: () => Navigator.pop(sheetContext, habit),
        );
      },
    ),
  );

  if (selected == null) return;

  try {
    await ref.read(dashboardServiceProvider).markHabitComplete(selected.id);

    await ref.read(habitTrackerControllerProvider.notifier).refresh();

    ref.invalidate(homeDashboardProvider);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selected.title} marked complete.'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not update habit: $error'),
      ),
    );
  }
}

Future<void> showQuickGroceryUpdate(
  BuildContext context,
  WidgetRef ref,
  GroceryHomeSummary summary,
) async {
  if (summary.entries.isEmpty) {
    openResponsiveModule(context, RoutesStr.grocery);
    return;
  }

  final selected = await showModalBottomSheet<GroceryHomeEntry>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _QuickSelectionSheet<GroceryHomeEntry>(
      title: 'Complete grocery or chore',
      items: summary.entries,
      itemBuilder: (entry) => ListTile(
        leading: Icon(
          entry.isChore
              ? Icons.cleaning_services_outlined
              : Icons.shopping_bag_outlined,
        ),
        title: Text(entry.title),
        subtitle: Text([
          if (entry.subtitle?.trim().isNotEmpty == true) entry.subtitle!,
          entry.priority.toUpperCase(),
          if (entry.isOverdue) 'OVERDUE',
        ].join(' • ')),
        trailing: const Icon(Icons.check_circle_outline_rounded),
        onTap: () => Navigator.pop(sheetContext, entry),
      ),
    ),
  );
  if (selected == null) return;

  try {
    await ref.read(dashboardServiceProvider).completeGroceryEntry(selected);
    ref.invalidate(grocery.groceryDashboardProvider);
    ref.invalidate(grocery.groceryTitlesProvider);
    ref.invalidate(grocery.householdChoresProvider);
    if (selected.groceryId != null) {
      ref.invalidate(grocery.groceryItemsProvider(selected.groceryId!));
    }
    ref.invalidate(homeDashboardProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.title} completed.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not update grocery: $error')),
    );
  }
}

Future<void> showQuickPillUpdate(
  BuildContext context,
  WidgetRef ref,
  PillHomeSummary summary,
) async {
  final occurrences = summary.occurrences
      .where((occurrence) => occurrence.canTake && occurrence.status != 'TAKEN')
      .toList(growable: false);
  if (occurrences.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No medicine is available to mark taken.')),
    );
    return;
  }

  final selected = await showModalBottomSheet<PillHomeOccurrence>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _QuickSelectionSheet<PillHomeOccurrence>(
      title: 'Mark medicine taken',
      items: occurrences,
      itemBuilder: (occurrence) => ListTile(
        leading: const Icon(Icons.medication_rounded),
        title: Text(occurrence.pillName),
        subtitle: Text([
          occurrence.scheduledTime,
          if (occurrence.dosage?.trim().isNotEmpty == true) occurrence.dosage!,
        ].join(' • ')),
        trailing: const Icon(Icons.check_circle_outline_rounded),
        onTap: () => Navigator.pop(sheetContext, occurrence),
      ),
    ),
  );
  if (selected == null) return;

  try {
    await ref.read(dashboardServiceProvider).markPillTaken(selected.id);
    ref.invalidate(pillHomeControllerProvider);
    ref.invalidate(homeDashboardProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.pillName} marked taken.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not update medicine: $error')),
    );
  }
}

