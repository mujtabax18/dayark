import 'dart:convert';

import '../../../models/quotation.dart';

class QuotationPromptRequest {
  const QuotationPromptRequest({
    required this.categories,
    this.purpose = 'daily motivation',
    this.tone = 'uplifting',
    this.language = 'English',
    this.count = 3,
    this.extraInstructions = '',
  });

  final String categories;
  final String purpose;
  final String tone;
  final String language;
  final int count;
  final String extraInstructions;

  String get defaultCategory {
    final values = categories
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? 'General' : values.first;
  }
}

class QuotationPromptService {
  const QuotationPromptService();

  String buildPrompt(QuotationPromptRequest request) {
    final safeCount = request.count.clamp(1, 20).toInt();
    final categories = request.categories.trim().isEmpty
        ? 'General motivation'
        : request.categories.trim();
    final extra = request.extraInstructions.trim();

    return '''
Create $safeCount original motivational quotations.

Categories: $categories
Purpose: ${request.purpose.trim().isEmpty ? 'daily motivation' : request.purpose.trim()}
Tone: ${request.tone.trim().isEmpty ? 'uplifting' : request.tone.trim()}
Language: ${request.language.trim().isEmpty ? 'English' : request.language.trim()}
${extra.isEmpty ? '' : 'Additional instructions: $extra\n'}
Requirements:
- Make every quotation original and natural.
- Do not copy famous quotations.
- Do not attribute a quotation to a real person unless the quotation is verified.
- Keep each quotation suitable for a WhatsApp status image.
- Keep the wording concise, practical and motivational.
- Use the requested categories across the results.

Return only a valid JSON array in this format:
[
  {"text":"Quotation text","author":"","category":"Category name"}
]
'''.trim();
  }

  List<Quotation> parsePastedText(
    String raw,
    QuotationPromptRequest request,
  ) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '');

    if (cleaned.isEmpty) return const [];

    final jsonQuotes = _parseJson(cleaned, request);
    if (jsonQuotes.isNotEmpty) return jsonQuotes;

    final now = DateTime.now();
    final fallback = cleaned
        .split(RegExp(r'\n+'))
        .map(_cleanLine)
        .where((line) => line.length >= 5)
        .take(request.count.clamp(1, 20).toInt())
        .map(
          (text) => Quotation(
            text: text,
            category: request.defaultCategory,
            source: 'prompt',
            createdAt: now,
          ),
        )
        .toList(growable: false);

    return fallback;
  }

  List<Quotation> _parseJson(
    String cleaned,
    QuotationPromptRequest request,
  ) {
    try {
      final decoded = jsonDecode(cleaned);
      final list = decoded is List
          ? decoded
          : decoded is Map && decoded['quotations'] is List
              ? decoded['quotations'] as List
              : const [];
      if (list.isEmpty) return const [];

      final now = DateTime.now();
      return list
          .whereType<Map>()
          .map((item) {
            final text = item['text']?.toString().trim() ?? '';
            if (text.isEmpty) return null;
            final category = item['category']?.toString().trim() ?? '';
            return Quotation(
              text: text,
              author: item['author']?.toString().trim() ?? '',
              category:
                  category.isEmpty ? request.defaultCategory : category,
              source: 'prompt',
              createdAt: now,
            );
          })
          .whereType<Quotation>()
          .take(request.count.clamp(1, 20).toInt())
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String _cleanLine(String value) {
    return value
        .replaceFirst(RegExp(r'^\s*[-*•\d.()]+\s*'), '')
        .replaceAll(RegExp(r"""^["“”']+|["“”']+$"""), '')
        .trim();
  }
}
