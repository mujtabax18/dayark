import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:metersystem/models/meter.dart';
import 'package:metersystem/services/localDatabaseServices/MeterService.dart';
import '../../MeterList/controller/meter_provider.dart';

class MeterDetailState {
  final Meter meter;
  final List<Reading> readings;
  final List<MeterTariffSlab> tariffSlabs;
  final MeterBaselineAnchor? baselineAnchor;
  final bool isLoading;
  final String? error;

  const MeterDetailState({
    required this.meter,
    this.readings = const [],
    this.tariffSlabs = const [],
    this.baselineAnchor,
    this.isLoading = false,
    this.error,
  });

  MeterDetailState copyWith({
    Meter? meter,
    List<Reading>? readings,
    List<MeterTariffSlab>? tariffSlabs,
    MeterBaselineAnchor? baselineAnchor,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearBaselineAnchor = false,
  }) {
    return MeterDetailState(
      meter: meter ?? this.meter,
      readings: readings ?? this.readings,
      tariffSlabs: tariffSlabs ?? this.tariffSlabs,
      baselineAnchor:
          clearBaselineAnchor ? null : baselineAnchor ?? this.baselineAnchor,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class MeterDetailNotifier extends StateNotifier<MeterDetailState> {
  final MeterService _service;
  final Future<void> Function() _refreshGlobalMeterStateCallback;

  MeterDetailNotifier(
    this._service,
    this._refreshGlobalMeterStateCallback,
    Meter meter,
  ) : super(MeterDetailState(meter: meter)) {
    load();
  }

  Future<void> load() async {
    final meterId = state.meter.id;
    if (meterId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait<dynamic>([
        _service.getMeterById(meterId),
        _service.getReadingsForMeter(meterId),
        _service.getTariffSlabs(meterId),
        _service.getBaselineAnchor(meterId),
      ]);
      state = state.copyWith(
        meter: (results[0] as Meter?) ?? state.meter,
        readings: results[1] as List<Reading>,
        tariffSlabs: results[2] as List<MeterTariffSlab>,
        baselineAnchor: results[3] as MeterBaselineAnchor?,
        clearBaselineAnchor: results[3] == null,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> updateMeter(Meter meter) async {
    await _service.updateMeter(meter);
    await load();
    await _refreshGlobalMeterState();
  }

  Future<void> setBaseline(Reading reading) async {
    final id = state.meter.id;
    if (id == null) return;
    await _service.updateMeterBaseline(
      id,
      reading.value,
      baselineDate: reading.date,
      readingId: reading.id,
    );
    await load();
    await _refreshGlobalMeterState();
  }

  Future<Reading> addReading(Reading reading) async {
    final id = await _service.addReading(reading);
    await _reloadReadingsAndBaseline();
    await _refreshGlobalMeterState();
    return reading.copyWith(id: id);
  }

  Future<void> updateReading(Reading reading) async {
    await _service.updateReading(reading);
    await _reloadReadingsAndBaseline();
    await _refreshGlobalMeterState();
  }

  Future<void> deleteReading(int? id) async {
    final meterId = state.meter.id;
    if (id == null || meterId == null) return;
    await _service.deleteReading(id, meterId);
    await _reloadReadingsAndBaseline();
    await _refreshGlobalMeterState();
  }

  Future<void> replaceTariffSlabs(List<MeterTariffSlab> slabs) async {
    final meterId = state.meter.id;
    if (meterId == null) return;
    await _service.replaceTariffSlabs(meterId, slabs);
    await load();
    await _refreshGlobalMeterState();
  }

  Future<void> _refreshGlobalMeterState() =>
      _refreshGlobalMeterStateCallback();

  Future<void> _reloadReadingsAndBaseline() async {
    final meterId = state.meter.id;
    if (meterId == null) return;
    final results = await Future.wait<dynamic>([
      _service.getMeterById(meterId),
      _service.getReadingsForMeter(meterId),
      _service.getBaselineAnchor(meterId),
    ]);
    state = state.copyWith(
      meter: (results[0] as Meter?) ?? state.meter,
      readings: results[1] as List<Reading>,
      baselineAnchor: results[2] as MeterBaselineAnchor?,
      clearBaselineAnchor: results[2] == null,
      clearError: true,
    );
  }
}

final meterDetailProvider = StateNotifierProvider.autoDispose
    .family<MeterDetailNotifier, MeterDetailState, Meter>(
  (ref, meter) => MeterDetailNotifier(
    ref.watch(meterServiceProvider),
    () async {
      // Keep list/overview/dashboard summaries synchronized no matter which
      // meter screen performs the mutation.
      await ref.read(meterProvider.notifier).loadMeters();
      final revision = ref.read(meterDataRevisionProvider.notifier);
      revision.state = revision.state + 1;
    },
    meter,
  ),
);
