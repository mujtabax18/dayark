import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HabitIconOption {
  const HabitIconOption({required this.label, required this.icon});

  final String label;
  final FaIconData icon;
}

class HabitIconCatalog {
  HabitIconCatalog._();

  static const List<HabitIconOption> options = [
    HabitIconOption(label: 'Growth', icon: FontAwesomeIcons.chartLine),
    HabitIconOption(label: 'Health', icon: FontAwesomeIcons.shieldHeart),
    HabitIconOption(label: 'Fitness', icon: FontAwesomeIcons.dumbbell),
    HabitIconOption(label: 'Learning', icon: FontAwesomeIcons.graduationCap),
    HabitIconOption(label: 'Care', icon: FontAwesomeIcons.handHoldingHeart),
    HabitIconOption(label: 'Work', icon: FontAwesomeIcons.briefcase),
    HabitIconOption(label: 'Energy', icon: FontAwesomeIcons.bolt),
    HabitIconOption(label: 'Hydration', icon: FontAwesomeIcons.droplet),
    HabitIconOption(label: 'Home', icon: FontAwesomeIcons.house),
    HabitIconOption(label: 'Coffee', icon: FontAwesomeIcons.mugHot),
    HabitIconOption(label: 'Music', icon: FontAwesomeIcons.music),
    HabitIconOption(label: 'Games', icon: FontAwesomeIcons.gamepad),
    HabitIconOption(label: 'Reward', icon: FontAwesomeIcons.gift),
    HabitIconOption(label: 'Saving', icon: FontAwesomeIcons.piggyBank),
    HabitIconOption(label: 'Travel', icon: FontAwesomeIcons.plane),
    HabitIconOption(label: 'Pets', icon: FontAwesomeIcons.paw),
    HabitIconOption(label: 'Cleaning', icon: FontAwesomeIcons.broom),
    HabitIconOption(label: 'Shopping', icon: FontAwesomeIcons.basketShopping),
  ];

  static int get defaultIconCode => FontAwesomeIcons.chartLine.codePoint;

  static FaIconData fromCode(
    dynamic code, {
    String? category,
    String? title,
  }) {
    final parsed = code is int
        ? code
        : code is num
            ? code.toInt()
            : int.tryParse(code?.toString() ?? '');

    if (parsed != null && parsed > 0) {
      for (final option in options) {
        if (option.icon.codePoint == parsed) return option.icon;
      }
    }

    return forCategory(category, title: title);
  }

  static int normalizeCode(
    dynamic code, {
    String? category,
    String? title,
  }) {
    return fromCode(code, category: category, title: title).codePoint;
  }

  static FaIconData forCategory(String? category, {String? title}) {
    final combined = '${category ?? ''} ${title ?? ''}'.trim().toLowerCase();

    bool containsAny(List<String> words) {
      return words.any(combined.contains);
    }

    if (containsAny(['health', 'medicine', 'wellness'])) {
      return FontAwesomeIcons.shieldHeart;
    }
    if (containsAny(['fitness', 'gym', 'exercise', 'workout'])) {
      return FontAwesomeIcons.dumbbell;
    }
    if (containsAny(['learn', 'study', 'read', 'education', 'course'])) {
      return FontAwesomeIcons.graduationCap;
    }
    if (containsAny(['mindful', 'meditat', 'gratitude', 'care'])) {
      return FontAwesomeIcons.handHoldingHeart;
    }
    if (containsAny(['productiv', 'work', 'business', 'task'])) {
      return FontAwesomeIcons.briefcase;
    }
    if (containsAny(['water', 'drink', 'hydrat'])) {
      return FontAwesomeIcons.droplet;
    }
    if (containsAny(['music', 'sing', 'instrument'])) {
      return FontAwesomeIcons.music;
    }
    if (containsAny(['game', 'gaming'])) return FontAwesomeIcons.gamepad;
    if (containsAny(['save', 'money', 'budget'])) {
      return FontAwesomeIcons.piggyBank;
    }
    if (containsAny(['travel', 'trip', 'flight'])) return FontAwesomeIcons.plane;
    if (containsAny(['clean', 'housework'])) return FontAwesomeIcons.broom;
    if (containsAny(['pet', 'dog', 'cat'])) return FontAwesomeIcons.paw;
    if (containsAny(['home', 'family'])) return FontAwesomeIcons.house;

    return FontAwesomeIcons.chartLine;
  }
}
