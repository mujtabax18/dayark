import 'package:flutter/material.dart';

import '../../../models/quotation.dart';

class QuotationPosterTheme {
  const QuotationPosterTheme({
    required this.key,
    required this.label,
    required this.colors,
    this.foreground = Colors.white,
    this.accent = Colors.white70,
  });

  final String key;
  final String label;
  final List<Color> colors;
  final Color foreground;
  final Color accent;

  static const all = <QuotationPosterTheme>[
    QuotationPosterTheme(
      key: 'sunrise',
      label: 'Sunrise',
      colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
    ),
    QuotationPosterTheme(
      key: 'ocean',
      label: 'Ocean',
      colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
    ),
    QuotationPosterTheme(
      key: 'forest',
      label: 'Forest',
      colors: [Color(0xFF134E5E), Color(0xFF71B280)],
    ),
    QuotationPosterTheme(
      key: 'midnight',
      label: 'Midnight',
      colors: [Color(0xFF141E30), Color(0xFF243B55)],
    ),
    QuotationPosterTheme(
      key: 'royal',
      label: 'Royal',
      colors: [Color(0xFF42275A), Color(0xFF734B6D)],
    ),
    QuotationPosterTheme(
      key: 'paper',
      label: 'Paper',
      colors: [Color(0xFFF7F3E9), Color(0xFFE8DFC8)],
      foreground: Color(0xFF28231D),
      accent: Color(0xFF6E6253),
    ),
  ];

  static QuotationPosterTheme byKey(String key) {
    return all.firstWhere(
      (theme) => theme.key == key,
      orElse: () => all.first,
    );
  }
}

class QuotationPoster extends StatelessWidget {
  const QuotationPoster({
    super.key,
    required this.quotation,
    required this.theme,
    required this.fontSize,
    required this.alignment,
    required this.showAuthor,
    this.brandText = 'Daily Motivation',
  });

  final Quotation quotation;
  final QuotationPosterTheme theme;
  final double fontSize;
  final TextAlign alignment;
  final bool showAuthor;
  final String brandText;

  @override
  Widget build(BuildContext context) {
    final horizontalAlignment = switch (alignment) {
      TextAlign.left => CrossAxisAlignment.start,
      TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.colors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.foreground.withOpacity(.08),
                ),
              ),
            ),
            Positioned(
              left: -110,
              bottom: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.foreground.withOpacity(.10),
                    width: 38,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 44, 34, 34),
              child: Column(
                crossAxisAlignment: horizontalAlignment,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          quotation.category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '“',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 72,
                      height: .6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    quotation.text,
                    textAlign: alignment,
                    style: TextStyle(
                      color: theme.foreground,
                      fontSize: fontSize,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4,
                    ),
                  ),
                  if (showAuthor && quotation.author.trim().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      '— ${quotation.author.trim()}',
                      textAlign: alignment,
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    brandText,
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
