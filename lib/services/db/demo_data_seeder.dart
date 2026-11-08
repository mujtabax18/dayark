import 'drift_database.dart';

class DemoSeedResult {
  const DemoSeedResult({required this.insertedRecords});

  final int insertedRecords;
  bool get alreadyPresent => insertedRecords == 0;
}

class DemoDataSeeder {
  static const _demoPrefix = '[Demo]';

  static Future<DemoSeedResult> seed(Database db) async {
    var inserted = 0;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final today = _dateOnly(now);

    await db.transaction((txn) async {
      final meterExists = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM meters WHERE name = ?',
            ['$_demoPrefix Home Electricity'],
          )) ??
          0;
      if (meterExists == 0) {
        final meterId = await txn.insert('meters', {
          'name': '$_demoPrefix Home Electricity',
          'number': 'DEMO-001',
          'baseline': 1250,
          'meter_type': 'electricity',
          'provider': 'Demo Provider',
          'location': 'Main House',
          'consumer_name': 'Demo User',
          'reference_number': '00000000000000',
          'tariff_category': 'residential',
          'unit_label': 'kWh',
          'icon_key': 'electricity',
          'color_value': 4284246976,
          'reading_frequency': 'weekly',
          'custom_interval_days': 7,
          'billing_cycle_day': 1,
          'target_units': 250,
          'target_budget': 15000,
          'unit_rate': 55,
          'fixed_charges': 500,
          'notes': 'Safe sample meter. Delete it at any time.',
          'is_active': 1,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        await txn.insert('readings', {
          'value': 1378,
          'date': nowIso,
          'meter_id': meterId,
          'note': 'Demo current reading',
          'estimated_cost': 7540,
          'source': 'manual',
          'reading_kind': 'normal',
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        inserted += 2;
      }

      final groceryExists = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM grocery_titles WHERE title = ?',
            ['$_demoPrefix Weekly Grocery'],
          )) ??
          0;
      if (groceryExists == 0) {
        final groceryId = await txn.insert('grocery_titles', {
          'title': '$_demoPrefix Weekly Grocery',
          'description': 'Sample plan for learning grocery features.',
          'plan_date': today,
          'plan_type': 'weekly',
          'icon_key': 'basket-shopping',
          'color_value': 4281236786,
          'alert_enabled': 0,
          'status': 'active',
          'created_at': nowIso,
          'updated_at': nowIso,
          'position': 0,
        });
        for (final item in const [
          ('Milk', 2.0, 'liter'),
          ('Bread', 1.0, 'item'),
          ('Vegetables', 3.0, 'kg'),
        ]) {
          await txn.insert('grocery_items', {
            'name': '$_demoPrefix ${item.$1}',
            'status': 0,
            'date': nowIso,
            'grocery_id': groceryId,
            'item_type': 'general',
            'quantity': item.$2,
            'unit': item.$3,
            'notes': 'Demo grocery item',
            'priority': 'normal',
            'alert_enabled': 0,
            'created_at': nowIso,
            'updated_at': nowIso,
          });
        }
        inserted += 4;
      }

      final expenseExists = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM expense_titles WHERE title = ? AND deleted_at IS NULL',
            ['$_demoPrefix Household'],
          )) ??
          0;
      if (expenseExists == 0) {
        final expenseId = await txn.insert('expense_titles', {
          'uuid': 'demo-expense-category-household',
          'title': '$_demoPrefix Household',
          'description': 'Sample expense category',
          'position': 0,
          'color': '#6366F1',
          'icon_code': 57895,
          'icon_font_family': 'MaterialIcons',
          'hidden': 0,
          'creation_date': nowIso,
          'updatation_date': nowIso,
        });
        await txn.insert('expense_items', {
          'uuid': 'demo-expense-item-utility',
          'name': '$_demoPrefix Utility Bill',
          'date': nowIso,
          'expense_id': expenseId,
          'price': 6500,
          'in_or_out': 'Out',
          'notes': 'Sample monthly expense',
          'creation_date': nowIso,
          'updatation_date': nowIso,
        });
        inserted += 2;
      }

      final habitExists = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM habits WHERE title = ?',
            ['$_demoPrefix Drink Water'],
          )) ??
          0;
      if (habitExists == 0) {
        await txn.insert('habits', {
          'title': '$_demoPrefix Drink Water',
          'description': 'Complete this sample habit before the daily deadline.',
          'created_at': nowIso,
          'is_active': 1,
          'category': 'Health',
          'reason': 'Build a healthy routine',
          'cue': 'After breakfast',
          'reward': 'Mark the daily goal complete',
          'difficulty': 'easy',
          'color_value': 4280391411,
          'icon_code': 59517,
          'target_value': 8,
          'target_unit': 'glasses',
          'deadline_hour': 23,
          'deadline_minute': 59,
          'grace_minutes': 0,
          'repeat_days': '1,2,3,4,5,6,7',
          'updated_at': nowIso,
        });
        inserted++;
      }

      final quoteExists = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM quotations WHERE text = ?',
            ['Small steps build strong routines.'],
          )) ??
          0;
      if (quoteExists == 0) {
        await txn.insert('quotations', {
          'text': 'Small steps build strong routines.',
          'author': 'Demo Guide',
          'category': 'Motivation',
          'source': 'demo',
          'is_favorite': 1,
          'is_used': 0,
          'usage_count': 0,
          'background_style': 'sunrise',
          'text_align': 'center',
          'font_size': 30,
          'show_author': 1,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        inserted++;
      }

      final businessExists = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM invoice_business_profiles WHERE id = ?',
            ['demo-business'],
          )) ??
          0;
      if (businessExists == 0) {
        await txn.insert('invoice_business_profiles', {
          'id': 'demo-business',
          'name': '$_demoPrefix My Business',
          'address': 'Demo business address',
          'email': 'demo@example.com',
          'phone': '03000000000',
          'templateStyle': 'modern',
          'accentColorValue': 4280640491,
          'backgroundOpacity': 0.06,
          'currencySymbol': 'PKR',
          'defaultTaxRate': 0,
          'paymentInfo': 'Demo bank or mobile wallet details',
          'terms': 'Payment is due within 7 days.',
          'customerNote': 'Thank you for your business.',
          'footerText': 'Generated with Household Manager',
          'isDefault': 0,
          'createdAt': nowIso,
          'updatedAt': nowIso,
        });
        inserted++;
      }

      final customerExists = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM invoice_customers WHERE id = ?',
            ['demo-customer'],
          )) ??
          0;
      if (customerExists == 0) {
        await txn.insert('invoice_customers', {
          'id': 'demo-customer',
          'name': '$_demoPrefix Customer',
          'company': 'Demo Company',
          'address': 'Demo customer address',
          'email': 'customer@example.com',
          'phone': '03000000001',
          'notes': 'Safe sample customer',
          'usageCount': 0,
          'createdAt': nowIso,
          'updatedAt': nowIso,
        });
        inserted++;
      }
    });

    return DemoSeedResult(insertedRecords: inserted);
  }

  static String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
