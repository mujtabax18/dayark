import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseItemFilterClosingIdNotifier extends Notifier<String> {
  @override
  String build() => 'latest';

  void setExpenseItemFilterClosingId(String value) => state = value;
}

class ExpenseItemFilterStartDateNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setExpenseItemFilterStartDate(String? value) => state = value;
}

class ExpenseItemFilterEndDate extends Notifier<String?> {
  @override
  String? build() => null;

  void setExpenseItemFilterEndDate(String? value) => state = value;
}

class ShowHiddenExpenseCategoriesNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setValue(bool value) => state = value;
}
