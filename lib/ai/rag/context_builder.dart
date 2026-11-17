import 'dart:convert';

import '../models/ai_models.dart';
import '../memory/memory_store.dart';

class AiBuiltContext {
  const AiBuiltContext(this.history, this.excerpts, this.hits);
  final List<AiMessage> history;
  final String excerpts;
  final List<RetrievalHit> hits;
  bool get isPrivate => excerpts.isNotEmpty;
  String get references => hits.isEmpty
      ? ''
      : '\n\nSources provided for this answer:\n${[for (var i = 0; i < hits.length; i++) '[S${i + 1}](${hits[i].uri}) · ${hits[i].source.title.replaceAll(RegExp(r"[\r\n\[\]()*_!`<>]"), " ")} · chunk ${hits[i].chunk + 1}'].join('  \n')}';
}

/// Uses conservative UTF-8 byte budgets for multilingual text (at most one byte
/// per token), leaving space for protected prompts, current input and output.
class ContextBuilder {
  const ContextBuilder();
  AiBuiltContext build({
    required Iterable<AiMessage> history,
    required AiMessage message,
    required List<RetrievalHit> hits,
    int contextTokens = 4096,
    int outputTokens = 1024,
    int instructionBytes = 1024,
    bool summarize = false,
  }) {
    var remaining =
        contextTokens -
        outputTokens -
        instructionBytes -
        utf8.encode(message.text).length;
    if (remaining < 0) {
      throw StateError(
        'Message and instructions exceed the context budget. Reduce input or increase context size.',
      );
    }
    final selected = <RetrievalHit>[];
    final excerpts = <Map<String, Object>>[];
    final retrievalBudget = remaining ~/ 2;
    var used = 0;
    for (final hit in hits) {
      var item = <String, Object>{
        'citation': 'S${selected.length + 1}',
        'source': hit.uri,
        'title': hit.source.title,
        'text': hit.text,
      };
      var cost = utf8.encode(jsonEncode(item)).length + 16;
      if (used + cost > retrievalBudget) {
        final available =
            retrievalBudget -
            used -
            utf8.encode(jsonEncode({...item, 'text': ''})).length -
            24;
        if (available < 80) continue;
        final clipped = StringBuffer();
        var bytes = 0;
        for (final rune in hit.text.runes) {
          final value = String.fromCharCode(rune);
          final length = utf8.encode(jsonEncode(value)).length;
          if (bytes + length > available) break;
          clipped.write(value);
          bytes += length;
        }
        item = {...item, 'text': clipped.toString()};
        cost = utf8.encode(jsonEncode(item)).length + 16;
      }
      selected.add(hit);
      excerpts.add(item);
      used += cost;
    }
    var context = excerpts.isEmpty
        ? ''
        : jsonEncode({'untrustedRetrievedExcerpts': excerpts});
    if (context.isNotEmpty) remaining -= utf8.encode(context).length + 128;
    final summaryReserve = summarize ? (remaining ~/ 3).clamp(0, 800) : 0;
    remaining -= summaryReserve;
    final previous = history.toList();
    final recent = <AiMessage>[];
    var cut = previous.length;
    for (var i = previous.length - 1; i >= 0; i--) {
      final cost = utf8.encode(previous[i].text).length + 32;
      // Binary attachments are kept in recent turns and validated by the normal
      // attachment pipeline; reserve a generous context allowance for each.
      final attachmentCost = previous[i].attachments.length * 1024;
      if (cost + attachmentCost > remaining) break;
      recent.insert(0, previous[i]);
      cut = i;
      remaining -= cost + attachmentCost;
    }
    remaining += summaryReserve;
    if (summarize && cut > 0 && remaining > 160) {
      final summary = ConversationSummarizer().summarize(
        previous.take(cut),
        maxBytes: (remaining - 96).clamp(0, 1200),
      );
      if (summary.isNotEmpty) {
        context = jsonEncode({
          'untrustedRetrievedExcerpts': excerpts,
          'untrustedEarlierConversationSummary': summary,
        });
      }
    }
    // Enforce the final encoded size too: control characters and JSON quoting
    // can expand an extractive summary beyond its raw-text budget.
    final totalBudget =
        contextTokens -
        outputTokens -
        instructionBytes -
        utf8.encode(message.text).length;
    int cost() =>
        utf8.encode(context).length +
        recent.fold<int>(
          0,
          (n, m) =>
              n + utf8.encode(m.text).length + 32 + m.attachments.length * 1024,
        );
    if (cost() > totalBudget) {
      context = excerpts.isEmpty
          ? ''
          : jsonEncode({'untrustedRetrievedExcerpts': excerpts});
    }
    while (cost() > totalBudget && excerpts.isNotEmpty) {
      excerpts.removeLast();
      selected.removeLast();
      context = excerpts.isEmpty
          ? ''
          : jsonEncode({'untrustedRetrievedExcerpts': excerpts});
    }
    while (cost() > totalBudget && recent.isNotEmpty) {
      recent.removeAt(0);
    }
    return AiBuiltContext(recent, context, selected);
  }
}

/// Deterministic extractive summary: no network call, invented facts or promotion
/// of earlier dialogue to system authority. Original messages remain in chat DB.
class ConversationSummarizer {
  String summarize(Iterable<AiMessage> messages, {int maxBytes = 1200}) {
    if (maxBytes <= 0) return '';
    final all = messages.toList();
    final lines = <String>[];
    var remaining = maxBytes;
    // First topic plus latest older exchanges give a useful bounded digest.
    final selected = all.length <= 5
        ? all
        : [all.first, ...all.skip(all.length - 4)];
    for (final m in selected) {
      final line =
          '${m.role.name}: ${m.text.runes.take(100).map(String.fromCharCode).join()}';
      final cost = utf8.encode(line).length + 1;
      if (cost > remaining) continue;
      lines.add(line);
      remaining -= cost;
    }
    return lines.join('\n');
  }
}
