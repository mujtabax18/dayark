import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../models/meter.dart';
import '../../../../services/database_service.dart';
import '../../../../services/localDatabaseServices/MeterService.dart';

final meterServiceProvider = Provider<MeterService>((ref) {
  return MeterService(ref.watch(databaseServiceProvider));
});

final meterDataRevisionProvider = StateProvider<int>((ref) => 0);

class MeterNotifier extends StateNotifier<List<Meter>> {
  final MeterService _service;
  final void Function() _onMeterDataChanged;

  MeterNotifier(this._service, this._onMeterDataChanged) : super(const []) {
    loadMeters();
  }

  Future<void> loadMeters() async {
    state = await _service.getAllMeters();
  }

  Future<Meter> addMeter(Meter meter) async {
    final id = await _service.addMeter(meter);
    await loadMeters();
    _notifyMeterDataChanged();
    return meter.copyWith(id: id);
  }

  Future<void> updateMeter(Meter meter) async {
    await _service.updateMeter(meter);
    await loadMeters();
    _notifyMeterDataChanged();
  }

  Future<void> deleteMeter(int? id) async {
    await _service.deleteMeter(id);
    await loadMeters();
    _notifyMeterDataChanged();
  }

  Future<void> toggleMeterStatus(Meter meter) async {
    await updateMeter(meter.copyWith(isActive: !meter.isActive));
  }

  /// Compatibility method for code that still calls the old API.
  Future<void> editMeterName(int? id, String? number) async {
    if (id == null) return;
    await _service.updateMeterNumber(id, number);
    await loadMeters();
    _notifyMeterDataChanged();
  }

  void _notifyMeterDataChanged() => _onMeterDataChanged();
}

final meterProvider = StateNotifierProvider<MeterNotifier, List<Meter>>(
  (ref) => MeterNotifier(
    ref.watch(meterServiceProvider),
    () {
      final revision = ref.read(meterDataRevisionProvider.notifier);
      revision.state = revision.state + 1;
    },
  ),
);

List<Reading> sortMeterReadingsNewestFirst(List<Reading> readings) {
  final sorted = List<Reading>.from(readings)
    ..sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
  return List<Reading>.unmodifiable(sorted);
}

Reading? meterBaselineReading(
  Meter meter,
  List<Reading> readings, {
  MeterBaselineAnchor? baselineAnchor,
}) {
  if (meter.baseline == null || readings.isEmpty) return null;

  final sorted = sortMeterReadingsNewestFirst(readings);
  if (baselineAnchor?.readingId != null) {
    for (final reading in sorted) {
      if (reading.id == baselineAnchor!.readingId) return reading;
    }
  }

  const tolerance = 0.000001;
  if (baselineAnchor != null) {
    for (final reading in sorted) {
      final sameDate = reading.date.isAtSameMomentAs(baselineAnchor.date);
      final sameValue = (reading.value - baselineAnchor.value).abs() <= tolerance;
      if (sameDate && sameValue) return reading;
    }
  }

  for (final reading in sorted) {
    if ((reading.value - meter.baseline!).abs() <= tolerance) return reading;
  }
  return null;
}

bool isMeterBaselineReading(
  Meter meter,
  List<Reading> readings,
  Reading reading, {
  MeterBaselineAnchor? baselineAnchor,
}) {
  final baselineReading = meterBaselineReading(
    meter,
    readings,
    baselineAnchor: baselineAnchor,
  );
  if (baselineReading == null) return false;
  if (baselineReading.id != null && reading.id != null) {
    return baselineReading.id == reading.id;
  }
  return baselineReading.date.isAtSameMomentAs(reading.date) &&
      (baselineReading.value - reading.value).abs() <= 0.000001;
}

DateTime meterBillingCycleStart(Meter meter, DateTime reference) {
  final configuredDay = meter.billingCycleDay.clamp(1, 28).toInt();
  final currentMonthStart = DateTime(
    reference.year,
    reference.month,
    configuredDay,
  );
  if (!currentMonthStart.isAfter(reference)) return currentMonthStart;
  return DateTime(reference.year, reference.month - 1, configuredDay);
}

