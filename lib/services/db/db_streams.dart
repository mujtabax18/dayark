import 'dart:async';

import '../../models/meter.dart';

class DbStreams {
  static final StreamController<List<Meter>> meterStreamController =
      StreamController.broadcast();

  static final StreamController<List<Reading>> readingStreamController =
      StreamController.broadcast();

  static void dispose() {
    meterStreamController.close();
    readingStreamController.close();
  }
}
