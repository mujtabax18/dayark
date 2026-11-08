import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/quotation.dart';
import '../../quotation/controller/quotation_controller.dart';

final homeQuoteProvider = FutureProvider<Quotation?>((ref) {
  return ref.watch(quotationServiceProvider).getRandom();
});
