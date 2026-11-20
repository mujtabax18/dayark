part of 'ai_chat_screen.dart';

extension _AiChatActions on _AiChatScreenState {
  Future<String?> _editText(
    String title,
    String initial, {
    String action = 'Save',
    String? note,
  }) => showDialog<String>(
    context: context,
    useRootNavigator: false,
    builder: (_) => _AiChatTextDialog(
      title: title,
      initial: initial,
      action: action,
      note: note,
    ),
  );

  Future<void> _action(String action) async {
    final chat = _chat!;
    if (chat.busy) return;
    final c = chat.active;
    try {
      switch (action) {
        case 'rename':
          final name = await _editText('Rename conversation', c!.title);
          if (name?.isNotEmpty ?? false) await chat.update(title: name);
        case 'folder':
          final name = await _chooseFolder(c!.folder);
          if (name != null) await chat.update(folder: name);
        case 'pin':
          await chat.update(pinned: !c!.pinned);
        case 'archive':
          await chat.update(archived: !c!.archived);
        case 'delete':
          final yes = await showDialog<bool>(
            context: context,
            useRootNavigator: false,
            builder: (context) => AlertDialog(
              title: const Text('Delete conversation?'),
              content: const Text(
                'Messages and attachments will be removed. Shared deletion will sync to opted-in devices.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (yes == true) await chat.remove();
        case 'json':
        case 'md':
        case 'txt':
          final bytes = Uint8List.fromList(
            utf8.encode(chat.store.export(c!, action)),
          );
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(
                  bytes,
                  mimeType: action == 'json'
                      ? 'application/json'
                      : 'text/plain',
                ),
              ],
              fileNameOverrides: ['dayark-chat-${c.id}.$action'],
              sharePositionOrigin: _shareOrigin,
            ),
          );
      }
    } catch (_) {
      _notice('Unable to update or export this conversation.');
    }
  }

  Rect? get _shareOrigin {
    final render = context.findRenderObject();
    return render is RenderBox
        ? render.localToGlobal(Offset.zero) & render.size
        : null;
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pick({bool images = false}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: images
            ? ['png', 'jpg', 'jpeg', 'webp']
            : ['pdf', 'txt', 'md'],
      );
      if (result.isEmpty || !mounted) return;
      if (_attachments.length + result.length > 8) {
        throw const FormatException(
          'You can attach up to 8 files. Please remove some files.',
        );
      }
      final picked = <AiAttachment>[];
      for (final file in result) {
        if (await file.length() > aiMaxAttachmentBytes) {
          throw const FormatException(
            'This file exceeds the 8 MiB limit. Please use a smaller file.',
          );
        }
        final buffer = BytesBuilder(copy: false);
        await for (final chunk in file.readAsByteStream()) {
          if (buffer.length + chunk.length > aiMaxAttachmentBytes) {
            throw const FormatException(
              'This file exceeds the 8 MiB limit. Please use a smaller file.',
            );
          }
          buffer.add(chunk);
        }
        final bytes = buffer.takeBytes();
        final mime = file.extension?.toLowerCase() == 'md'
            ? 'text/markdown'
            : file.extension?.toLowerCase() == 'txt'
            ? 'text/plain'
            : lookupMimeType(file.name, headerBytes: bytes.take(32).toList());
        final id = const Uuid().v4();
        final a = AiAttachment(
          id: id,
          uri: Uri(scheme: 'attachment', path: id),
          mimeType: mime ?? 'application/octet-stream',
          kind: mime?.startsWith('image/') == true
              ? AiAttachmentKind.image
              : AiAttachmentKind.document,
          name: file.name,
          bytes: bytes,
        );
        validateAiAttachment(a);
        picked.add(a);
      }
      final total = [..._attachments, ...picked];
      if (total.fold<int>(0, (sum, a) => sum + a.bytes!.length) >
          aiMaxRequestAttachmentBytes) {
        throw const FormatException(
          'The selected files exceed 16 MiB together. Please use fewer or smaller files.',
        );
      }
      if (mounted) _update(() => _attachments.addAll(picked));
    } on AiException catch (error) {
      _notice(error.message);
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice(
        'Unable to read this file. Try a readable PNG, JPEG, WebP, PDF, UTF-8 TXT or Markdown file.',
      );
    }
  }
}
