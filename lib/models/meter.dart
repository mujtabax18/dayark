class Reading {
  int? id;
  double value;
  DateTime date;
  int meterId;
  String note;
  double? billAmount;
  double? estimatedCost;
  String source;
  String readingKind;
  DateTime? createdAt;
  DateTime? updatedAt;

  Reading({
    this.id,
    required num value,
    required this.date,
    required this.meterId,
    this.note = '',
    num? billAmount,
    num? estimatedCost,
    this.source = 'manual',
    this.readingKind = 'normal',
    this.createdAt,
    this.updatedAt,
  })  : value = value.toDouble(),
        billAmount = billAmount?.toDouble(),
        estimatedCost = estimatedCost?.toDouble();

  Reading copyWith({
    int? id,
    double? value,
    DateTime? date,
    int? meterId,
    String? note,
    double? billAmount,
    bool clearBillAmount = false,
    double? estimatedCost,
    bool clearEstimatedCost = false,
    String? source,
    String? readingKind,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reading(
      id: id ?? this.id,
      value: value ?? this.value,
      date: date ?? this.date,
      meterId: meterId ?? this.meterId,
      note: note ?? this.note,
      billAmount: clearBillAmount ? null : billAmount ?? this.billAmount,
      estimatedCost:
          clearEstimatedCost ? null : estimatedCost ?? this.estimatedCost,
      source: source ?? this.source,
      readingKind: readingKind ?? this.readingKind,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'value': value,
      'date': date.toIso8601String(),
      'meter_id': meterId,
      'note': note,
      'bill_amount': billAmount,
      'estimated_cost': estimatedCost,
      'source': source,
      'reading_kind': readingKind,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': updatedAt?.toIso8601String() ?? now,
    };
  }

  static Reading fromJson(Map<String, dynamic> json) {
    return Reading(
      id: _asInt(json['id']),
      value: _asDouble(json['value']) ?? 0,
      date: _asDateTime(json['date']) ?? DateTime.now(),
      meterId: _asInt(json['meter_id']) ?? 0,
      note: (json['note'] ?? '').toString(),
      billAmount: _asDouble(json['bill_amount']),
      estimatedCost: _asDouble(json['estimated_cost']),
      source: (json['source'] ?? 'manual').toString(),
      readingKind: (json['reading_kind'] ?? 'normal').toString(),
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

class Meter {
  int? id;
  String name;
  String number;
  double? baseline;
  String meterType;
  String provider;
  String location;
  String consumerName;
  String referenceNumber;
  String tariffCategory;
  String unitLabel;
  String iconKey;
  int colorValue;
  String readingFrequency;
  int customIntervalDays;
  int billingCycleDay;
  double? targetUnits;
  double? targetBudget;
  double unitRate;
  double fixedCharges;
  String notes;
  bool isActive;
  DateTime? createdAt;
  DateTime? updatedAt;

  Meter({
    this.id,
    required this.name,
    this.number = '',
    num? baseline,
    this.meterType = 'electricity',
    this.provider = '',
    this.location = '',
    this.consumerName = '',
    this.referenceNumber = '',
    this.tariffCategory = 'residential',
    this.unitLabel = 'kWh',
    this.iconKey = 'electricity',
    this.colorValue = 0xFF5C6BC0,
    this.readingFrequency = 'weekly',
    this.customIntervalDays = 7,
    this.billingCycleDay = 1,
    num? targetUnits,
    num? targetBudget,
    num unitRate = 0,
    num fixedCharges = 0,
    this.notes = '',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  })  : baseline = baseline?.toDouble(),
        targetUnits = targetUnits?.toDouble(),
        targetBudget = targetBudget?.toDouble(),
        unitRate = unitRate.toDouble(),
        fixedCharges = fixedCharges.toDouble();

  Meter copyWith({
    int? id,
    String? name,
    String? number,
    double? baseline,
    bool clearBaseline = false,
    String? meterType,
    String? provider,
    String? location,
    String? consumerName,
    String? referenceNumber,
    String? tariffCategory,
    String? unitLabel,
    String? iconKey,
    int? colorValue,
    String? readingFrequency,
    int? customIntervalDays,
    int? billingCycleDay,
    double? targetUnits,
    bool clearTargetUnits = false,
    double? targetBudget,
    bool clearTargetBudget = false,
    double? unitRate,
    double? fixedCharges,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meter(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      baseline: clearBaseline ? null : baseline ?? this.baseline,
      meterType: meterType ?? this.meterType,
      provider: provider ?? this.provider,
      location: location ?? this.location,
      consumerName: consumerName ?? this.consumerName,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      tariffCategory: tariffCategory ?? this.tariffCategory,
      unitLabel: unitLabel ?? this.unitLabel,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      readingFrequency: readingFrequency ?? this.readingFrequency,
      customIntervalDays: customIntervalDays ?? this.customIntervalDays,
      billingCycleDay: billingCycleDay ?? this.billingCycleDay,
      targetUnits:
          clearTargetUnits ? null : targetUnits ?? this.targetUnits,
      targetBudget:
          clearTargetBudget ? null : targetBudget ?? this.targetBudget,
      unitRate: unitRate ?? this.unitRate,
      fixedCharges: fixedCharges ?? this.fixedCharges,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'name': name,
      'number': number,
      'baseline': baseline,
      'meter_type': meterType,
      'provider': provider,
      'location': location,
      'consumer_name': consumerName,
      'reference_number': referenceNumber,
      'tariff_category': tariffCategory,
      'unit_label': unitLabel,
      'icon_key': iconKey,
      'color_value': colorValue,
      'reading_frequency': readingFrequency,
      'custom_interval_days': customIntervalDays,
      'billing_cycle_day': billingCycleDay,
      'target_units': targetUnits,
      'target_budget': targetBudget,
      'unit_rate': unitRate,
      'fixed_charges': fixedCharges,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': updatedAt?.toIso8601String() ?? now,
    };
  }

  static Meter fromJson(Map<String, dynamic> json) {
    final meterType = (json['meter_type'] ?? 'electricity').toString();
    return Meter(
      id: _asInt(json['id']),
      name: (json['name'] ?? 'Meter').toString(),
      number: (json['number'] ?? '').toString(),
      baseline: _asDouble(json['baseline']),
      meterType: meterType,
      provider: (json['provider'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      consumerName: (json['consumer_name'] ?? '').toString(),
      referenceNumber: (json['reference_number'] ?? '').toString(),
      tariffCategory:
          (json['tariff_category'] ?? 'residential').toString(),
      unitLabel:
          (json['unit_label'] ?? defaultUnitForType(meterType)).toString(),
      iconKey: (json['icon_key'] ?? meterType).toString(),
      colorValue: _asInt(json['color_value']) ?? 0xFF5C6BC0,
      readingFrequency:
          (json['reading_frequency'] ?? 'weekly').toString(),
      customIntervalDays: _asInt(json['custom_interval_days']) ?? 7,
      billingCycleDay: _asInt(json['billing_cycle_day']) ?? 1,
      targetUnits: _asDouble(json['target_units']),
      targetBudget: _asDouble(json['target_budget']),
      unitRate: _asDouble(json['unit_rate']) ?? 0,
      fixedCharges: _asDouble(json['fixed_charges']) ?? 0,
      notes: (json['notes'] ?? '').toString(),
      isActive: (_asInt(json['is_active']) ?? 1) == 1,
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }

  int get effectiveIntervalDays {
    switch (readingFrequency) {
      case 'daily':
        return 1;
      case 'weekly':
        return 7;
      case 'monthly':
        return 30;
      case 'custom':
        return customIntervalDays < 1 ? 1 : customIntervalDays;
      default:
        return 7;
    }
  }

  static String defaultUnitForType(String type) {
    switch (type) {
      case 'gas':
        return 'm³';
      case 'water':
        return 'L';
      case 'solar':
        return 'kWh';
      case 'generator':
        return 'L';
      default:
        return 'kWh';
    }
  }
}

class MeterTariffSlab {
  final int? id;
  final int meterId;
  final double fromUnit;
  final double? toUnit;
  final double rate;
  final String label;
  final int position;

  const MeterTariffSlab({
    this.id,
    required this.meterId,
    required this.fromUnit,
    this.toUnit,
    required this.rate,
    this.label = '',
    this.position = 0,
  });

  MeterTariffSlab copyWith({
    int? id,
    int? meterId,
    double? fromUnit,
    double? toUnit,
    bool clearToUnit = false,
    double? rate,
    String? label,
    int? position,
  }) {
    return MeterTariffSlab(
      id: id ?? this.id,
      meterId: meterId ?? this.meterId,
      fromUnit: fromUnit ?? this.fromUnit,
      toUnit: clearToUnit ? null : toUnit ?? this.toUnit,
      rate: rate ?? this.rate,
      label: label ?? this.label,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'meter_id': meterId,
        'from_unit': fromUnit,
        'to_unit': toUnit,
        'rate': rate,
        'label': label,
        'position': position,
      };

  static MeterTariffSlab fromJson(Map<String, dynamic> json) {
    return MeterTariffSlab(
      id: _asInt(json['id']),
      meterId: _asInt(json['meter_id']) ?? 0,
      fromUnit: _asDouble(json['from_unit']) ?? 0,
      toUnit: _asDouble(json['to_unit']),
      rate: _asDouble(json['rate']) ?? 0,
      label: (json['label'] ?? '').toString(),
      position: _asInt(json['position']) ?? 0,
    );
  }
}

class MeterInsights {
  final Reading? latest;
  final Reading? previous;
  final double latestIntervalUsage;
  final double totalUsage;
  final double averageDailyUsage;
  final double projected30DayUsage;
  final double estimatedCost;
  final DateTime? nextReadingDue;

  const MeterInsights({
    this.latest,
    this.previous,
    this.latestIntervalUsage = 0,
    this.totalUsage = 0,
    this.averageDailyUsage = 0,
    this.projected30DayUsage = 0,
    this.estimatedCost = 0,
    this.nextReadingDue,
  });

  double progressFor(Meter meter) {
    final target = meter.targetUnits;
    if (target == null || target <= 0) return 0;
    return (projected30DayUsage / target).clamp(0, 2).toDouble();
  }

  bool isOverUnitTarget(Meter meter) {
    final target = meter.targetUnits;
    return target != null && target > 0 && projected30DayUsage > target;
  }

  bool isOverBudget(Meter meter) {
    final target = meter.targetBudget;
    return target != null && target > 0 && estimatedCost > target;
  }

  static MeterInsights calculate({
    required Meter meter,
    required List<Reading> readings,
    List<MeterTariffSlab> slabs = const [],
  }) {
    if (readings.isEmpty) {
      return MeterInsights(
        nextReadingDue: meter.createdAt?.add(
          Duration(days: meter.effectiveIntervalDays),
        ),
      );
    }

    final sorted = [...readings]..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;
    final previous = sorted.length > 1 ? sorted[1] : null;
    final chronological = sorted.reversed.toList();
    final baseline = meter.baseline ?? chronological.first.value;

    var totalUsage = _positiveDifference(
      chronological.first.value,
      baseline,
    );
    for (var index = 1; index < chronological.length; index++) {
      final current = chronological[index];
      final older = chronological[index - 1];
      if (current.readingKind == 'meter_reset') continue;
      totalUsage += _positiveDifference(current.value, older.value);
    }

    final intervalUsage = latest.readingKind == 'meter_reset'
        ? 0.0
        : previous == null
            ? _positiveDifference(latest.value, baseline)
            : _positiveDifference(latest.value, previous.value);

    final recentDescending = sorted.take(10).toList();
    final recent = recentDescending.reversed.toList();
    var recentUsage = 0.0;
    for (var index = 1; index < recent.length; index++) {
      final current = recent[index];
      final older = recent[index - 1];
      if (current.readingKind == 'meter_reset') continue;
      recentUsage += _positiveDifference(current.value, older.value);
    }
    final firstRecent = recent.first;
    final daySpan = latest.date.difference(firstRecent.date).inHours / 24;
    final averageDaily = daySpan > 0
        ? recentUsage / daySpan
        : intervalUsage / meter.effectiveIntervalDays;
    final projected = averageDaily * 30;
    final cost = calculateCost(
      units: projected,
      meter: meter,
      slabs: slabs,
    );

    return MeterInsights(
      latest: latest,
      previous: previous,
      latestIntervalUsage: intervalUsage,
      totalUsage: totalUsage,
      averageDailyUsage: averageDaily,
      projected30DayUsage: projected,
      estimatedCost: cost,
      nextReadingDue:
          latest.date.add(Duration(days: meter.effectiveIntervalDays)),
    );
  }

  static double calculateCost({
    required double units,
    required Meter meter,
    List<MeterTariffSlab> slabs = const [],
  }) {
    final safeUnits = units < 0 ? 0 : units;
    if (slabs.isEmpty) {
      return (safeUnits * meter.unitRate) + meter.fixedCharges;
    }

    final sorted = [...slabs]
      ..sort((a, b) => a.fromUnit.compareTo(b.fromUnit));
    var variableCost = 0.0;

    for (final slab in sorted) {
      if (safeUnits <= slab.fromUnit) continue;
      final upper = slab.toUnit ?? safeUnits;
      final chargeable = (safeUnits < upper ? safeUnits : upper) - slab.fromUnit;
      if (chargeable > 0) variableCost += chargeable * slab.rate;
    }

    return variableCost + meter.fixedCharges;
  }

  static double _positiveDifference(double current, double previous) {
    final result = current - previous;
    return result < 0 ? 0 : result;
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
