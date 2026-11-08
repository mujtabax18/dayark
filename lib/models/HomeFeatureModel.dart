import 'package:flutter/material.dart';
import 'package:metersystem/utlis/app_router.dart';

class HomeFeatureModel {
  final int id;
  final String title;
  final String route;
  final int iconCode;
  final int position;
  final int colorCode;

  const HomeFeatureModel({
    required this.id,
    required this.title,
    required this.route,
    required this.iconCode,
    required this.position,
    required this.colorCode,
  });

  factory HomeFeatureModel.fromMap(Map<String, dynamic> map) {
    final int id = map['id'];
    final int position = map['position'];

    final feature = HomeFeatureModel.defaultFeaturesById[id];
    if (feature == null) {
      throw Exception("Unknown feature ID: $id");
    }

    return HomeFeatureModel(
      id: id,
      title: feature.title,
      route: feature.route,
      iconCode: feature.iconCode,
      position: position,
      colorCode: feature.colorCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'position': position,
    };
  }

  HomeFeatureModel copyWith({
    int? id,
    String? title,
    String? route,
    int? iconCode,
    int? position,
    int? colorCode,
  }) {
    return HomeFeatureModel(
      id: id ?? this.id,
      title: title ?? this.title,
      route: route ?? this.route,
      iconCode: iconCode ?? this.iconCode,
      position: position ?? this.position,
      colorCode: colorCode ?? this.colorCode,
    );
  }

  // 🔹 Hardcoded list of all features
  static List<HomeFeatureModel> defaultFeatures = [
    HomeFeatureModel(
      id: 1,
      title: "Meters",
      route: RoutesStr.meterList,
      iconCode: 0,
      position: 0,
      colorCode: 0xFF4F46E5,
    ),
    HomeFeatureModel(
      id: 2,
      title: "Grocery",
      route: RoutesStr.grocery,
      iconCode: 1,
      position: 1,
      colorCode: 0xFF22C55E,
    ),
    HomeFeatureModel(
      id: 3,
      title: "Expenses",
      route: RoutesStr.expense,
      iconCode: 2,
      position: 2,
      colorCode: 0xFFF43F5E,
    ),
    HomeFeatureModel(
      id: 4,
      title: "Settings",
      route: RoutesStr.backup,
      iconCode: 3,
      position: 3,
      colorCode: 0xFF6B7280,
    ),
    HomeFeatureModel(
      id: 5,
      title: "Diary",
      route: RoutesStr.moodTracker,
      iconCode: 4,
      position: 4,
      colorCode: 0xFFEC4899,
    ),
    HomeFeatureModel(
      id: 6,
      title: "Habits",
      route: RoutesStr.habits,
      iconCode: 5,
      position: 5,
      colorCode: 0xFF8B5CF6,
    ),
    HomeFeatureModel(
      id: 7,
      title: "Quotations",
      route: RoutesStr.quotes,
      iconCode: 6,
      position: 6,
      colorCode: 0xFF3B82F6,
    ),
    HomeFeatureModel(
      id: 8,
      title: "Invoices",
      route: RoutesStr.invoices,
      iconCode: 7,
      position: 7,
      colorCode: 0xFF6366F1,
    ),
    HomeFeatureModel(
      id: 9,
      title: "Loans",
      route: RoutesStr.loans,
      iconCode: 8,
      position: 8,
      colorCode: 0xFF0891B2,
    ),
    HomeFeatureModel(
      id: 10,
      title: "Photo Editor",
      route: RoutesStr.multimedia,
      iconCode: 9,
      position: 9,
      colorCode: 0xFFE11D48,
    ),

    // 🆕 PILL REMINDER FEATURE
    HomeFeatureModel(
      id: 11,
      title: "Pill Reminder",
      route: RoutesStr.pillReminder,
      iconCode: 10,
      position: 10,
      colorCode: 0xFF14B8A6, // Teal (health/medical)
    ),
    HomeFeatureModel(
      id: 12,
      title: "DocScanner",
      route: RoutesStr.scannerGallery,
      iconCode: 11,
      position: 11,
      colorCode: 0xFF0EA5E9, // Teal (health/medical)
    ),
    HomeFeatureModel(
      id: 13,
      title: "Tutorials",
      route: RoutesStr.tutorials,
      iconCode: 12,
      position: 12,
      colorCode: 0xFF0F766E,
    ),
    HomeFeatureModel(
      id: 14,
      title: "Life Archives",
      route: RoutesStr.familyTrees,
      iconCode: 13,
      position: 13,
      colorCode: 0xFF7C3AED,
    ),
  ];

  static final Map<int, HomeFeatureModel> defaultFeaturesById =
      Map.fromEntries(defaultFeatures.map((f) => MapEntry(f.id, f)));
}

const List<IconData> homeIconList = [
  Icons.electrical_services, // 0
  Icons.shopping_cart, // 1
  Icons.attach_money, // 2
  Icons.settings, // 3
  Icons.menu_book, // 4
  Icons.star, // 5
  Icons.format_quote, // 6
  Icons.receipt_long, // 7
  Icons.account_balance_wallet, // 8
  Icons.perm_media, // 9
  Icons.medication, // 10 🆕 Pill Reminder
  Icons.document_scanner, // 11
  Icons.school_outlined, // 12 Tutorials
  Icons.account_tree_outlined, // 13 Family Trees
];
