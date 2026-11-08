import '../../../services/db/drift_database.dart';

import '../../../models/quotation.dart';
import '../../../services/database_service.dart';

part 'parts/quotation_service_quotation_import_result.dart';
part 'parts/quotation_service_quotation_service.dart';

enum QuotationSort {
  newest,
  mostUsed,
  alphabetical,
}

