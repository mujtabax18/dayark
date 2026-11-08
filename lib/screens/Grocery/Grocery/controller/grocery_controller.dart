import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metersystem/services/database_service.dart';
import 'package:metersystem/services/localDatabaseServices/GroceryService.dart';

final databaseService = DatabaseService();

final dbServiceProvider = Provider<GroceryService>((ref) {
  return GroceryService(databaseService);
});

final groceryDashboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(dbServiceProvider).getDashboardSummary();
});

final groceryTitlesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(dbServiceProvider).getGroceryTitles();
});

final groceryPlanProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((ref, groceryId) async {
  return ref.read(dbServiceProvider).getGroceryPlan(groceryId);
});

final groceryItemsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, groceryId) async {
  return ref.read(dbServiceProvider).getGroceryItems(groceryId);
});

final reusableGroceryItemsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, groceryId) async {
  return ref.read(dbServiceProvider).getReusableGroceryItems(groceryId);
});

final householdChoresProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(dbServiceProvider).getHouseholdChores();
});

final householdAlertsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(dbServiceProvider).getHouseholdAlerts();
});

final householdActivityProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    ({String? entityType, int? entityId})>((ref, filter) async {
  return ref.read(dbServiceProvider).getActivityLogs(
        entityType: filter.entityType,
        entityId: filter.entityId,
      );
});

void refreshGroceryDashboard(WidgetRef ref, {int? groceryId}) {
  ref.invalidate(groceryDashboardProvider);
  ref.invalidate(groceryTitlesProvider);
  ref.invalidate(householdChoresProvider);
  ref.invalidate(householdAlertsProvider);
  if (groceryId != null) {
    ref.invalidate(groceryPlanProvider(groceryId));
    ref.invalidate(groceryItemsProvider(groceryId));
    ref.invalidate(reusableGroceryItemsProvider(groceryId));
  }
}

final deleteGroceryTitleProvider =
    Provider.family<Future<void>, int>((ref, titleId) async {
  await ref.read(dbServiceProvider).deleteGroceryTitle(titleId);
  ref.invalidate(groceryDashboardProvider);
  ref.invalidate(groceryTitlesProvider);
  ref.invalidate(householdAlertsProvider);
});

final deleteGroceryItemProvider =
    Provider.family<Future<void>, ({int itemId, int groceryId})>(
        (ref, input) async {
  await ref.read(dbServiceProvider).deleteGroceryItem(input.itemId);
  ref.invalidate(groceryDashboardProvider);
  ref.invalidate(groceryTitlesProvider);
  ref.invalidate(groceryPlanProvider(input.groceryId));
  ref.invalidate(groceryItemsProvider(input.groceryId));
  ref.invalidate(reusableGroceryItemsProvider(input.groceryId));
  ref.invalidate(householdAlertsProvider);
});
