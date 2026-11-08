import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ExpenseCategoryStyle {
  ExpenseCategoryStyle._();

  static const String defaultColorHex = '#5C6BC0';

  /// Kept as an integer so the existing expense database contract remains
  /// unchanged. The UI resolves this value back to a [FaIconData].
  static int get defaultIconCode => FontAwesomeIcons.wallet.codePoint;

  /// Retained for compatibility with the existing database/service layer.
  /// Category rendering no longer depends on this value.
  static const String materialFontFamily = 'MaterialIcons';

  static const List<String> colorOptions = [
    '#3949AB',
    '#5C6BC0',
    '#7E57C2',
    '#8E24AA',
    '#AB47BC',
    '#D81B60',
    '#EC407A',
    '#E53935',
    '#EF5350',
    '#F4511E',
    '#FF7043',
    '#FB8C00',
    '#FFA726',
    '#F9A825',
    '#FFCA28',
    '#7CB342',
    '#9CCC65',
    '#43A047',
    '#66BB6A',
    '#00897B',
    '#26A69A',
    '#00ACC1',
    '#26C6DA',
    '#039BE5',
    '#29B6F6',
    '#1E88E5',
    '#42A5F5',
    '#546E7A',
    '#78909C',
    '#6D4C41',
    '#8D6E63',
    '#455A64',
    '#2E7D32',
    '#00695C',
    '#1565C0',
    '#4527A0',
    '#AD1457',
    '#C62828',
    '#EF6C00',
    '#4E342E',
  ];

  static const List<FaIconData> iconOptions = [
    FontAwesomeIcons.wallet,
    FontAwesomeIcons.bagShopping,
    FontAwesomeIcons.cartShopping,
    FontAwesomeIcons.utensils,
    FontAwesomeIcons.basketShopping,
    FontAwesomeIcons.burger,
    FontAwesomeIcons.mugHot,
    FontAwesomeIcons.house,
    FontAwesomeIcons.building,
    FontAwesomeIcons.bolt,
    FontAwesomeIcons.droplet,
    FontAwesomeIcons.gasPump,
    FontAwesomeIcons.car,
    FontAwesomeIcons.bus,
    FontAwesomeIcons.plane,
    FontAwesomeIcons.shieldHeart,
    FontAwesomeIcons.kitMedical,
    FontAwesomeIcons.dumbbell,
    FontAwesomeIcons.graduationCap,
    FontAwesomeIcons.baby,
    FontAwesomeIcons.paw,
    FontAwesomeIcons.mobileScreenButton,
    FontAwesomeIcons.wifi,
    FontAwesomeIcons.repeat,
    FontAwesomeIcons.film,
    FontAwesomeIcons.music,
    FontAwesomeIcons.gamepad,
    FontAwesomeIcons.gift,
    FontAwesomeIcons.piggyBank,
    FontAwesomeIcons.chartLine,
    FontAwesomeIcons.briefcase,
    FontAwesomeIcons.receipt,
    FontAwesomeIcons.moneyBillWave,
    FontAwesomeIcons.creditCard,
    FontAwesomeIcons.handHoldingHeart,
    FontAwesomeIcons.screwdriverWrench,
    FontAwesomeIcons.broom,
    FontAwesomeIcons.shirt,
    FontAwesomeIcons.earthAmericas,
    FontAwesomeIcons.coins,
    FontAwesomeIcons.sackDollar,
    FontAwesomeIcons.moneyCheckDollar,
    FontAwesomeIcons.landmark,
    FontAwesomeIcons.store,
    FontAwesomeIcons.tags,
    FontAwesomeIcons.boxOpen,
    FontAwesomeIcons.truck,
    FontAwesomeIcons.trainSubway,
    FontAwesomeIcons.taxi,
    FontAwesomeIcons.motorcycle,
    FontAwesomeIcons.bicycle,
    FontAwesomeIcons.hotel,
    FontAwesomeIcons.umbrellaBeach,
    FontAwesomeIcons.planeDeparture,
    FontAwesomeIcons.hospital,
    FontAwesomeIcons.pills,
    FontAwesomeIcons.heartPulse,
    FontAwesomeIcons.tooth,
    FontAwesomeIcons.glasses,
    FontAwesomeIcons.bookOpen,
    FontAwesomeIcons.laptop,
    FontAwesomeIcons.headphones,
    FontAwesomeIcons.camera,
    FontAwesomeIcons.couch,
    FontAwesomeIcons.bed,
    FontAwesomeIcons.hammer,
    FontAwesomeIcons.paintRoller,
    FontAwesomeIcons.soap,
    FontAwesomeIcons.trashCan,
    FontAwesomeIcons.seedling,
    FontAwesomeIcons.tree,
    FontAwesomeIcons.calendarDays,
    FontAwesomeIcons.cakeCandles,
    FontAwesomeIcons.userTie,
    FontAwesomeIcons.ellipsis,
  ];

  static Color colorFromHex(String? value, {Color? fallback}) {
    final normalized = (value ?? '').trim().replaceFirst('#', '');
    final parsed = int.tryParse(
      normalized.length == 6 ? 'FF$normalized' : normalized,
      radix: 16,
    );
    return parsed == null ? (fallback ?? const Color(0xFF5C6BC0)) : Color(parsed);
  }

  static String normalizeHex(Color color) {
    final value = color.value & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Resolves persisted category icon values into Font Awesome 11 icons.
  ///
  /// Existing Material icon code points remain readable: when a stored value
  /// is not one of the Font Awesome choices, a suitable Font Awesome icon is
  /// selected from the category title. No database or service migration is
  /// required.
  static FaIconData iconFromCode(
    dynamic code, {
    String? title,
    FaIconData fallback = FontAwesomeIcons.wallet,
  }) {
    final parsed = code is int
        ? code
        : code is num
            ? code.toInt()
            : int.tryParse(code?.toString() ?? '');

    if (parsed != null && parsed > 0) {
      for (final icon in iconOptions) {
        if (icon.codePoint == parsed) return icon;
      }
    }

    return iconForTitle(title, fallback: fallback);
  }

  static int normalizeIconCode(dynamic code, {String? title}) {
    return iconFromCode(code, title: title).codePoint;
  }

  static FaIconData iconForTitle(
    String? title, {
    FaIconData fallback = FontAwesomeIcons.wallet,
  }) {
    final value = (title ?? '').trim().toLowerCase();
    if (value.isEmpty) return fallback;

    bool hasAny(List<String> words) =>
        words.any((word) => value.contains(word));

    if (hasAny(['grocery', 'groceries', 'market', 'vegetable', 'fruit'])) {
      return FontAwesomeIcons.basketShopping;
    }
    if (hasAny(['food', 'restaurant', 'dining', 'meal', 'lunch', 'dinner'])) {
      return FontAwesomeIcons.utensils;
    }
    if (hasAny(['coffee', 'cafe', 'tea'])) return FontAwesomeIcons.mugHot;
    if (hasAny(['shopping', 'purchase'])) return FontAwesomeIcons.bagShopping;
    if (hasAny(['rent', 'home', 'house', 'mortgage'])) {
      return FontAwesomeIcons.house;
    }
    if (hasAny(['office', 'apartment', 'building'])) {
      return FontAwesomeIcons.building;
    }
    if (hasAny(['electric', 'electricity', 'power', 'utility'])) {
      return FontAwesomeIcons.bolt;
    }
    if (hasAny(['water'])) return FontAwesomeIcons.droplet;
    if (hasAny(['fuel', 'petrol', 'diesel', 'gas'])) {
      return FontAwesomeIcons.gasPump;
    }
    if (hasAny(['car', 'vehicle', 'parking'])) return FontAwesomeIcons.car;
    if (hasAny(['bus', 'public transport'])) return FontAwesomeIcons.bus;
    if (hasAny(['travel', 'vacation', 'holiday', 'trip', 'flight'])) {
      return FontAwesomeIcons.plane;
    }
    if (hasAny(['health', 'medical', 'doctor', 'medicine', 'hospital'])) {
      return FontAwesomeIcons.kitMedical;
    }
    if (hasAny(['gym', 'fitness', 'workout', 'sport'])) {
      return FontAwesomeIcons.dumbbell;
    }
    if (hasAny(['education', 'school', 'college', 'university', 'course'])) {
      return FontAwesomeIcons.graduationCap;
    }
    if (hasAny(['baby', 'child', 'kids'])) return FontAwesomeIcons.baby;
    if (hasAny(['pet', 'cat', 'dog'])) return FontAwesomeIcons.paw;
    if (hasAny(['phone', 'mobile'])) return FontAwesomeIcons.mobileScreenButton;
    if (hasAny(['internet', 'wifi', 'broadband'])) return FontAwesomeIcons.wifi;
    if (hasAny(['subscription', 'membership'])) return FontAwesomeIcons.repeat;
    if (hasAny(['movie', 'cinema', 'entertainment'])) {
      return FontAwesomeIcons.film;
    }
    if (hasAny(['music'])) return FontAwesomeIcons.music;
    if (hasAny(['game', 'gaming'])) return FontAwesomeIcons.gamepad;
    if (hasAny(['gift', 'present'])) return FontAwesomeIcons.gift;
    if (hasAny(['saving', 'savings'])) return FontAwesomeIcons.piggyBank;
    if (hasAny(['investment', 'invest', 'profit'])) {
      return FontAwesomeIcons.chartLine;
    }
    if (hasAny(['work', 'business', 'job'])) return FontAwesomeIcons.briefcase;
    if (hasAny(['receipt', 'invoice', 'bill'])) return FontAwesomeIcons.receipt;
    if (hasAny(['card', 'credit', 'debit'])) return FontAwesomeIcons.creditCard;
    if (hasAny(['charity', 'donation'])) {
      return FontAwesomeIcons.handHoldingHeart;
    }
    if (hasAny(['repair', 'maintenance', 'tool'])) {
      return FontAwesomeIcons.screwdriverWrench;
    }
    if (hasAny(['clean', 'cleaning'])) return FontAwesomeIcons.broom;
    if (hasAny(['clothes', 'clothing', 'fashion'])) {
      return FontAwesomeIcons.shirt;
    }
    if (hasAny(['cash', 'payment', 'salary', 'income'])) {
      return FontAwesomeIcons.moneyBillWave;
    }

    return fallback;
  }

  static String fallbackColorForId(int id) {
    return colorOptions[id.abs() % colorOptions.length];
  }

  static int fallbackIconForId(int id) {
    return iconOptions[id.abs() % iconOptions.length].codePoint;
  }
}