DateTime? meterBaselineDate(
  Meter meter,
  List<Reading> readings, {
  MeterBaselineAnchor? baselineAnchor,
}) {
  if (meter.baseline == null) return null;
  if (baselineAnchor != null) return baselineAnchor.date;

  final baselineReading = meterBaselineReading(meter, readings);
  if (baselineReading != null) return baselineReading.date;

  final sorted = sortMeterReadingsNewestFirst(readings);
  final reference = sorted.isEmpty ? DateTime.now() : sorted.first.date;
  return meterBillingCycleStart(meter, reference);
}

/// Returns readings that belong to the active bill cycle.
///
/// The cycle starts at the exact dated reading selected as the baseline. Older
/// readings remain in history but do not affect the current month projection,
/// usage, or costing.
List<Reading> readingsForCurrentBaseline(
  Meter meter,
  List<Reading> readings, {
  MeterBaselineAnchor? baselineAnchor,
}) {
  final sorted = sortMeterReadingsNewestFirst(readings);
  if (sorted.isEmpty || meter.baseline == null) return sorted;

  final start = meterBaselineDate(
    meter,
    sorted,
    baselineAnchor: baselineAnchor,
  );
  if (start == null) return sorted;

  return List<Reading>.unmodifiable(
    sorted.where((reading) => !reading.date.isBefore(start)),
  );
}

Reading? latestReadingForCurrentBaseline(
  Meter meter,
  List<Reading> readings, {
  MeterBaselineAnchor? baselineAnchor,
}) {
  final current = readingsForCurrentBaseline(
    meter,
    readings,
    baselineAnchor: baselineAnchor,
  );
  return current.isEmpty ? null : current.first;
}

double meterUnitsFromBaseline(
  Meter meter,
  List<Reading> readings, {
  MeterBaselineAnchor? baselineAnchor,
}) {
  if (meter.baseline == null || readings.isEmpty) return 0;

  final latest = latestReadingForCurrentBaseline(
    meter,
    readings,
    baselineAnchor: baselineAnchor,
  );
  if (latest == null) return 0;

  return (latest.value - meter.baseline!)
      .clamp(0, double.infinity)
      .toDouble();
}

double meterCostFromBaseline({
  required Meter meter,
  required List<Reading> readings,
  List<MeterTariffSlab> slabs = const [],
  MeterBaselineAnchor? baselineAnchor,
}) {
  if (meter.baseline == null || readings.isEmpty) return 0;
  final currentReadings = readingsForCurrentBaseline(
    meter,
    readings,
    baselineAnchor: baselineAnchor,
  );
  if (currentReadings.isEmpty) return 0;

  return MeterInsights.calculateCost(
    units: meterUnitsFromBaseline(
      meter,
      currentReadings,
      baselineAnchor: baselineAnchor,
    ),
    meter: meter,
    slabs: slabs,
  );
}

MeterInsights meterInsightsForCurrentBaseline({
  required Meter meter,
  required List<Reading> readings,
  List<MeterTariffSlab> slabs = const [],
  MeterBaselineAnchor? baselineAnchor,
}) {
  return MeterInsights.calculate(
    meter: meter,
    readings: readingsForCurrentBaseline(
      meter,
      readings,
      baselineAnchor: baselineAnchor,
    ),
    slabs: slabs,
  );
}

