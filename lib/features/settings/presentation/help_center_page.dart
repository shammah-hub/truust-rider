import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import 'report_problem_page.dart';

class HelpCenterPage extends StatefulWidget {
  final String userId;
  const HelpCenterPage({super.key, required this.userId});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  static const _faqs = [
    _Faq(
      'How does verification work?',
      'Our team manually reviews your ID document and selfie after you '
          'submit them. This usually takes up to 24 hours. You\'ll get a '
          'notification once you\'re approved and can go online.',
    ),
    _Faq(
      'How do I get matched with jobs?',
      'Jobs are matched to your registered city and the weight categories '
          'your vehicles can handle. Go online to start seeing available jobs.',
    ),
    _Faq(
      'Why can\'t I see any jobs?',
      'Make sure you\'re verified, online, and that your city matches '
          'where the job was posted. Some jobs also wait on the seller to '
          'confirm the exact pickup address before they\'re visible to riders.',
    ),
    _Faq(
      'How do bids and counters work?',
      'You place a bid with your price for a job. The buyer can accept it '
          'outright or send a counter-offer with a lower price — you can '
          'then accept or decline the counter.',
    ),
    _Faq(
      'When do I get paid?',
      'Funds are locked in escrow once a buyer accepts your bid, and '
          'released to your rider wallet after the delivery is confirmed, '
          'minus platform commission.',
    ),
    _Faq(
      'What are guarantors used for?',
      'Guarantors are kept on file only — we contact them only if '
          'something serious comes up, like a dispute or a missing delivery.',
    ),
  ];

  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
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
                Text(
                  'Help Center',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: AppTheme.ink(isDark),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  children: List.generate(_faqs.length, (i) {
                    final expanded = _expandedIndex == i;
                    return Column(
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _expandedIndex = expanded ? null : i);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _faqs[i].question,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.ink(isDark),
                                        ),
                                      ),
                                      if (expanded) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _faqs[i].answer,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.5,
                                            color: isDark
                                                ? AppTheme.darkTextSecondary
                                                : AppTheme.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  expanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: isDark
                                      ? AppTheme.darkTextTertiary
                                      : AppTheme.lightTextTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (i != _faqs.length - 1)
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: isDark
                                ? Colors.white.withOpacity(0.07)
                                : Colors.black.withOpacity(0.07),
                          ),
                      ],
                    );
                  }),
                ),
              ),

              const SizedBox(height: 22),
              Text(
                'Still need help?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportProblemPage(userId: widget.userId),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.07)
                          : Colors.black.withOpacity(0.06),
                    ),
                  ),
                  child: Row(children: [
                    Icon(Iconsax.message_question, color: AppTheme.ink(isDark), size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Report a Problem',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink(isDark),
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}
