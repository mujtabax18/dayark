import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controller/theme_notifier.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/responsive_layout.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/HomeFeatureModel.dart';
import '../../../models/HomeLayoutSettings.dart';
import '../../../models/dashboard_summary.dart';
import '../../../utlis/app_router.dart';
import '../controller/dashboard_provider.dart';
import '../controller/home_layout_provider.dart';
import '../controller/home_quote_provider.dart';
import '../controller/home_provider.dart';
import '../widgets/compact_dashboard_summaries.dart';
import '../widgets/dashboard_summary_grid.dart';
import '../widgets/glance_dashboard_summaries.dart';
import '../widgets/home_module_links.dart';
import '../widgets/home_quote_card.dart';

part 'parts/home_screen_home_page_state.dart';
part 'parts/home_screen_desktop_dashboard_intro.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

