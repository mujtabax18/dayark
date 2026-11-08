part of '../QuotesScreen.dart';

class _DesktopPasteGeneratedQuotationsPageState
    extends State<_DesktopPasteGeneratedQuotationsPage> {
  late final TextEditingController _responseController;
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    _responseController = TextEditingController();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _review() async {
    if (_reviewing) return;
    final quotes = widget.promptService.parsePastedText(
      _responseController.text,
      widget.request,
    );
    if (quotes.isEmpty) {
      _showMessage('No usable quotations were found.', isError: true);
      return;
    }

    setState(() => _reviewing = true);
    try {
      await widget.onReview(quotes);
    } finally {
      if (mounted) setState(() => _reviewing = false);
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
          'Paste Generated Quotations',
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
                    Text(
                      'Paste AI output',
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'JSON output works best, but numbered quotation lines are also supported.',
                      style: TextStyle(
                        color: neutral.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _responseController,
                      minLines: 14,
                      maxLines: 24,
                      enabled: !_reviewing,
                      decoration: const InputDecoration(
                        hintText:
                            'Paste the generated JSON or quotation list here',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.habit,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(190, 48),
                        ),
                        onPressed: _reviewing ? null : _review,
                        icon: _reviewing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const CenteredFaIcon(
                                FontAwesomeIcons.listCheck,
                                size: 15,
                              ),
                        label: const Text('Review quotations'),
                      ),
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

class _DesktopGeneratedQuotationReviewPage
    extends ConsumerStatefulWidget {
  const _DesktopGeneratedQuotationReviewPage({required this.initialQuotes});

  final List<Quotation> initialQuotes;

  @override
  ConsumerState<_DesktopGeneratedQuotationReviewPage> createState() =>
      _DesktopGeneratedQuotationReviewPageState();
}

class _DesktopGeneratedQuotationReviewPageState
    extends ConsumerState<_DesktopGeneratedQuotationReviewPage> {
  late final List<Quotation> _quotes;
  bool _savingAll = false;

  @override
  void initState() {
    super.initState();
    _quotes = List<Quotation>.from(widget.initialQuotes);
  }

  Future<void> _saveAll() async {
    if (_savingAll || _quotes.isEmpty) return;
    setState(() => _savingAll = true);
    try {
      await ref.read(quotationControllerProvider.notifier).saveMany(_quotes);
      if (!mounted) return;
      _showMessage('All quotations saved.');
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
  }

  Future<void> _saveOne(int index) async {
    if (index < 0 || index >= _quotes.length) return;
    final quote = _quotes[index];
    await ref.read(quotationControllerProvider.notifier).save(quote);
    if (!mounted) return;
    setState(() => _quotes.removeAt(index));
    _showMessage('Quotation saved.');
  }

  Future<void> _copy(Quotation quote) async {
    await Clipboard.setData(ClipboardData(text: quote.shareText));
    await ref.read(quotationControllerProvider.notifier).registerUse(quote);
    if (mounted) _showMessage('Quotation copied.');
  }

  Future<void> _edit(int index) async {
    if (index < 0 || index >= _quotes.length) return;
    final quote = _quotes[index];
    final text = TextEditingController(text: quote.text);
    final author = TextEditingController(text: quote.author);
    final category = TextEditingController(text: quote.category);
    Quotation? result;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit generated quotation'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Quotation',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: author,
                        decoration: const InputDecoration(
                          labelText: 'Author',
                          hintText: 'Optional',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (text.text.trim().isEmpty) return;
              result = quote.copyWith(
                text: text.text.trim(),
                author: author.text.trim(),
                category: category.text.trim().isEmpty
                    ? 'General'
                    : category.text.trim(),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    text.dispose();
    author.dispose();
    category.dispose();

    if (!mounted || result == null) return;
    setState(() => _quotes[index] = result!);
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
          'Review Generated Quotations',
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton.icon(
              onPressed: _quotes.isEmpty || _savingAll ? null : _saveAll,
              icon: _savingAll
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const CenteredFaIcon(
                      FontAwesomeIcons.floppyDisk,
                      size: 14,
                    ),
              label: const Text('Save all'),
            ),
          ),
        ],
      ),
      body: DesktopContentFrame(
        maxWidth: 1180,
        child: _quotes.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No quotations remaining.',
                    style: TextStyle(color: neutral.textSecondary),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                itemCount: _quotes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final quote = _quotes[index];
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: neutral.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: neutral.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.text,
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 17,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Text(
                              quote.category,
                              style: TextStyle(
                                color: AppColors.habit,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (quote.author.trim().isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Text(
                                '— ${quote.author}',
                                style: TextStyle(
                                  color: neutral.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _copy(quote),
                              icon: const CenteredFaIcon(
                                FontAwesomeIcons.copy,
                                size: 13,
                              ),
                              label: const Text('Copy'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _edit(index),
                              icon: const CenteredFaIcon(
                                FontAwesomeIcons.pen,
                                size: 13,
                              ),
                              label: const Text('Edit'),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.habit,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _saveOne(index),
                              icon: const CenteredFaIcon(
                                FontAwesomeIcons.floppyDisk,
                                size: 13,
                              ),
                              label: const Text('Save'),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _quotes.removeAt(index),
                              ),
                              icon: const CenteredFaIcon(
                                FontAwesomeIcons.trash,
                                size: 13,
                              ),
                              label: const Text('Remove'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

