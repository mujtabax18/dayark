part of '../QuotesScreen.dart';

class QuotesScreenState extends ConsumerState<QuotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final QuotationPromptService _promptService = const QuotationPromptService();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.openCreateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showQuoteForm();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> openCreateForm() => _showQuoteForm();

  Future<void> openPromptBuilder() => _showPromptBuilder();

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final state = ref.watch(quotationControllerProvider);
    final controller = ref.read(quotationControllerProvider.notifier);

    ref.listen<QuotationState>(quotationControllerProvider, (previous, next) {
      if (previous?.quotations.length != next.quotations.length) {
        ref.invalidate(quotationCountProvider);
        ref.invalidate(homeQuoteProvider);
      }
      if (next.error != null && next.error != previous?.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMessage(next.error!, isError: true);
        });
      }
    });

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        elevation: 0,
        title: Text(
          'Quotation Studio',
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Online quotation library',
            onPressed: _showOnlineLibrary,
            icon: const Icon(Icons.cloud_download_outlined),
          ),
          IconButton(
            tooltip: 'Offline prompt builder',
            onPressed: _showPromptBuilder,
            icon: const CenteredFaIcon(FontAwesomeIcons.terminal, size: 18),
          ),
          PopupMenuButton<String>(
            icon: const CenteredFaIcon(
              FontAwesomeIcons.ellipsisVertical,
              size: 18,
            ),
            onSelected: (value) {
              if (value == 'manage') _showManagement();
              if (value == 'import') _importJson();
              if (value == 'export') _exportJson(state.quotations);
              if (value == 'sort_newest') {
                controller.setSort(QuotationSort.newest);
              }
              if (value == 'sort_used') {
                controller.setSort(QuotationSort.mostUsed);
              }
              if (value == 'sort_az') {
                controller.setSort(QuotationSort.alphabetical);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18),
                    SizedBox(width: 12),
                    Text('Manage library'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'sort_newest',
                child: Row(
                  children: [
                    Icon(
                      state.sort == QuotationSort.newest
                          ? Icons.check
                          : Icons.schedule,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    const Text('Sort: Newest'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sort_used',
                child: Row(
                  children: [
                    Icon(
                      state.sort == QuotationSort.mostUsed
                          ? Icons.check
                          : Icons.trending_up,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    const Text('Sort: Most used'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sort_az',
                child: Row(
                  children: [
                    Icon(
                      state.sort == QuotationSort.alphabetical
                          ? Icons.check
                          : Icons.sort_by_alpha,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    const Text('Sort: A–Z'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    CenteredFaIcon(FontAwesomeIcons.fileImport, size: 16),
                    SizedBox(width: 12),
                    Text('Import JSON'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    CenteredFaIcon(
                      Platform.isLinux
                          ? FontAwesomeIcons.download
                          : FontAwesomeIcons.fileExport,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      Platform.isLinux
                          ? 'Download visible quotes'
                          : 'Export visible quotes',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: widget.desktopEmbedded
          ? null
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'quotation_prompt',
            backgroundColor: neutral.card,
            foregroundColor: AppColors.habit,
            tooltip: 'Build quotation prompt',
            onPressed: _showPromptBuilder,
            child: const CenteredFaIcon(
              FontAwesomeIcons.wandMagicSparkles,
              size: 18,
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'new_quote',
            backgroundColor: AppColors.habit,
            foregroundColor: Colors.white,
            onPressed: () => _showQuoteForm(),
            icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 17),
            label: const Text('New quote'),
          ),
        ],
      ),
      body: DesktopContentFrame(
        child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _HeroCard(
                  total: state.quotations.length,
                  favoriteCount: state.quotations
                      .where((item) => item.isFavorite)
                      .length,
                  onRandom: _openRandomQuote,
                  onPrompt: _showPromptBuilder,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {});
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 350),
                      () => controller.setSearch(value),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search quotation, author or category',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              controller.setSearch('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: neutral.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: neutral.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: neutral.divider),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 58,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: const CenteredFaIcon(
                          FontAwesomeIcons.heart,
                          size: 13,
                        ),
                        label: const Text('Favorites'),
                        selected: state.favoritesOnly,
                        onSelected: controller.setFavoritesOnly,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: const Icon(Icons.cloud_done_outlined, size: 16),
                        label: const Text('Online'),
                        selected: state.onlineOnly,
                        onSelected: controller.setOnlineOnly,
                      ),
                    ),
                    ...['All', ...state.categories].map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: state.category == category,
                          onSelected: (_) => controller.setCategory(category),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.isLoading && state.quotations.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.quotations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  onAdd: () => _showQuoteForm(),
                  onPrompt: _showPromptBuilder,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  widget.desktopEmbedded ? 32 : 120,
                ),
                sliver: SliverList.separated(
                  itemCount: state.quotations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final quote = state.quotations[index];
                    return _QuotationCard(
                      quotation: quote,
                      onFavorite: () => controller.toggleFavorite(quote),
                      onCopy: () => _copyQuote(quote),
                      onShare: () => Platform.isLinux
                          ? _downloadText(quote)
                          : _shareText(quote),
                      shareLabel: Platform.isLinux ? 'Download' : 'Share',
                      shareIcon: Platform.isLinux
                          ? FontAwesomeIcons.download
                          : FontAwesomeIcons.shareNodes,
                      onImage: () => _openEditor(quote),
                      onEdit: () => _showQuoteForm(existing: quote),
                      onDelete: () => _confirmDelete(quote),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _showOnlineLibrary() async {
    if (widget.onOpenOnlineLibrary != null) {
      widget.onOpenOnlineLibrary!();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const OnlineQuotationLibrarySheet(),
    );
  }

  Future<void> _showManagement() async {
    if (widget.onOpenManagement != null) {
      widget.onOpenManagement!();
      return;
    }
    final state = ref.read(quotationControllerProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuotationManagementSheet(currentCategory: state.category),
    );
  }

  Future<void> _showQuoteForm({Quotation? existing}) async {
    if (widget.desktopEmbedded) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: existing == null
                ? '/quotations-desktop/new'
                : '/quotations-desktop/edit/${existing.id ?? 'local'}',
          ),
          builder: (_) => _DesktopQuotationFormPage(existing: existing),
        ),
      );
      return;
    }

    final text = TextEditingController(text: existing?.text ?? '');
    final author = TextEditingController(text: existing?.author ?? '');
    final category = TextEditingController(text: existing?.category ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final neutral = sheetContext.themeColors.neutral;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: neutral.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                existing == null ? 'Add quotation' : 'Edit quotation',
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: text,
                minLines: 4,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Quotation *',
                  hintText: 'Write the motivational quotation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: category,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'Discipline',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: author,
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.habit,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () async {
                    if (text.text.trim().isEmpty) {
                      _showMessage(
                        'Quotation text is required.',
                        isError: true,
                      );
                      return;
                    }
                    final now = DateTime.now();
                    final quote =
                        (existing ??
                                Quotation(
                                  text: text.text.trim(),
                                  createdAt: now,
                                ))
                            .copyWith(
                              text: text.text.trim(),
                              author: author.text.trim(),
                              category: category.text.trim().isEmpty
                                  ? 'General'
                                  : category.text.trim(),
                              updatedAt: now,
                            );
                    final id = await ref
                        .read(quotationControllerProvider.notifier)
                        .save(quote);
                    if (!sheetContext.mounted || id == null) return;
                    Navigator.pop(sheetContext);
                    _showMessage(
                      existing == null
                          ? 'Quotation saved.'
                          : 'Quotation updated.',
                    );
                  },
                  icon: const CenteredFaIcon(
                    FontAwesomeIcons.floppyDisk,
                    size: 16,
                  ),
                  label: Text(
                    existing == null ? 'Save quotation' : 'Save changes',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    text.dispose();
    author.dispose();
    category.dispose();
  }

  Future<void> _showPromptBuilder() async {
    final state = ref.read(quotationControllerProvider);

    // Desktop quotations use a nested admin-style Navigator. Keeping the
    // prompt builder as a modal bottom sheet made sidebar navigation race with
    // the sheet's teardown (for example Prompt Builder -> Manage Library).
    // Use a normal page route on desktop so switching tools cleanly disposes
    // the page only after the Navigator has finished the route transition.
    if (widget.desktopEmbedded) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(
            name: '/quotations-desktop/prompt-builder',
          ),
          builder: (_) => _DesktopQuotationPromptBuilderPage(
            initialCategory: state.category == 'All' ? '' : state.category,
            promptService: _promptService,
            onPreview: _showPromptPreview,
            onPasteGenerated: _showPasteGeneratedText,
          ),
        ),
      );
      return;
    }

    final categories = TextEditingController(
      text: state.category == 'All' ? '' : state.category,
    );
    final purpose = TextEditingController(text: 'daily motivation');
    final extra = TextEditingController();
    String tone = 'Uplifting';
    String language = 'English';
    int count = 5;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final neutral = context.themeColors.neutral;

            QuotationPromptRequest request() => QuotationPromptRequest(
              categories: categories.text.trim(),
              purpose: purpose.text.trim(),
              tone: tone,
              language: language,
              count: count,
              extraInstructions: extra.text.trim(),
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: neutral.divider,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.habit.withOpacity(.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: CenteredFaIcon(
                          FontAwesomeIcons.wandMagicSparkles,
                          color: AppColors.habit,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline prompt builder',
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'No API, account or internet connection is used.',
                              style: TextStyle(color: neutral.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: categories,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Categories *',
                      hintText: 'Fitness, study, discipline, business',
                      helperText:
                          'Add one category or separate many with commas.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: purpose,
                    decoration: const InputDecoration(
                      labelText: 'Purpose',
                      hintText: 'Morning motivation, habit streak, success',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tone,
                          decoration: const InputDecoration(
                            labelText: 'Tone',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              const [
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
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => tone = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: language,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              const ['English', 'Urdu', 'Roman Urdu', 'Arabic']
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => language = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: extra,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Extra instructions',
                      hintText: 'Keep each quotation under 18 words',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        value: count,
                        items: const [1, 3, 5, 8, 10, 15]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => count = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.habit.withOpacity(.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CenteredFaIcon(FontAwesomeIcons.circleInfo, size: 16),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Copy the prompt, paste it into any AI app yourself, then return here and paste the generated quotations. This app remains fully offline.',
                            style: TextStyle(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (categories.text.trim().isEmpty) {
                              _showMessage(
                                'Add at least one category.',
                                isError: true,
                              );
                              return;
                            }
                            await _showPromptPreview(request());
                          },
                          icon: const CenteredFaIcon(
                            FontAwesomeIcons.eye,
                            size: 15,
                          ),
                          label: const Text('Preview'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.habit,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (categories.text.trim().isEmpty) {
                              _showMessage(
                                'Add at least one category.',
                                isError: true,
                              );
                              return;
                            }
                            final prompt = _promptService.buildPrompt(
                              request(),
                            );
                            await Clipboard.setData(
                              ClipboardData(text: prompt),
                            );
                            _showMessage('Prompt copied.');
                          },
                          icon: const CenteredFaIcon(
                            FontAwesomeIcons.copy,
                            size: 15,
                          ),
                          label: const Text('Copy prompt'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (categories.text.trim().isEmpty) {
                          _showMessage(
                            'Add at least one category.',
                            isError: true,
                          );
                          return;
                        }
                        Navigator.pop(sheetContext);
                        await _showPasteGeneratedText(request());
                      },
                      icon: const CenteredFaIcon(
                        FontAwesomeIcons.paste,
                        size: 15,
                      ),
                      label: const Text('Paste generated quotations'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    categories.dispose();
    purpose.dispose();
    extra.dispose();
  }

  Future<void> _showPromptPreview(QuotationPromptRequest request) async {
    final prompt = _promptService.buildPrompt(request);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            CenteredFaIcon(FontAwesomeIcons.terminal, size: 18),
            SizedBox(width: 10),
            Text('Quotation prompt'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(child: SelectableText(prompt)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: prompt));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _showMessage('Prompt copied.');
            },
            icon: const CenteredFaIcon(FontAwesomeIcons.copy, size: 14),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPasteGeneratedText(QuotationPromptRequest request) async {
    if (widget.desktopEmbedded) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(
            name: '/quotations-desktop/prompt-builder/paste',
          ),
          builder: (_) => _DesktopPasteGeneratedQuotationsPage(
            request: request,
            promptService: _promptService,
            onReview: _showGeneratedResults,
          ),
        ),
      );
      return;
    }

    final response = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final neutral = sheetContext.themeColors.neutral;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: neutral.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Paste generated quotations',
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'JSON output works best, but numbered quotation lines are also supported.',
                style: TextStyle(color: neutral.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: response,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  hintText: 'Paste the generated JSON or quotation list here',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.habit,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () async {
                    final quotes = _promptService.parsePastedText(
                      response.text,
                      request,
                    );
                    if (quotes.isEmpty) {
                      _showMessage(
                        'No usable quotations were found.',
                        isError: true,
                      );
                      return;
                    }
                    Navigator.pop(sheetContext);
                    await _showGeneratedResults(quotes);
                  },
                  icon: const CenteredFaIcon(
                    FontAwesomeIcons.listCheck,
                    size: 16,
                  ),
                  label: const Text('Review quotations'),
                ),
              ),
            ],
          ),
        );
      },
    );
    response.dispose();
  }

  Future<void> _showGeneratedResults(List<Quotation> initialQuotes) async {
    if (widget.desktopEmbedded) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(
            name: '/quotations-desktop/prompt-builder/review',
          ),
          builder: (_) => _DesktopGeneratedQuotationReviewPage(
            initialQuotes: initialQuotes,
          ),
        ),
      );
      return;
    }

    final quotes = List<Quotation>.from(initialQuotes);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final neutral = context.themeColors.neutral;
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * .86,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                    child: Row(
                      children: [
                        const CenteredFaIcon(
                          FontAwesomeIcons.wandMagicSparkles,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Generated quotation review',
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: quotes.isEmpty
                              ? null
                              : () async {
                                  await ref
                                      .read(
                                        quotationControllerProvider.notifier,
                                      )
                                      .saveMany(quotes);
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  _showMessage('All quotations saved.');
                                },
                          child: const Text('Save all'),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const CenteredFaIcon(
                            FontAwesomeIcons.xmark,
                            size: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: neutral.divider),
                  Expanded(
                    child: quotes.isEmpty
                        ? const Center(child: Text('No quotations remaining.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: quotes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final quote = quotes[index];
                              return Container(
                                padding: const EdgeInsets.all(15),
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
                                        fontSize: 16,
                                        height: 1.35,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      quote.category,
                                      style: TextStyle(
                                        color: neutral.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _SmallAction(
                                          icon: FontAwesomeIcons.copy,
                                          label: 'Copy',
                                          onTap: () => _copyQuote(quote),
                                        ),
                                        _SmallAction(
                                          icon: FontAwesomeIcons.pen,
                                          label: 'Edit',
                                          onTap: () async {
                                            final edited =
                                                await _editGeneratedQuote(
                                                  quote,
                                                );
                                            if (edited != null) {
                                              setSheetState(
                                                () => quotes[index] = edited,
                                              );
                                            }
                                          },
                                        ),
                                        _SmallAction(
                                          icon: FontAwesomeIcons.floppyDisk,
                                          label: 'Save',
                                          onTap: () async {
                                            await ref
                                                .read(
                                                  quotationControllerProvider
                                                      .notifier,
                                                )
                                                .save(quote);
                                            setSheetState(
                                              () => quotes.removeAt(index),
                                            );
                                            _showMessage('Quotation saved.');
                                          },
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: 'Remove',
                                          onPressed: () => setSheetState(
                                            () => quotes.removeAt(index),
                                          ),
                                          icon: const CenteredFaIcon(
                                            FontAwesomeIcons.trash,
                                            size: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Quotation?> _editGeneratedQuote(Quotation quote) async {
    final text = TextEditingController(text: quote.text);
    final author = TextEditingController(text: quote.author);
    final category = TextEditingController(text: quote.category);
    Quotation? result;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit generated quotation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: text,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Quotation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: author,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
    return result;
  }

  Future<void> _openRandomQuote() async {
    final quote = await ref
        .read(quotationControllerProvider.notifier)
        .randomQuote();
    if (!mounted) return;
    if (quote == null) {
      _showMessage('Add quotations first.', isError: true);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your motivation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CenteredFaIcon(
              FontAwesomeIcons.quoteLeft,
              color: AppColors.habit,
              size: 28,
            ),
            const SizedBox(height: 14),
            Text(
              quote.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (quote.author.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('— ${quote.author}'),
            ],
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copyQuote(quote),
            icon: const CenteredFaIcon(FontAwesomeIcons.copy, size: 14),
            label: const Text('Copy'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openEditor(quote);
            },
            icon: const CenteredFaIcon(FontAwesomeIcons.image, size: 14),
            label: const Text('Create image'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(Quotation quote) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuotationEditorScreen(quotation: quote),
      ),
    );
  }

  Future<void> _copyQuote(Quotation quote) async {
    await Clipboard.setData(ClipboardData(text: quote.shareText));
    await ref.read(quotationControllerProvider.notifier).registerUse(quote);
    if (mounted) _showMessage('Quotation copied.');
  }

  Future<void> _shareText(Quotation quote) async {
    await SharePlus.instance.share(ShareParams(text: quote.shareText));
    await ref.read(quotationControllerProvider.notifier).registerUse(quote);
  }

  Future<void> _downloadText(Quotation quote) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(quote.shareText));
      final location = await FilePicker.saveFile(
        dialogTitle: 'Download quotation',
        fileName: 'quotation_${DateTime.now().millisecondsSinceEpoch}.txt',
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        bytes: bytes,
      );
      if (location == null || !mounted) return;
      await ref.read(quotationControllerProvider.notifier).registerUse(quote);
      _showMessage('Quotation downloaded.');
    } catch (error) {
      if (mounted) _showMessage('Download failed: $error', isError: true);
    }
  }

  Future<void> _confirmDelete(Quotation quote) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete quotation?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(quotationControllerProvider.notifier).delete(quote);
  }

  Future<void> _importJson() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );

      if (pickedFiles == null || pickedFiles.isEmpty) return;

      final path = pickedFiles.single.path;
      if (path == null || path.isEmpty) {
        throw const FileSystemException(
          'The selected JSON file could not be accessed.',
        );
      }

      final decoded = jsonDecode(await File(path).readAsString());

      if (decoded is! List) {
        throw const FormatException('Expected a JSON list.');
      }

      final now = DateTime.now();

      final quotes = decoded
          .whereType<Map>()
          .map((raw) {
            final item = Map<String, dynamic>.from(raw);

            final text = item['text']?.toString().trim() ?? '';
            if (text.isEmpty) return null;

            final category = item['category']?.toString().trim() ?? '';

            return Quotation(
              text: text,
              author: item['author']?.toString().trim() ?? '',
              category: category.isEmpty ? 'General' : category,
              source: 'import',
              isFavorite:
                  item['is_favorite'] == 1 || item['isFavorite'] == true,
              createdAt: now,
            );
          })
          .whereType<Quotation>()
          .toList(growable: false);

      if (quotes.isEmpty) {
        _showMessage(
          'No valid quotations were found in the selected file.',
          isError: true,
        );
        return;
      }

      final importResult = await ref
          .read(quotationControllerProvider.notifier)
          .importMany(quotes);

      if (!mounted) return;

      _showMessage(
        '${importResult.inserted} quotations imported'
        '${importResult.skipped > 0 ? ', ${importResult.skipped} duplicates skipped' : ''}.',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Import failed: $error', isError: true);
      }
    }
  }

  Future<void> _exportJson(List<Quotation> quotes) async {
    if (quotes.isEmpty) {
      _showMessage('There are no visible quotations to export.', isError: true);
      return;
    }

    final data = quotes.map((quote) => quote.toMap()).toList(growable: false);
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
    if (Platform.isLinux) {
      try {
        final location = await FilePicker.saveFile(
          dialogTitle: 'Download quotation export',
          fileName: 'quotations_export.json',
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: bytes,
        );
        if (location != null && mounted) {
          _showMessage('Quotation export downloaded.');
        }
      } catch (error) {
        if (mounted) _showMessage('Export failed: $error', isError: true);
      }
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: 'Quotation Studio export',
        files: [XFile.fromData(bytes, mimeType: 'application/json')],
        fileNameOverrides: ['quotations_export.json'],
      ),
    );
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
}


