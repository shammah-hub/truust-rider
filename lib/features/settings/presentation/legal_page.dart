import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LegalPage extends StatelessWidget {
  final String title;
  final List<LegalSection> sections;
  final DateTime lastUpdated;

  const LegalPage({
    super.key,
    required this.title,
    required this.sections,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.07),
                      ),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 15, color: AppTheme.ink(isDark)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: AppTheme.ink(isDark),
                    ),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last updated: ${lastUpdated.day}/${lastUpdated.month}/${lastUpdated.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final s in sections) ...[
                      Text(
                        s.heading,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink(isDark),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.body,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.6,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}
