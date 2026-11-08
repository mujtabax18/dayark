import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../models/quotation.dart';
import '../controller/quotation_controller.dart';
import '../widgets/quotation_poster.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

class QuotationEditorScreen extends ConsumerStatefulWidget {
  const QuotationEditorScreen({super.key, required this.quotation});

  final Quotation quotation;

  @override
  ConsumerState<QuotationEditorScreen> createState() =>
      _QuotationEditorScreenState();
}

class _QuotationEditorScreenState extends ConsumerState<QuotationEditorScreen> {
  final GlobalKey _posterKey = GlobalKey();
  late String _themeKey;
  late double _fontSize;
  late TextAlign _alignment;
  late bool _showAuthor;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _themeKey = widget.quotation.backgroundStyle;
    _fontSize = widget.quotation.fontSize.clamp(20, 46).toDouble();
    _alignment = _textAlignFromStorage(widget.quotation.textAlign);
    _showAuthor = widget.quotation.showAuthor;
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final posterTheme = QuotationPosterTheme.byKey(_themeKey);

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        title: Text(
          'Create Status Image',
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy quotation',
            onPressed: _copyText,
            icon: const CenteredFaIcon(FontAwesomeIcons.copy),
          ),
        ],
      ),
      body: DesktopContentFrame(
        child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 370),
                child: RepaintBoundary(
                  key: _posterKey,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: QuotationPoster(
                      quotation: widget.quotation,
                      theme: posterTheme,
                      fontSize: _fontSize,
                      alignment: _alignment,
                      showAuthor: _showAuthor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Background style',
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: QuotationPosterTheme.all.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = QuotationPosterTheme.all[index];
                  final selected = item.key == _themeKey;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _themeKey = item.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 92,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? AppColors.habit : neutral.divider,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(colors: item.colors),
                        ),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: item.foreground,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Text size',
                    style: TextStyle(
                      color: neutral.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _fontSize.round().toString(),
                  style: TextStyle(color: neutral.textSecondary),
                ),
              ],
            ),
            Slider(
              value: _fontSize,
              min: 20,
              max: 46,
              divisions: 26,
              activeColor: AppColors.habit,
              onChanged: (value) => setState(() => _fontSize = value),
            ),
            Row(
              children: [
                Text(
                  'Alignment',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                SegmentedButton<TextAlign>(
                  segments: const [
                    ButtonSegment(
                      value: TextAlign.left,
                      icon: CenteredFaIcon(
                        FontAwesomeIcons.alignLeft,
                        size: 14,
                      ),
                    ),
                    ButtonSegment(
                      value: TextAlign.center,
                      icon: CenteredFaIcon(
                        FontAwesomeIcons.alignCenter,
                        size: 14,
                      ),
                    ),
                    ButtonSegment(
                      value: TextAlign.right,
                      icon: CenteredFaIcon(
                        FontAwesomeIcons.alignRight,
                        size: 14,
                      ),
                    ),
                  ],
                  selected: {_alignment},
                  onSelectionChanged: (selection) {
                    setState(() => _alignment = selection.first);
                  },
                ),
              ],
            ),
            if (widget.quotation.author.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show author'),
                value: _showAuthor,
                activeColor: AppColors.habit,
                onChanged: (value) => setState(() => _showAuthor = value),
              ),
            ],
          ],
        ),
      ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(14),
        child: Platform.isLinux
            ? SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.habit,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _busy ? null : _savePng,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const CenteredFaIcon(
                          FontAwesomeIcons.download,
                          size: 16,
                        ),
                  label: const Text('Download PNG'),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _savePng,
                      icon: const CenteredFaIcon(
                        FontAwesomeIcons.download,
                        size: 16,
                      ),
                      label: const Text('Save PNG'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.habit,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: _busy ? null : _sharePng,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const CenteredFaIcon(
                              FontAwesomeIcons.whatsapp,
                              size: 17,
                            ),
                      label: const Text('Share / Status'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<Uint8List> _capturePng() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('The quotation image is not ready.');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) throw StateError('Could not create PNG data.');
    return byteData.buffer.asUint8List();
  }

  Future<void> _savePng() async {
    await _runBusy(() async {
      final bytes = await _capturePng();
      final fileName = _fileName();
      final location = await FilePicker.saveFile(
        dialogTitle: 'Save quotation image',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: bytes,
      );
      if (!mounted || location == null) return;
      await _persistDesign();
      _showMessage('Image saved successfully.');
    });
  }

  Future<void> _sharePng() async {
    await _runBusy(() async {
      final bytes = await _capturePng();
      await SharePlus.instance.share(
        ShareParams(
          text: widget.quotation.shareText,
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: [_fileName()],
        ),
      );
      await ref
          .read(quotationControllerProvider.notifier)
          .registerUse(widget.quotation);
      await _persistDesign();
    });
  }

  Future<void> _persistDesign() async {
    if (widget.quotation.id == null) return;
    await ref
        .read(quotationControllerProvider.notifier)
        .save(
          widget.quotation.copyWith(
            backgroundStyle: _themeKey,
            fontSize: _fontSize,
            textAlign: _storageTextAlign(_alignment),
            showAuthor: _showAuthor,
          ),
        );
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: widget.quotation.shareText));
    if (!mounted) return;
    await ref
        .read(quotationControllerProvider.notifier)
        .registerUse(widget.quotation);
    _showMessage('Quotation copied.');
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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

  String _fileName() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'quotation_status_$stamp.png';
  }

  static TextAlign _textAlignFromStorage(String value) {
    return switch (value) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };
  }

  static String _storageTextAlign(TextAlign value) {
    return switch (value) {
      TextAlign.left => 'left',
      TextAlign.right => 'right',
      _ => 'center',
    };
  }
}
