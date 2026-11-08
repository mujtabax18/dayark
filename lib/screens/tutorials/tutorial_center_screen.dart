import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_tokens.dart';
import '../../core/design/responsive_layout.dart';
import '../../core/widgets/common/app_surface.dart';
import '../../localization/app_localizations.dart';
import '../../utlis/app_router.dart';
import '../navigation/widgets/desktop_content_frame.dart';
import '../navigation/widgets/desktop_navigation_scope.dart';

part 'parts/tutorial_center_screen_state.dart';
part 'parts/tutorial_center_screen_tutorial_desktop_detail.dart';
part 'parts/tutorial_center_screen_tutorial_guide.dart';

class TutorialCenterScreen extends StatefulWidget {
  const TutorialCenterScreen({super.key});

  @override
  State<TutorialCenterScreen> createState() => _TutorialCenterScreenState();
}

