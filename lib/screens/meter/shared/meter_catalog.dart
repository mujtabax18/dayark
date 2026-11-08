import 'package:flutter/material.dart';

class MeterChoice {
  final String key;
  final String label;
  final IconData icon;
  final String defaultUnit;

  const MeterChoice({
    required this.key,
    required this.label,
    required this.icon,
    required this.defaultUnit,
  });
}

class MeterCatalog {
  static const types = <MeterChoice>[
    MeterChoice(
      key: 'electricity',
      label: 'Electricity',
      icon: Icons.electric_bolt_rounded,
      defaultUnit: 'kWh',
    ),
    MeterChoice(
      key: 'gas',
      label: 'Gas',
      icon: Icons.local_fire_department_rounded,
      defaultUnit: 'm³',
    ),
    MeterChoice(
      key: 'water',
      label: 'Water',
      icon: Icons.water_drop_rounded,
      defaultUnit: 'L',
    ),
    MeterChoice(
      key: 'solar',
      label: 'Solar generation',
      icon: Icons.solar_power_rounded,
      defaultUnit: 'kWh',
    ),
    MeterChoice(
      key: 'generator',
      label: 'Generator / fuel',
      icon: Icons.oil_barrel_rounded,
      defaultUnit: 'L',
    ),
    MeterChoice(
      key: 'sub_meter',
      label: 'Sub meter',
      icon: Icons.device_hub_rounded,
      defaultUnit: 'units',
    ),
    MeterChoice(
      key: 'other',
      label: 'Other',
      icon: Icons.speed_rounded,
      defaultUnit: 'units',
    ),
  ];

  static const pakistanProviders = <String>[
    'MEPCO',
    'LESCO',
    'IESCO',
    'FESCO',
    'GEPCO',
    'PESCO',
    'HESCO',
    'SEPCO',
    'QESCO',
    'TESCO',
    'K-Electric',
    'SNGPL',
    'SSGC',
    'WASA',
    'Private / Sub meter',
    'Other',
  ];

  static const tariffCategories = <String, String>{
    'residential': 'Residential',
    'commercial': 'Commercial',
    'industrial': 'Industrial',
    'agricultural': 'Agricultural',
    'general_supply': 'General supply',
    'other': 'Other',
  };

  static const frequencies = <String, String>{
    'daily': 'Daily',
    'weekly': 'Weekly',
    'monthly': 'Monthly',
    'custom': 'Custom interval',
  };

  static const readingKinds = <String, String>{
    'normal': 'Normal reading',
    'estimated': 'Estimated reading',
    'meter_reset': 'Meter reset / replacement',
  };

  static const colors = <int>[
    0xFF5C6BC0,
    0xFF00897B,
    0xFF1E88E5,
    0xFFF4511E,
    0xFF7B1FA2,
    0xFF43A047,
    0xFFF9A825,
    0xFF546E7A,
    0xFFD81B60,
    0xFF6D4C41,
  ];

  static MeterChoice typeFor(String key) {
    return types.firstWhere(
      (type) => type.key == key,
      orElse: () => types.last,
    );
  }

  static IconData iconFor(String key) => typeFor(key).icon;

  static String typeLabel(String key) => typeFor(key).label;

  static String frequencyLabel(String key) => frequencies[key] ?? 'Weekly';

  static String tariffLabel(String key) => tariffCategories[key] ?? 'Other';

  static String readingKindLabel(String key) =>
      readingKinds[key] ?? 'Normal reading';
}
