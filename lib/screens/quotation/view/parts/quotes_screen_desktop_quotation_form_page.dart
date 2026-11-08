part of '../QuotesScreen.dart';

class _DesktopQuotationFormPage extends ConsumerStatefulWidget {
  const _DesktopQuotationFormPage({this.existing});

  final Quotation? existing;

  @override
  ConsumerState<_DesktopQuotationFormPage> createState() =>
      _DesktopQuotationFormPageState();
}

class _DesktopQuotationFormPageState
    extends ConsumerState<_DesktopQuotationFormPage> {
  late final TextEditingController _textController;
  late final TextEditingController _authorController;
  late final TextEditingController _categoryController;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.existing?.text ?? '');
    _authorController =
        TextEditingController(text: widget.existing?.author ?? '');
    _categoryController =
        TextEditingController(text: widget.existing?.category ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    _authorController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_textController.text.trim().isEmpty) {
      _showMessage('Quotation text is required.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final quote =
          (widget.existing ??
                  Quotation(
                    text: _textController.text.trim(),
                    createdAt: now,
                  ))
              .copyWith(
                text: _textController.text.trim(),
                author: _authorController.text.trim(),
                category: _categoryController.text.trim().isEmpty
                    ? 'General'
                    : _categoryController.text.trim(),
                updatedAt: now,
              );

      final id =
          await ref.read(quotationControllerProvider.notifier).save(quote);
      if (!mounted || id == null) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Quotation updated.' : 'Quotation saved.',
            ),
          ),
        );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit quotation' : 'New quotation',
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: DesktopContentFrame(
        maxWidth: 980,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: neutral.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: neutral.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.habit.withOpacity(.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const CenteredFaIcon(
                            FontAwesomeIcons.quoteLeft,
                            color: AppColors.habit,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEditing
                                    ? 'Update quotation details'
                                    : 'Create a quotation',
                                style: TextStyle(
                                  color: neutral.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Keep the quote, category and optional author together in your local library.',
                                style: TextStyle(
                                  color: neutral.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _textController,
                      minLines: 5,
                      maxLines: 9,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Quotation *',
                        hintText: 'Write the motivational quotation',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _categoryController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              hintText: 'Discipline',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _authorController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Author',
                              hintText: 'Optional',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.habit,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(170, 48),
                          ),
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const CenteredFaIcon(
                                  FontAwesomeIcons.floppyDisk,
                                  size: 15,
                                ),
                          label: Text(
                            _isEditing ? 'Save changes' : 'Save quotation',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.total,
    required this.favoriteCount,
    required this.onRandom,
    required this.onPrompt,
  });

  final int total;
  final int favoriteCount;
  final VoidCallback onRandom;
  final VoidCallback onPrompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.habit, AppColors.habit.withOpacity(.70)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CenteredFaIcon(
                FontAwesomeIcons.quoteLeft,
                color: Colors.white,
                size: 22,
              ),
              Spacer(),
              Text(
                'MOTIVATION LIBRARY',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Save words that move you.\nTurn them into shareable moments.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(value: '$total', label: 'Quotes'),
              _HeroStat(value: '$favoriteCount', label: 'Favorites'),
              const Spacer(),
              IconButton.filledTonal(
                tooltip: 'Random quote',
                onPressed: onRandom,
                icon: const CenteredFaIcon(FontAwesomeIcons.shuffle, size: 16),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Offline prompt builder',
                onPressed: onPrompt,
                icon: const CenteredFaIcon(
                  FontAwesomeIcons.wandMagicSparkles,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

