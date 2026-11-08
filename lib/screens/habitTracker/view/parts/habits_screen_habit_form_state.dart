part of '../HabitsScreen.dart';

class _HabitFormState extends State<_HabitForm> {
  final title = TextEditingController();
  final description = TextEditingController();
  final reason = TextEditingController();
  final cue = TextEditingController();
  final reward = TextEditingController();
  TimeOfDay reminder = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay deadline = const TimeOfDay(hour: 23, minute: 59);
  String category = 'Personal growth';
  String difficulty = 'medium';
  int selectedIconCode = HabitIconCatalog.defaultIconCode;
  final days = <int>{1, 2, 3, 4, 5, 6, 7};

  bool get isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    if (habit == null) return;

    title.text = habit.title;
    description.text = habit.description ?? '';
    reason.text = habit.reason;
    cue.text = habit.cue;
    reward.text = habit.reward;
    reminder = habit.notificationTime ?? const TimeOfDay(hour: 9, minute: 0);
    deadline = TimeOfDay(
      hour: habit.deadlineHour,
      minute: habit.deadlineMinute,
    );
    category = habit.category;
    difficulty = habit.difficulty;
    selectedIconCode = habit.iconCode ?? HabitIconCatalog.defaultIconCode;
    days
      ..clear()
      ..addAll(habit.repeatDays);
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    reason.dispose();
    cue.dispose();
    reward.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Material(
      color: neutral.background,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
        children: [
          Row(children: [
            Expanded(
                child: Text(isEditing ? 'Edit habit' : 'Create a habit',
                    style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const CenteredFaIcon(FontAwesomeIcons.xmark))
          ]),
          Text(
              isEditing
                  ? 'Update the habit details without losing its progress history.'
                  : 'Define the action, why it matters, and the daily deadline.',
              style: TextStyle(color: neutral.textSecondary)),
          const SizedBox(height: 18),
          TextField(
              controller: title,
              decoration: const InputDecoration(
                  labelText: 'Habit name *', hintText: 'Read for 20 minutes')),
          const SizedBox(height: 12),
          TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                'Health',
                'Fitness',
                'Mindfulness',
                'Learning',
                'Productivity',
                'Personal growth'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => category = v!)),
          const SizedBox(height: 12),
          TextField(
              controller: reason,
              decoration: const InputDecoration(
                  labelText: 'Why does this matter?',
                  hintText: 'The identity or result you want')),
          const SizedBox(height: 12),
          TextField(
              controller: cue,
              decoration: const InputDecoration(
                  labelText: 'Trigger / cue', hintText: 'After breakfast...')),
          const SizedBox(height: 12),
          TextField(
              controller: reward,
              decoration: const InputDecoration(
                  labelText: 'Healthy reward',
                  hintText: 'Tea, music, five-minute break')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              value: difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('Easy')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'hard', child: Text('Hard'))
              ],
              onChanged: (v) => setState(() => difficulty = v!)),
          const SizedBox(height: 16),
          Text('Habit icon',
              style: TextStyle(
                  color: neutral.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: HabitIconCatalog.options.length,
            itemBuilder: (context, index) {
              final option = HabitIconCatalog.options[index];
              final selected = option.icon.codePoint == selectedIconCode;
              return Tooltip(
                message: option.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      setState(() => selectedIconCode = option.icon.codePoint),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.habit.withOpacity(.14)
                          : neutral.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.habit : neutral.divider,
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: CenteredFaIcon(
                      option.icon,
                      color: selected ? AppColors.habit : neutral.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Repeat days',
              style: TextStyle(
                  color: neutral.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              children: List.generate(7, (index) {
                final day = index + 1;
                final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return FilterChip(
                    label: Text(labels[index]),
                    selected: days.contains(day),
                    onSelected: (selected) => setState(
                        () => selected ? days.add(day) : days.remove(day)));
              })),
          const SizedBox(height: 12),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CenteredFaIcon(FontAwesomeIcons.bell),
              title: const Text('Reminder'),
              subtitle: Text(reminder.format(context)),
              trailing: const CenteredFaIcon(FontAwesomeIcons.angleRight),
              onTap: () async {
                final value = await showTimePicker(
                    context: context, initialTime: reminder);
                if (value != null) setState(() => reminder = value);
              }),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CenteredFaIcon(FontAwesomeIcons.clock),
              title: const Text('Daily update deadline'),
              subtitle: Text(
                  '${deadline.format(context)} · after this, the day is missed'),
              trailing: const CenteredFaIcon(FontAwesomeIcons.angleRight),
              onTap: () async {
                final value = await showTimePicker(
                    context: context, initialTime: deadline);
                if (value != null) setState(() => deadline = value);
              }),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.habit,
                minimumSize: const Size.fromHeight(52)),
            onPressed: () async {
              if (title.text.trim().isEmpty || days.isEmpty) return;
              final repeatDays = days.toList()..sort();
              final habit = widget.habit;
              if (habit == null) {
                await widget.controller.addHabit(
                    title: title.text,
                    description: description.text,
                    notificationTime: reminder,
                    category: category,
                    reason: reason.text,
                    cue: cue.text,
                    reward: reward.text,
                    difficulty: difficulty,
                    deadlineHour: deadline.hour,
                    deadlineMinute: deadline.minute,
                    repeatDays: repeatDays,
                    iconCode: selectedIconCode);
              } else {
                await widget.controller.editHabit(
                  habitId: habit.id!,
                  title: title.text,
                  description: description.text,
                  notificationTime: reminder,
                  category: category,
                  reason: reason.text,
                  cue: cue.text,
                  reward: reward.text,
                  difficulty: difficulty,
                  deadlineHour: deadline.hour,
                  deadlineMinute: deadline.minute,
                  repeatDays: repeatDays,
                  iconCode: selectedIconCode,
                );
              }
              if (mounted) Navigator.pop(context);
            },
            icon: CenteredFaIcon(
              isEditing ? FontAwesomeIcons.floppyDisk : FontAwesomeIcons.rocket,
            ),
            label: Text(isEditing ? 'Save changes' : 'Start habit'),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(
      {required this.icon, required this.text, required this.color});
  final FaIconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        CenteredFaIcon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text))
      ]));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(children: [
        const CenteredFaIcon(FontAwesomeIcons.bullseye,
            size: 68, color: AppColors.habit),
        const SizedBox(height: 14),
        const Text('Build your first system',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Start tiny, update daily, and let the streak grow.',
            textAlign: TextAlign.center),
        const SizedBox(height: 18),
        FilledButton(onPressed: onAdd, child: const Text('Create a habit'))
      ]));
}
