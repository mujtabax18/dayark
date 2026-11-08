part of '../QuotesScreen.dart';

class _DesktopQuotationPromptBuilderPage extends StatefulWidget {
  const _DesktopQuotationPromptBuilderPage({
    required this.initialCategory,
    required this.promptService,
    required this.onPreview,
    required this.onPasteGenerated,
  });

  final String initialCategory;
  final QuotationPromptService promptService;
  final Future<void> Function(QuotationPromptRequest request) onPreview;
  final Future<void> Function(QuotationPromptRequest request) onPasteGenerated;

  @override
  State<_DesktopQuotationPromptBuilderPage> createState() =>
      _DesktopQuotationPromptBuilderPageState();
}

class _DesktopQuotationPromptBuilderPageState
    extends State<_DesktopQuotationPromptBuilderPage> {
  late final TextEditingController _categoriesController;
  late final TextEditingController _purposeController;
  late final TextEditingController _extraController;

  String _tone = 'Uplifting';
  String _language = 'English';
  int _count = 5;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _categoriesController = TextEditingController(text: widget.initialCategory);
    _purposeController = TextEditingController(text: 'daily motivation');
    _extraController = TextEditingController();
  }

  @override
  void dispose() {
    _categoriesController.dispose();
    _purposeController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  QuotationPromptRequest _request() => QuotationPromptRequest(
        categories: _categoriesController.text.trim(),
        purpose: _purposeController.text.trim(),
        tone: _tone,
        language: _language,
        count: _count,
        extraInstructions: _extraController.text.trim(),
      );

  bool _validate() {
    if (_categoriesController.text.trim().isNotEmpty) return true;
    _showMessage('Add at least one category.', isError: true);
    return false;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
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
          'Prompt Builder',
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: DesktopContentFrame(
        maxWidth: 1080,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.habit.withOpacity(.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const CenteredFaIcon(
                            FontAwesomeIcons.wandMagicSparkles,
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
                                'Offline prompt builder',
                                style: TextStyle(
                                  color: neutral.textPrimary,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Build a prompt for any AI app without connecting an API or account.',
                                style: TextStyle(
                                  color: neutral.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _categoriesController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Categories *',
                        hintText: 'Fitness, study, discipline, business',
                        helperText:
                            'Add one category or separate many with commas.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _purposeController,
                      decoration: const InputDecoration(
                        labelText: 'Purpose',
                        hintText: 'Morning motivation, habit streak, success',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 620;
                        final toneField = DropdownButtonFormField<String>(
                          value: _tone,
                          decoration: const InputDecoration(
                            labelText: 'Tone',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            'Uplifting',
                            'Powerful',
                            'Calm',
                            'Direct',
                            'Reflective',
                          ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _tone = value);
                                  }
                                },
                        );
                        final languageField =
                            DropdownButtonFormField<String>(
                          value: _language,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            'English',
                            'Urdu',
                            'Roman Urdu',
                            'Arabic',
                          ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _language = value);
                                  }
                                },
                        );

                        if (compact) {
                          return Column(
                            children: [
                              toneField,
                              const SizedBox(height: 14),
                              languageField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: toneField),
                            const SizedBox(width: 14),
                            Expanded(child: languageField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _extraController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Extra instructions',
                        hintText: 'Keep each quotation under 18 words',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Number of quotations',
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DropdownButton<int>(
                          value: _count,
                          items: const [1, 3, 5, 8, 10, 15]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text('$value'),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _count = value);
                                  }
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.habit.withOpacity(.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CenteredFaIcon(
                            FontAwesomeIcons.circleInfo,
                            size: 16,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Copy the prompt, paste it into any AI app yourself, then return here and paste the generated quotations. The app remains fully offline.',
                              style: TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () {
                                  if (!_validate()) return;
                                  _run(() => widget.onPreview(_request()));
                                },
                          icon: const CenteredFaIcon(
                            FontAwesomeIcons.eye,
                            size: 15,
                          ),
                          label: const Text('Preview prompt'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.habit,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _busy
                              ? null
                              : () {
                                  if (!_validate()) return;
                                  _run(() async {
                                    final prompt =
                                        widget.promptService.buildPrompt(
                                      _request(),
                                    );
                                    await Clipboard.setData(
                                      ClipboardData(text: prompt),
                                    );
                                    _showMessage('Prompt copied.');
                                  });
                                },
                          icon: const CenteredFaIcon(
                            FontAwesomeIcons.copy,
                            size: 15,
                          ),
                          label: const Text('Copy prompt'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () {
                                  if (!_validate()) return;
                                  _run(
                                    () => widget.onPasteGenerated(_request()),
                                  );
                                },
                          icon: const CenteredFaIcon(
                            FontAwesomeIcons.paste,
                            size: 15,
                          ),
                          label: const Text('Paste generated quotations'),
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


class _DesktopPasteGeneratedQuotationsPage extends StatefulWidget {
  const _DesktopPasteGeneratedQuotationsPage({
    required this.request,
    required this.promptService,
    required this.onReview,
  });

  final QuotationPromptRequest request;
  final QuotationPromptService promptService;
  final Future<void> Function(List<Quotation> quotes) onReview;

  @override
  State<_DesktopPasteGeneratedQuotationsPage> createState() =>
      _DesktopPasteGeneratedQuotationsPageState();
}

