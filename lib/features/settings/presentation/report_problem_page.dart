import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/wdgets/app_loader.dart';

class ReportProblemPage extends StatefulWidget {
  final String userId;
  const ReportProblemPage({super.key, required this.userId});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  static const _categories = [
    'App bug or crash',
    'Payment or wallet issue',
    'Delivery job problem',
    'Account or verification',
    'Something else',
  ];

  String? _category;
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _category != null && _descCtrl.text.trim().length >= 10;

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      final ticketRef = FirebaseFirestore.instance.collection('supportChats').doc();
      await ticketRef.set({
        'userId': widget.userId,
        'category': _category,
        'subject': _category,
        'status': 'open',
        'lastMessage': _descCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await ticketRef.collection('messages').add({
        'senderId': widget.userId,
        'text': _descCtrl.text.trim(),
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Report submitted — our team will follow up.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

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
                  'Report a Problem',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: AppTheme.ink(isDark),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'Tell us what went wrong — our team reads every report.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((c) {
                  final selected = c == _category;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _category = c);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.ink(isDark)
                            : (isDark ? AppTheme.darkSurface : AppTheme.lightSurface),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppTheme.ink(isDark)
                              : (isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.08)),
                        ),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppTheme.inkInverse(isDark)
                              : AppTheme.ink(isDark),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),
              Text(
                'What happened?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: TextField(
                  controller: _descCtrl,
                  minLines: 5,
                  maxLines: 8,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 14, color: AppTheme.ink(isDark)),
                  decoration: InputDecoration(
                    hintText: 'Describe the issue in as much detail as you can...',
                    hintStyle: TextStyle(
                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              GestureDetector(
                onTap: _canSubmit ? _submit : null,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _canSubmit
                        ? AppTheme.ink(isDark)
                        : (isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: AppLoader(size: 44),
                    )
                        : Text(
                      'Submit Report',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _canSubmit
                            ? AppTheme.inkInverse(isDark)
                            : (isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.lightTextTertiary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
