import 'package:drift/drift.dart' show driftRuntimeOptions;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/chat/ai_conversation.dart';

AiConversation conversation(
  String id, {
  bool share = false,
  String text = 'اردو budget groceries',
}) => AiConversation(
  id: id,
  title: 'Planning',
  updatedAt: DateTime.now().toUtc(),
  shareWithDevices: share,
  profileId: 'private-local-profile',
  messages: [
    AiChatMessage(
      id: 'message-1',
      createdAt: DateTime.now().toUtc(),
      message: AiMessage(role: AiRole.user, text: text),
    ),
  ],
);
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AiChatStore a, b;
  setUp(() {
    a = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
    b = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });
  test(
    'database persists messages and metadata across a file reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('dayark-chat-db');
      final file = File('${dir.path}/chats.sqlite');
      var persistent = AiChatStore(AiChatDatabase(NativeDatabase(file)));
      final saved = await persistent.save(conversation('persisted'));
      await persistent.close();
      persistent = AiChatStore(AiChatDatabase(NativeDatabase(file)));
      expect(
        (await persistent.get('persisted'))!.messages.single.message.text,
        contains('اردو'),
      );
      expect((await persistent.get('persisted'))!.revision, saved.revision);
      await persistent.close();
      await dir.delete(recursive: true);
    },
  );
  test(
    'search, folders, pins, archive, export and deletion retain expected data',
    () async {
      var c = await a.save(conversation('one'));
      await a.save(conversation('two', text: 'Other topic'));
      expect((await a.list(query: 'groceries')).single.id, 'one');
      expect((await a.list(query: "' OR 1=1 --")).isEmpty, isTrue);
      c = await a.save(
        c.copyWith(title: 'My plan', folder: 'Home', pinned: true),
        expectedRevision: c.revision,
      );
      expect((await a.list(folder: 'Home')).single.title, 'My plan');
      expect((await a.list()).first.id, 'one');
      expect(
        jsonDecode(a.export(c, 'json'))['messages'][0]['text'],
        contains('اردو'),
      );
      expect(a.export(c, 'md'), contains('# My plan'));
      expect(a.export(c, 'txt'), contains('user (complete)'));
      c = await a.save(
        c.copyWith(archived: true),
        expectedRevision: c.revision,
      );
      expect(await a.list(query: 'groceries'), isEmpty);
      expect((await a.list(archived: true)).single.id, 'one');
      await a.delete(c);
      expect((await a.get('one'))!.messages, isEmpty);
      expect(await a.list(archived: true), isEmpty);
    },
  );
  test(
    'optimistic revisions reject stale edits rather than overwrite messages',
    () async {
      final c = await a.save(conversation('one'));
      await a.save(c.copyWith(title: 'Updated'), expectedRevision: c.revision);
      await expectLater(
        a.save(c.copyWith(title: 'Stale'), expectedRevision: c.revision),
        throwsA(isA<AiChatConflict>()),
      );
      expect((await a.get('one'))!.title, 'Updated');
    },
  );
  test(
    'global sync includes all chats and excludes device-local details',
    () async {
      await a.save(conversation('private'));
      await a.save(conversation('shared', share: true));
      await expectLater(a.syncSnapshot(), throwsStateError);
      await a.setSyncEnabled(true);
      final snapshot = await a.syncSnapshot();
      expect(
        (snapshot['conversations'] as List).map((c) => c['id']),
        containsAll(['private', 'shared']),
      );
      expect(jsonEncode(snapshot), isNot(contains('private-local-profile')));
      await expectLater(b.mergeSync(snapshot), throwsStateError);
      await b.setSyncEnabled(true);
      await b.mergeSync(snapshot);
      expect(
        (await b.list()).map((c) => c.id),
        containsAll(['private', 'shared']),
      );
      expect((await b.get('shared'))!.profileId, isNull);
    },
  );

  test(
    'provider diagnostics remain local and are excluded from sync',
    () async {
      await a.setSyncEnabled(true);
      await a.save(
        AiConversation(
          id: 'diagnostic',
          title: 'Diagnostic',
          updatedAt: DateTime.now(),
          messages: [
            AiChatMessage(
              id: 'failed',
              createdAt: DateTime.now(),
              state: AiChatMessageState.failed,
              error: 'Failed',
              diagnostics: 'private model thinking',
              message: AiMessage(role: AiRole.assistant, text: 'No response'),
            ),
          ],
        ),
      );
      expect(
        (await a.get('diagnostic'))!.messages.single.diagnostics,
        isNotNull,
      );
      expect(
        jsonEncode(await a.syncSnapshot()),
        isNot(contains('private model thinking')),
      );
    },
  );
  test('concurrent offline edits converge and preserve a conflict copy; tombstones prevent resurrection', () async {
    await a.setSyncEnabled(true);
    await b.setSyncEnabled(true);
    var original = await a.save(conversation('shared', share: true));
    await b.mergeSync(await a.syncSnapshot());
    final remote = (await b.get('shared'))!;
    original = await a.save(
      original.copyWith(title: 'Edited on A'),
      expectedRevision: original.revision,
    );
    await b.save(
      remote.copyWith(title: 'Edited on B'),
      expectedRevision: remote.revision,
    );
    await a.mergeSync(await b.syncSnapshot());
    await b.mergeSync(await a.syncSnapshot());
    expect(
      (await a.list()).map((c) => c.title).toSet(),
      (await b.list()).map((c) => c.title).toSet(),
    );
    expect(await a.list(), hasLength(2));
    expect(
      (await a.list()).any((c) => c.title.contains('conflict copy')),
      isTrue,
    );
    final stale = await a.syncSnapshot();
    await a.delete((await a.get('shared'))!);
    await b.mergeSync(await a.syncSnapshot());
    await b.mergeSync(stale);
    expect((await b.get('shared'))!.deleted, isTrue);
    expect((await b.get('shared'))!.messages, isEmpty);
  });
  test('malformed sync batch rolls back all imported conversations', () async {
    await a.setSyncEnabled(true);
    await b.setSyncEnabled(true);
    await a.save(conversation('shared', share: true));
    final snapshot = await a.syncSnapshot();
    (snapshot['conversations'] as List).add({'version': 2});
    await expectLater(b.mergeSync(snapshot), throwsA(anything));
    expect(await b.list(), isEmpty);
  });
}
