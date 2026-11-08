// // lib/services/quote_notification_manager.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../screens/habitTracker/controller/habit_tracker_controller.dart';
// import '../NotificationService.dart';
//
// class QuoteNotificationManager {
//   final Ref<Object?> ref; // Explicitly specify the Ref type
//   // final NotificationService notificationService;
//
//   QuoteNotificationManager(this.ref, this.notificationService);
//
//   Future<void> sendRandomQuoteNotification() async {
//     final controller = ref.read(habitTrackerControllerProvider.notifier);
//
//     // Try to get a random unused quote
//     var quote = await controller.getRandomUnusedQuotation();
//
//     if (quote == null) {
//       // If no unused quotes, reset all and try again
//       await controller.resetAllQuotations();
//       quote = await controller.getRandomUnusedQuotation();
//
//       if (quote == null) return; // No quotes available at all
//     }
//
//     // Mark the quote as used
//     await controller.markQuotationAsUsed(quote.id!);
//
//     // Show notification
//     await notificationService.showNotification(
//       id: quote.id!,
//       title: 'Motivational Quote',
//       body: quote.text,
//     );
//   }
//
//   Future<void> scheduleDailyQuoteNotification(TimeOfDay time) async {
//     // Cancel any existing scheduled notifications
//     await notificationService.cancelAllNotifications();
//
//     // Schedule new notification
//     await notificationService.scheduleDailyNotification(
//       id: 0, // Use a fixed ID for the daily notification
//       time: time,
//       title: 'Daily Motivation',
//       body: 'Time for your daily motivational quote!',
//     );
//   }
// }
