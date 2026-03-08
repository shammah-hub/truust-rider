import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/delivery_models.dart';

// ═══════════════════════════════════════════════════════════════
//  OTP ENTRY PAGE
//
//  Rider types the 4-digit code the buyer reads out loud.
//  Only reachable AFTER delivery photo is uploaded.
//  Wrong code → shows attempts remaining.
//  5 wrong attempts → order flagged for dispute.
// ═══════════════════════════════════════════════════════════════

class OtpEntryPage extends StatefulWidget {
  final DeliveryJob job;
  final String orderId;
  final String agentId;

  const OtpEntryPage({
    super.key,
    required this.job,
    required this.orderId,
    required this.agentId,
  });

  @override
  State<OtpEntryPage> createState() => _OtpEntryPageState();
}

class _OtpEntryPageState extends State<OtpEntryPage> {
  final List<TextEditingController> _ctrls =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(4, (_) => FocusNode());

  bool _loading = false;
  bool _success = false;
  String? _error;
  int _attemptsLeft = 5;

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  void _onDigit(int index, String val) {
    if (val.isNotEmpty && index < 3) {
      _nodes[index + 1].requestFocus();
    }
    if (_otp.length == 4) _submit();
  }

  Future<void> _submit() async {
    if (_otp.length < 4 || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    HapticFeedback.mediumImpact();

    try {
      await FirebaseFunctions.instance
          .httpsCallable('completeDeliveryWithOTP')
          .call({
        'jobId': widget.job.id,
        'orderId': widget.orderId,
        'agentId': widget.agentId,
        'otp': _otp,
      });

      // Success
      HapticFeedback.heavyImpact();
      setState(() => _success = true);

    } on FirebaseFunctionsException catch (e) {
      // Clear OTP fields
      for (final c in _ctrls) c.clear();
      _nodes[0].requestFocus();

      String message = e.message ?? 'Wrong code. Try again.';

      // Extract attempts remaining from message if present
      if (message.contains('attempt')) {
        final match = RegExp(r'\d+').firstMatch(message);
        if (match != null) {
          setState(() => _attemptsLeft = int.parse(match.group(0)!));
        }
      }

      if (e.code == 'resource-exhausted') {
        // Flagged for dispute
        setState(() {
          _error = 'Too many wrong attempts. Order flagged for review.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _error = message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: _success
            ? _SuccessView(
                job: widget.job,
                isDark: isDark,
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurface
                              : AppTheme.lightSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.blue.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Enter Delivery Code',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Ask the buyer for their 4-digit code to complete delivery and release payment.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.lightTextTertiary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Job summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.blue.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppTheme.blue.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.inventory_2_outlined,
                            color: AppTheme.blue, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${widget.job.itemDescription} · ${widget.job.pickupArea} → ${widget.job.destinationArea}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.blue,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 36),

                    // OTP boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (i) {
                        return SizedBox(
                          width: 70,
                          height: 80,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurface
                                  : AppTheme.lightSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _error != null
                                    ? AppTheme.error
                                    : _ctrls[i].text.isNotEmpty
                                        ? AppTheme.blue
                                        : (isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.black.withOpacity(0.08)),
                                width: _ctrls[i].text.isNotEmpty ||
                                        _error != null
                                    ? 2
                                    : 1,
                              ),
                            ),
                            child: TextField(
                              controller: _ctrls[i],
                              focusNode: _nodes[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) {
                                setState(() {});
                                _onDigit(i, v);
                                if (v.isEmpty && i > 0) {
                                  _nodes[i - 1].requestFocus();
                                }
                              },
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Error message
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.error.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppTheme.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ]),
                      ),

                    // Attempts warning
                    if (_attemptsLeft <= 3 && _attemptsLeft > 0 && _error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '⚠️ $_attemptsLeft attempt${_attemptsLeft != 1 ? 's' : ''} remaining before dispute',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkTextTertiary
                                : AppTheme.lightTextTertiary,
                          ),
                        ),
                      ),

                    const SizedBox(height: 28),

                    // Submit button
                    GestureDetector(
                      onTap: _otp.length == 4 && !_loading ? _submit : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _otp.length == 4
                              ? AppTheme.primaryGradient
                              : null,
                          color: _otp.length == 4
                              ? null
                              : (isDark
                                  ? AppTheme.darkSurface
                                  : AppTheme.lightSurface),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _otp.length == 4
                              ? [
                                  BoxShadow(
                                    color: AppTheme.blue.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Complete Delivery',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _otp.length == 4
                                        ? Colors.white
                                        : (isDark
                                            ? AppTheme.darkTextTertiary
                                            : AppTheme.lightTextTertiary),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Help text
                    Center(
                      child: Text(
                        'The buyer sees the code in their Truust app',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.lightTextTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SUCCESS VIEW — shown after OTP verified + money split
// ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final DeliveryJob job;
  final bool isDark;

  const _SuccessView({required this.job, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final earnings = job.agreedAmount != null
        ? (job.agreedAmount! * 0.9)
        : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.green.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.green.withOpacity(0.3), width: 2),
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 44)),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Delivery Complete!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Payment has been released to your wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary,
              ),
            ),

            const SizedBox(height: 28),

            // Earnings card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.earningsGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.green.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'You earned',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₦${earnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'after 10% commission',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Back to jobs
            GestureDetector(
              onTap: () {
                // Pop back to active page
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Back to Jobs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
