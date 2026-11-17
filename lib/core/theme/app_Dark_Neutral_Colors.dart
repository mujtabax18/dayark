import 'package:flutter/material.dart';

import 'app_neutral_colors.dart';

class DarkNeutralColors implements AppNeutralColors {
  const DarkNeutralColors({this.pureBlack = false});

  final bool pureBlack;

  @override
  Color get background =>
      pureBlack ? const Color(0xFF000000) : const Color(0xFF0B0D12);

  @override
  Color get section =>
      pureBlack ? const Color(0xFF080808) : const Color(0xFF10131A);

  @override
  Color get card =>
      pureBlack ? const Color(0xFF111111) : const Color(0xFF151922);

  @override
  Color get divider =>
      pureBlack ? const Color(0xFF303030) : const Color(0xFF282D38);

  @override
  Color get textPrimary => const Color(0xFFF4F6FA);

  @override
  Color get textSecondary => const Color(0xFFB3B9C6);

  @override
  Color get textDisabled => const Color(0xFF737A89);

  @override
  Color get textPrimaryNot => const Color(0xFFFFFFFF);
}
