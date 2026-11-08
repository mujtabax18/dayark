part of '../habit_desktop_dashboard.dart';

enum _HabitDesktopSection { overview, active, paused, history, detail }

class _HabitDesktopDashboardState
    extends ConsumerState<HabitDesktopDashboard> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final ValueNotifier<_HabitDesktopSection> _rootSection;
  _HabitDesktopSection _selectedSection = _HabitDesktopSection.overview;
  int? _selectedHabitId;
  int _navigationToken = 0;

  @override
  void initState() {
    super.initState();
    _rootSection = ValueNotifier(_HabitDesktopSection.overview);
    final initialHabitId = widget.initialHabitId;
    if (initialHabitId != null) {
      _selectedSection = _HabitDesktopSection.detail;
      _selectedHabitId = initialHabitId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openHabit(initialHabitId);
      });
    }
  }

  @override
  void dispose() {
    _rootSection.dispose();
    super.dispose();
  }

  void _returnToRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _selectRoot(_HabitDesktopSection section) {
    _navigationToken++;
    _returnToRoot();
    _rootSection.value = section;
    setState(() {
      _selectedSection = section;
      _selectedHabitId = null;
    });
  }

  void _openHistory() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final token = ++_navigationToken;
    _returnToRoot();
    setState(() {
      _selectedSection = _HabitDesktopSection.history;
      _selectedHabitId = null;
    });
    navigator
        .push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/habit-history-desktop'),
            builder: (_) => const HabitHistoryScreen(),
          ),
        )
        .then((_) {
      if (!mounted || token != _navigationToken) return;
      _selectRoot(_HabitDesktopSection.overview);
    });
  }

  void _openHabit(int habitId) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final token = ++_navigationToken;
    _returnToRoot();
    setState(() {
      _selectedSection = _HabitDesktopSection.detail;
      _selectedHabitId = habitId;
    });
    navigator
        .push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: '/habit-detail/$habitId'),
            builder: (_) => HabitDetailScreen(habitId: habitId),
          ),
        )
        .then((_) {
      if (!mounted || token != _navigationToken) return;
      _selectRoot(_HabitDesktopSection.overview);
    });
  }

  BuildContext? get _paneContext => _navigatorKey.currentState?.overlay?.context;

  Future<void> _addHabit() async {
    final paneContext = _paneContext;
    if (paneContext == null) return;
    await showCreateHabitSheet(paneContext, ref);
  }

  Future<void> _editHabit(Habit habit) async {
    final paneContext = _paneContext;
    if (paneContext == null) return;
    await showEditHabitSheet(paneContext, ref, habit);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(habitTrackerControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: Row(
        children: [
          _HabitModuleSidebar(
            state: state,
            selectedSection: _selectedSection,
            selectedHabitId: _selectedHabitId,
            onOverview: () => _selectRoot(_HabitDesktopSection.overview),
            onActive: () => _selectRoot(_HabitDesktopSection.active),
            onPaused: () => _selectRoot(_HabitDesktopSection.paused),
            onHistory: _openHistory,
            onHabit: _openHabit,
            onAddHabit: _addHabit,
            onBackToDashboard: () {
              final desktopScope = DesktopNavigationScope.maybeOf(context);
              if (desktopScope != null) {
                desktopScope.onDashboard();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: scheme.outlineVariant.withOpacity(.72),
          ),
          Expanded(
            child: ClipRect(
              child: Navigator(
                key: _navigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/habits-desktop-root'),
                  builder: (_) => ValueListenableBuilder<_HabitDesktopSection>(
                    valueListenable: _rootSection,
                    builder: (context, section, __) => _HabitDesktopOverview(
                      section: section,
                      onOpenHabit: _openHabit,
                      onEditHabit: _editHabit,
                      onAddHabit: _addHabit,
                      onOpenHistory: _openHistory,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitModuleSidebar extends StatelessWidget {
  const _HabitModuleSidebar({
    required this.state,
    required this.selectedSection,
    required this.selectedHabitId,
    required this.onOverview,
    required this.onActive,
    required this.onPaused,
    required this.onHistory,
    required this.onHabit,
    required this.onAddHabit,
    required this.onBackToDashboard,
  });

  final HabitTrackerState state;
  final _HabitDesktopSection selectedSection;
  final int? selectedHabitId;
  final VoidCallback onOverview;
  final VoidCallback onActive;
  final VoidCallback onPaused;
  final VoidCallback onHistory;
  final ValueChanged<int> onHabit;
  final VoidCallback onAddHabit;
  final VoidCallback onBackToDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = state.activeHabits;

    return SizedBox(
      width: 264,
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.habit.withOpacity(.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const CenteredFaIcon(
                      FontAwesomeIcons.bullseye,
                      color: AppColors.habit,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Habit Coach',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${state.activeHabits.length} active habits',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAddHabit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.habit,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 15),
                label: const Text('New habit'),
              ),
              const SizedBox(height: 18),
              const _SidebarLabel(text: 'WORKSPACE'),
              const SizedBox(height: 5),
              _SidebarItem(
                icon: FontAwesomeIcons.chartPie,
                label: 'Overview',
                selected: selectedSection == _HabitDesktopSection.overview,
                onTap: onOverview,
              ),
              _SidebarItem(
                icon: FontAwesomeIcons.calendarDays,
                label: 'History & calendar',
                selected: selectedSection == _HabitDesktopSection.history,
                onTap: onHistory,
              ),
              _SidebarItem(
                icon: FontAwesomeIcons.play,
                label: 'Active habits',
                badge: '${state.activeHabits.length}',
                selected: selectedSection == _HabitDesktopSection.active,
                onTap: onActive,
              ),
              _SidebarItem(
                icon: FontAwesomeIcons.pause,
                label: 'Paused habits',
                badge: '${state.habits.where((habit) => !habit.isActive).length}',
                selected: selectedSection == _HabitDesktopSection.paused,
                onTap: onPaused,
              ),
              const SizedBox(height: 12),
              const _SidebarLabel(text: 'HABITS'),
              const SizedBox(height: 6),
              Expanded(
                child: active.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: Text(
                          'Create a habit and it will appear here for quick access.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: active.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 3),
                        itemBuilder: (context, index) {
                          final habit = active[index];
                          return _HabitSidebarItem(
                            habit: habit,
                            selected: selectedSection ==
                                    _HabitDesktopSection.detail &&
                                selectedHabitId == habit.id,
                            onTap: () => onHabit(habit.id!),
                          );
                        },
                      ),
              ),
              Divider(color: scheme.outlineVariant.withOpacity(.7)),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onBackToDashboard,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to dashboard'),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

