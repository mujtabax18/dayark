// // lib/screens/notification_settings/quote_notification_settings.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:intl/intl.dart';
//
// import '../../../models/NotificationSettings.dart';
// import '../../../services/NotificationService.dart';
// import '../../../services/NotificationsManagers/QuoteNotificationManager.dart';
// import '../../habitTracker/controller/habit_tracker_controller.dart';
// import '../controller/notificationSettingController.dart';
//
// class QuoteNotificationSettingsScreen extends ConsumerStatefulWidget {
//   const QuoteNotificationSettingsScreen({super.key});
//
//   @override
//   ConsumerState<QuoteNotificationSettingsScreen> createState() => _QuoteNotificationSettingsScreenState();
// }
//
// class _QuoteNotificationSettingsScreenState extends ConsumerState<QuoteNotificationSettingsScreen> {
//   TimeOfDay? _startTime;
//   TimeOfDay? _endTime;
//   int _selectedIntervalHours = 1;
//
//   @override
//   Widget build(BuildContext context) {
//     final settingsAsync = ref.watch(notificationSettingsProvider('quotes'));
//     final notificationService = ref.read(notificationServiceProvider);
//     final quoteManager = ref.read(quoteNotificationManagerProvider);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Quote Notifications'),
//       ),
//       body: settingsAsync.when(
//         loading: () => const Center(child: CircularProgressIndicator()),
//         error: (error, stack) => Center(child: Text('Error: $error')),
//         data: (settings) {
//           _startTime = settings.startTime;
//           _endTime = settings.endTime;
//           _selectedIntervalHours = settings.intervalValue;
//
//           return SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Enable/Disable Switch with Test Button
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Enable Quotes Notifications',
//                       style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                             fontWeight: FontWeight.bold,
//                           ),
//                     ),
//                     Row(
//                       children: [
//                         IconButton(
//                           icon: const Icon(Icons.notifications_active),
//                           tooltip: 'Send test notification',
//                           onPressed: () async {
//                             await quoteManager.sendRandomQuoteNotification();
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(content: Text('Test notification sent')),
//                             );
//                           },
//                         ),
//                         Switch(
//                           value: settings.isActive,
//                           onChanged: (value) => _updateSettings(
//                             settings.copyWith(isActive: value),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//
//                 Column(
//                   children: [
//                     const Divider(height: 24),
//
//                     // Notification Interval
//                     buildSettingItem(
//                       context,
//                       title: 'Notification Interval',
//                       value: 'Every $_selectedIntervalHours hours',
//                       trailing: DropdownButton<int>(
//                         value: _selectedIntervalHours,
//                         items: [1, 2, 6, 12, 24].map((int value) {
//                           return DropdownMenuItem<int>(
//                             value: value,
//                             child: Text('$value hours'),
//                           );
//                         }).toList(),
//                         onChanged: (value) {
//                           setState(() => _selectedIntervalHours = value!);
//                           _updateSettings(
//                             settings.copyWith(
//                               intervalType: 'hours',
//                               intervalValue: value,
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//
//                     // Daily Time Range
//                     TimeRangePicker(
//                       startTime: _startTime,
//                       endTime: _endTime,
//                       onTimeRangeChanged: (timeRange) {
//                         setState(() {
//                           _startTime = timeRange.startTime;
//                           _endTime = timeRange.endTime;
//                         });
//
//                         final currentSettings = ref.read(notificationSettingsProvider('quotes')).value;
//
//                         _updateSettings(
//                           NotificationSettings(
//                             id: currentSettings?.id ?? 0,
//                             featureName: 'quotes',
//                             isActive: currentSettings?.isActive ?? true,
//                             intervalType: 'hours',
//                             intervalValue: _selectedIntervalHours,
//                             startTime: _startTime,
//                             endTime: _endTime,
//                             blockedDays: currentSettings?.blockedDays ?? const [],
//                             blockedDates: currentSettings?.blockedDates ?? const [],
//                             blockedMonths: currentSettings?.blockedMonths ?? const [],
//                             createdAt: currentSettings?.createdAt ?? DateTime.now(),
//                             updatedAt: DateTime.now(),
//                           ),
//                         );
//                       },
//                       featureName: 'quotes',
//                       ref: ref,
//                       settingsId: 'quotes',
//                     ),
//                     const Divider(height: 24),
//                     // Advanced Settings Expansion Tile
//                     ExpansionTile(
//                       title: Text(
//                         'Advanced Settings',
//                         style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                               fontWeight: FontWeight.bold,
//                             ),
//                       ),
//                       children: [
//                         // Days of week to block
//                         buildDaySelector(
//                           'Block Days',
//                           settings.blockedDays,
//                           context,
//                           (days) => _updateSettings(
//                             settings.copyWith(blockedDays: days),
//                           ),
//                         ),
//
//                         // Dates of month to block
//                         buildNumberSelector(
//                           'Block Dates (1-31)',
//                           settings.blockedDates,
//                           context,
//                           (dates) => _updateSettings(
//                             settings.copyWith(blockedDates: dates),
//                           ),
//                           max: 31,
//                         ),
//
//                         // Months to block
//                         buildNumberSelector(
//                           'Block Months',
//                           settings.blockedMonths,
//                           context,
//                           (months) => _updateSettings(
//                             settings.copyWith(blockedMonths: months),
//                           ),
//                           max: 12,
//                           labels: List.generate(12, (i) => DateFormat('MMM').format(DateTime(0, i + 1))),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Future<void> _updateSettings(NotificationSettings newSettings) async {
//     final service = ref.read(notificationSettingServiceProvider);
//     await service.saveSettings(newSettings);
//     ref.invalidate(notificationSettingsProvider('quotes'));
//   }
// }
//
// class NotificationSettingsColumn extends ConsumerStatefulWidget {
//   final String featureName;
//   final NotificationSettings initialSettings;
//   final ValueChanged<NotificationSettings> onSettingsChanged;
//
//   const NotificationSettingsColumn({
//     super.key,
//     required this.featureName,
//     required this.initialSettings,
//     required this.onSettingsChanged,
//   });
//
//   @override
//   ConsumerState<NotificationSettingsColumn> createState() => _NotificationSettingsColumnState();
// }
//
// class _NotificationSettingsColumnState extends ConsumerState<NotificationSettingsColumn> {
//   late int _selectedIntervalHours;
//   late TimeOfDay? _startTime;
//   late TimeOfDay? _endTime;
//
//   @override
//   void initState() {
//     super.initState();
//     _selectedIntervalHours = widget.initialSettings.intervalValue;
//     _startTime = widget.initialSettings.startTime;
//     _endTime = widget.initialSettings.endTime;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         const Divider(height: 24),
//
//         // Notification Interval
//         _buildSettingItem(
//           context,
//           title: 'Notification Interval',
//           value: 'Every $_selectedIntervalHours hours',
//           trailing: DropdownButton<int>(
//             value: _selectedIntervalHours,
//             items: [1, 2, 6, 12, 24].map((int value) {
//               return DropdownMenuItem<int>(
//                 value: value,
//                 child: Text('$value hours'),
//               );
//             }).toList(),
//             onChanged: (value) {
//               setState(() => _selectedIntervalHours = value!);
//               _updateSettings(
//                 widget.initialSettings.copyWith(
//                   intervalType: 'hours',
//                   intervalValue: value,
//                 ),
//               );
//             },
//           ),
//         ),
//
//         // Daily Time Range
//         TimeRangePicker(
//           startTime: _startTime,
//           endTime: _endTime,
//           onTimeRangeChanged: (timeRange) {
//             setState(() {
//               _startTime = timeRange.startTime;
//               _endTime = timeRange.endTime;
//             });
//             _updateSettings(
//               widget.initialSettings.copyWith(
//                 startTime: _startTime,
//                 endTime: _endTime,
//               ),
//             );
//           },
//           featureName: widget.featureName,
//           ref: ref,
//           settingsId: widget.featureName,
//         ),
//
//         const Divider(height: 24),
//
//         // Advanced Settings Expansion Tile
//         ExpansionTile(
//           title: Text(
//             'Advanced Settings',
//             style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//           ),
//           children: [
//             _buildDaySelector(
//               'Block Days',
//               widget.initialSettings.blockedDays,
//               context,
//               (days) => _updateSettings(
//                 widget.initialSettings.copyWith(blockedDays: days),
//               ),
//             ),
//             _buildNumberSelector(
//               'Block Dates (1-31)',
//               widget.initialSettings.blockedDates,
//               context,
//               (dates) => _updateSettings(
//                 widget.initialSettings.copyWith(blockedDates: dates),
//               ),
//               max: 31,
//             ),
//             _buildNumberSelector(
//               'Block Months',
//               widget.initialSettings.blockedMonths,
//               context,
//               (months) => _updateSettings(
//                 widget.initialSettings.copyWith(blockedMonths: months),
//               ),
//               max: 12,
//               labels: List.generate(12, (i) => DateFormat('MMM').format(DateTime(0, i + 1))),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
//   void _updateSettings(NotificationSettings newSettings) {
//     widget.onSettingsChanged(newSettings);
//   }
//
//   Widget _buildSettingItem(
//     BuildContext context, {
//     required String title,
//     required String value,
//     required Widget trailing,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(title, style: Theme.of(context).textTheme.bodyMedium),
//               const SizedBox(height: 4),
//               Text(
//                 value,
//                 style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                       color: Theme.of(context).hintColor,
//                     ),
//               ),
//             ],
//           ),
//           trailing,
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDaySelector(
//     String title,
//     List<int> selectedDays,
//     BuildContext context,
//     ValueChanged<List<int>> onChanged,
//   ) {
//     const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: Theme.of(context).textTheme.titleMedium),
//           Wrap(
//             spacing: 8,
//             children: List.generate(7, (index) {
//               final dayIndex = index + 1; // 1=Monday to 7=Sunday
//               return FilterChip(
//                 label: Text(days[index]),
//                 selected: selectedDays.contains(dayIndex),
//                 onSelected: (selected) {
//                   final newDays = List<int>.from(selectedDays);
//                   selected ? newDays.add(dayIndex) : newDays.remove(dayIndex);
//                   onChanged(newDays);
//                 },
//               );
//             }),
//           ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildNumberSelector(
//     String title,
//     List<int> selectedNumbers,
//     BuildContext context,
//     ValueChanged<List<int>> onChanged, {
//     required int max,
//     List<String>? labels,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: Theme.of(context).textTheme.titleMedium),
//           Wrap(
//             spacing: 8,
//             children: List.generate(max, (index) {
//               final number = index + 1;
//               return FilterChip(
//                 label: Text(labels?[index] ?? number.toString()),
//                 selected: selectedNumbers.contains(number),
//                 onSelected: (selected) {
//                   final newNumbers = List<int>.from(selectedNumbers);
//                   selected ? newNumbers.add(number) : newNumbers.remove(number);
//                   onChanged(newNumbers);
//                 },
//               );
//             }),
//           ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }
// }
//
// Widget buildSettingItem(
//   BuildContext context, {
//   required String title,
//   required String value,
//   required Widget trailing,
// }) {
//   return Padding(
//     padding: const EdgeInsets.symmetric(vertical: 8),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(title, style: Theme.of(context).textTheme.bodyMedium),
//             const SizedBox(height: 4),
//             Text(
//               value,
//               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                     color: Theme.of(context).hintColor,
//                   ),
//             ),
//           ],
//         ),
//         trailing,
//       ],
//     ),
//   );
// }
//
// Widget buildDaySelector(
//   String title,
//   List<int> selectedDays,
//   context,
//   Function(List<int>) onChanged,
// ) {
//   const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//
//   return Padding(
//     padding: const EdgeInsets.symmetric(horizontal: 16),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(title, style: Theme.of(context).textTheme.titleMedium),
//         Wrap(
//           spacing: 8,
//           children: List.generate(7, (index) {
//             final dayIndex = index + 1; // 1=Monday to 7=Sunday
//             return FilterChip(
//               label: Text(days[index]),
//               selected: selectedDays.contains(dayIndex),
//               onSelected: (selected) {
//                 final newDays = List<int>.from(selectedDays);
//                 selected ? newDays.add(dayIndex) : newDays.remove(dayIndex);
//                 onChanged(newDays);
//               },
//             );
//           }),
//         ),
//         const SizedBox(height: 16),
//       ],
//     ),
//   );
// }
//
// Widget buildNumberSelector(
//   String title,
//   List<int> selectedNumbers,
//   context,
//   Function(List<int>) onChanged, {
//   required int max,
//   List<String>? labels,
// }) {
//   return Padding(
//     padding: const EdgeInsets.symmetric(horizontal: 16),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(title, style: Theme.of(context).textTheme.titleMedium),
//         Wrap(
//           spacing: 8,
//           children: List.generate(max, (index) {
//             final number = index + 1;
//             return FilterChip(
//               label: Text(labels?[index] ?? number.toString()),
//               selected: selectedNumbers.contains(number),
//               onSelected: (selected) {
//                 final newNumbers = List<int>.from(selectedNumbers);
//                 selected ? newNumbers.add(number) : newNumbers.remove(number);
//                 onChanged(newNumbers);
//               },
//             );
//           }),
//         ),
//         const SizedBox(height: 16),
//       ],
//     ),
//   );
// }
//
// class TimeRangePicker extends ConsumerWidget {
//   final TimeOfDay? startTime;
//   final TimeOfDay? endTime;
//   final ValueChanged<TimeRange> onTimeRangeChanged;
//   final String featureName;
//   final WidgetRef ref;
//   final String settingsId;
//
//   const TimeRangePicker({
//     super.key,
//     required this.startTime,
//     required this.endTime,
//     required this.onTimeRangeChanged,
//     required this.featureName,
//     required this.ref,
//     required this.settingsId,
//   });
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           'Daily Time Range',
//           style: Theme.of(context).textTheme.bodyMedium,
//         ),
//         Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               _getTimeRangeText(context),
//               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                     color: Theme.of(context).hintColor,
//                   ),
//             ),
//             IconButton(
//               icon: const Icon(Icons.access_time),
//               tooltip: 'Set start time',
//               onPressed: () => _selectTime(context, isStartTime: true),
//             ),
//             IconButton(
//               icon: const Icon(Icons.access_time),
//               tooltip: 'Set end time',
//               onPressed: () => _selectTime(context, isStartTime: false),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
//   String _getTimeRangeText(BuildContext context) {
//     if (startTime == null && endTime == null) return 'Not set';
//     if (startTime == null) return 'Until ${endTime!.format(context)}';
//     if (endTime == null) return 'From ${startTime!.format(context)}';
//     return '${startTime!.format(context)} - ${endTime!.format(context)}';
//   }
//
//   Future<void> _selectTime(BuildContext context, {required bool isStartTime}) async {
//     final initialTime = isStartTime ? startTime : endTime;
//     final time = await showTimePicker(
//       context: context,
//       initialTime: initialTime ?? TimeOfDay.now(),
//     );
//
//     if (time != null) {
//       final newStartTime = isStartTime ? time : startTime;
//       final newEndTime = isStartTime ? endTime : time;
//
//       onTimeRangeChanged(TimeRange(
//         startTime: newStartTime,
//         endTime: newEndTime,
//       ));
//     }
//   }
// }
//
// class TimeRange {
//   final TimeOfDay? startTime;
//   final TimeOfDay? endTime;
//
//   TimeRange({required this.startTime, required this.endTime});
// }
