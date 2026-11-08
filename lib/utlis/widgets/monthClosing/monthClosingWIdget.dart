// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
//
// import '../../../core/theme/app_colors.dart';
// import '../../../core/theme/theme_x.dart';
// import 'monthClosingController.dart';
//
// class MonthClosingWidget extends ConsumerWidget {
//   final String tableName;
//
//   const MonthClosingWidget({
//     Key? key,
//     required this.tableName,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final neutral = context.themeColors.neutral;
//
//     return GestureDetector(
//       onTap: () => handleMonthClosing(context, ref, tableName),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         decoration: BoxDecoration(
//           color: AppColors.warning.withOpacity(0.15),
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(
//             color: AppColors.warning.withOpacity(0.4),
//           ),
//         ),
//         child: Text(
//           'Close Month',
//           style: TextStyle(
//             color: neutral.textPrimary,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// /// ─────────────────────────────────────────────
// /// Month closing handler
// // Future<void> handleMonthClosing(
// //   BuildContext context,
// //   WidgetRef ref,
// //   String tableName,
// // ) async {
// //   final closingData = await showClosingDialog(context);
// //
// //   if (closingData != null) {
// //     await ref.read(monthClosingProvider.notifier).closeMonth(
// //           closingData['title']!,
// //           closingData['description']!,
// //           tableName,
// //         );
// //   }
// // }
//
// /// ─────────────────────────────────────────────
// /// Closing dialog
// Future<Map<String, String>?> showClosingDialog(BuildContext context) {
//   final neutral = context.themeColors.neutral;
//
//   final titleController = TextEditingController();
//   final descriptionController = TextEditingController();
//
//   return showDialog<Map<String, String>>(
//     context: context,
//     builder: (_) => AlertDialog(
//       backgroundColor: neutral.card,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//       ),
//       title: Text(
//         'Close Month',
//         style: TextStyle(
//           color: neutral.textPrimary,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           _inputField(
//             neutral,
//             controller: titleController,
//             label: 'Title',
//           ),
//           const SizedBox(height: 12),
//           _inputField(
//             neutral,
//             controller: descriptionController,
//             label: 'Description',
//             maxLines: 3,
//           ),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: Text(
//             'Cancel',
//             style: TextStyle(color: neutral.textSecondary),
//           ),
//         ),
//         ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: AppColors.warning,
//             foregroundColor: neutral.textPrimaryNot,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           onPressed: () {
//             final title = titleController.text.trim();
//             final description = descriptionController.text.trim();
//
//             if (title.isEmpty) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   backgroundColor: AppColors.danger,
//                   content: Text(
//                     'Title cannot be empty',
//                     style: TextStyle(color: neutral.textPrimaryNot),
//                   ),
//                 ),
//               );
//               return;
//             }
//
//             Navigator.pop(context, {
//               'title': title,
//               'description': description,
//             });
//           },
//           child: const Text('Confirm'),
//         ),
//       ],
//     ),
//   );
// }
//
// /// ─────────────────────────────────────────────
// /// Input helper
// Widget _inputField(
//   neutral, {
//   required TextEditingController controller,
//   required String label,
//   int maxLines = 1,
// }) {
//   return TextField(
//     controller: controller,
//     maxLines: maxLines,
//     style: TextStyle(color: neutral.textPrimary),
//     decoration: InputDecoration(
//       labelText: label,
//       labelStyle: TextStyle(color: neutral.textSecondary),
//       filled: true,
//       fillColor: neutral.section,
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: BorderSide(color: neutral.divider),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: BorderSide(color: neutral.divider),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: BorderSide(
//           color: AppColors.warning,
//           width: 1.5,
//         ),
//       ),
//     ),
//   );
// }