/// Projects usage to the end of the exact monthly bill cycle that starts at
/// the selected baseline reading date.
///
/// Units are always `latest value - active baseline`. The elapsed time comes
/// from reading dates, so inserting an older reading cannot make the app treat
/// it as the latest reading or as a meter replacement.
double meterProjectedMonthUsage({
  required Meter meter,
  required List<Reading> readings,
  MeterBaselineAnchor? baselineAnchor,
}) {
  final baseline = meter.baseline;
  if (baseline == null) return 0;

  final currentReadings = readingsForCurrentBaseline(
    meter,
    readings,
    baselineAnchor: baselineAnchor,
  );
  if (currentReadings.isEmpty) return 0;

  final latest = currentReadings.first;
  final currentUnits = (latest.value - baseline)
      .clamp(0, double.infinity)
      .toDouble();
  if (currentUnits <= 0) return 0;

  final cycleStart = meterBaselineDate(
    meter,
    readings,
    baselineAnchor: baselineAnchor,
  );
  if (cycleStart == null || !latest.date.isAfter(cycleStart)) {
    return currentUnits;
  }

  final cycleEnd = _addOneMonthClamped(cycleStart);
  if (!latest.date.isBefore(cycleEnd)) return currentUnits;

  var elapsedDays = latest.date.difference(cycleStart).inMinutes / 1440.0;
  if (elapsedDays < 1) elapsedDays = 1;

  final cycleDays = cycleEnd.difference(cycleStart).inMinutes / 1440.0;
  if (cycleDays <= 0) return currentUnits;

  final projected = (currentUnits / elapsedDays) * cycleDays;
  return projected < currentUnits ? currentUnits : projected;
}

DateTime _addOneMonthClamped(DateTime value) {
  final firstOfNextMonth = DateTime(value.year, value.month + 1, 1);
  final firstOfFollowingMonth = DateTime(value.year, value.month + 2, 1);
  final lastDayOfNextMonth =
      firstOfFollowingMonth.subtract(const Duration(days: 1)).day;
  final day = value.day > lastDayOfNextMonth ? lastDayOfNextMonth : value.day;
  return DateTime(
    firstOfNextMonth.year,
    firstOfNextMonth.month,
    day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

class ReadingDateNeighbors {
  final Reading? previous;
  final Reading? next;

  const ReadingDateNeighbors({this.previous, this.next});
}

ReadingDateNeighbors meterReadingNeighbors({
  required List<Reading> readings,
  required DateTime date,
  int? excludingReadingId,
}) {
  final sorted = readings
      .where(
        (reading) => excludingReadingId == null || reading.id != excludingReadingId,
      )
      .toList()
    ..sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

  Reading? previous;
  Reading? next;
  for (final reading in sorted) {
    if (!reading.date.isAfter(date)) {
      previous = reading;
      continue;
    }
    next = reading;
    break;
  }
  return ReadingDateNeighbors(previous: previous, next: next);
}

final meterReadingsOverviewProvider =
    FutureProvider.autoDispose<Map<int, List<Reading>>>((ref) async {
  ref.watch(meterDataRevisionProvider);
  final meters = ref.watch(meterProvider);
  final ids = meters.map((meter) => meter.id).whereType<int>();
  return ref.watch(meterServiceProvider).getReadingsForMeters(ids);
});

final meterBaselineAnchorsOverviewProvider =
    FutureProvider.autoDispose<Map<int, MeterBaselineAnchor>>((ref) async {
  ref.watch(meterDataRevisionProvider);
  final meters = ref.watch(meterProvider);
  final ids = meters.map((meter) => meter.id).whereType<int>();
  return ref.watch(meterServiceProvider).getBaselineAnchorsForMeters(ids);
});

final meterTariffSlabsOverviewProvider =
    FutureProvider.autoDispose<Map<int, List<MeterTariffSlab>>>((ref) async {
  ref.watch(meterDataRevisionProvider);
  final meters = ref.watch(meterProvider);
  final ids = meters.map((meter) => meter.id).whereType<int>();
  return ref.watch(meterServiceProvider).getTariffSlabsForMeters(ids);
});

final meterTariffSlabsProvider = FutureProvider.autoDispose
    .family<List<MeterTariffSlab>, int>((ref, meterId) async {
  ref.watch(meterDataRevisionProvider);
  return ref.watch(meterServiceProvider).getTariffSlabs(meterId);
});
