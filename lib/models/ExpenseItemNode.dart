import 'expense_category_data.dart';

class ExpenseItemNode {
  final int id;
  final String name;
  final String date;
  final double price;
  final String inOrOut;
  final String? notes;
  final int? closingId;

  ExpenseItemNode({
    required this.id,
    required this.name,
    required this.date,
    required this.price,
    required this.inOrOut,
    this.notes,
    this.closingId,
  });
}

class ExpenseCategoryNode {
  final int id;
  final String title;
  final String? color;
  final int? iconCode;
  final String? iconFontFamily;
  final int hidden;
  final double totalIn;
  final double totalOut;
  final List<ExpenseItemNode> items;

  ExpenseCategoryNode({
    required this.id,
    required this.title,
    this.color,
    this.iconCode,
    this.iconFontFamily,
    required this.hidden,
    required this.totalIn,
    required this.totalOut,
    required this.items,
  });
}

extension ExpenseItemNodeMapper on ExpenseItemNode {
  ExpenseItemData toData() => ExpenseItemData(
        id: id,
        name: name,
        date: date,
        price: price,
        inOrOut: inOrOut,
        notes: notes,
        closingId: closingId,
      );
}
