import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/wdgets/app_loader.dart';

// ═══════════════════════════════════════════════════════════════
//  TRUSTED ASSIGN REQUEST — an actual job, sent directly by someone
//  who already trusts this rider. Same money shape as a normal
//  accepted bid once accepted: real fee, real escrow, real 10% cut.
//  10-minute window — after that the payer is notified to pick
//  someone else, handled server-side by expireTrustedAssignments.
// ═══════════════════════════════════════════════════════════════

class TrustedAssignRequestPage extends StatefulWidget {
  final String bidId;
  const TrustedAssignRequestPage({super.key, required this.bidId});

  @override
  State<TrustedAssignRequestPage> createState() => _TrustedAssignRequestPageState();
}

class _TrustedAssignRequestPageState extends State<TrustedAssignRequestPage> {
  bool _loading = false;

  Future<void> _respond(bool accept) async {
    setState(() => _loading = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('respondToTrustedAssignment').call({
        'bidId': widget.bidId,
        'accept': accept,
      });
      HapticFeedback.heavyImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed — this request may have expired.'),
          backgroundColor: AppTheme.redFor(Theme.of(context).brightness == Brightness.dark),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.bg(isDark),
      appBar: AppBar(title: const Text('Direct Delivery Request'), backgroundColor: AppTheme.surface(isDark)),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('deliveryBids').doc(widget.bidId).get(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: AppLoader());
          if (!snap.data!.exists) {
            return Center(child: Text('This request no longer exists', style: TextStyle(color: AppTheme.textTertiary(isDark))));
          }
          final bid = snap.data!.data() as Map<String, dynamic>;
          final status = bid['status'] as String? ?? '';
          final amount = (bid['amount'] as num?)?.toDouble() ?? 0;

          if (status != 'trusted_pending') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  status == 'accepted' ? 'You already accepted this.' : 'This request is no longer available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(isDark)),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(isDark),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border(isDark)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Someone who trusts you directly wants you for a delivery.',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(isDark))),
                      const SizedBox(height: 14),
                      Text('₦${amount.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.greenFor(isDark))),
                      const SizedBox(height: 4),
                      Text('Same as a normal accepted job — escrow-protected, paid to your wallet.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textTertiary(isDark))),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _loading ? null : () => _respond(false),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(color: AppTheme.redFor(isDark).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                          child: Center(child: Text('Decline', style: TextStyle(color: AppTheme.redFor(isDark), fontWeight: FontWeight.w700, fontSize: 15))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _loading ? null : () => _respond(true),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(color: AppTheme.greenFor(isDark), borderRadius: BorderRadius.circular(14)),
                          child: _loading
                              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                              : const Center(child: Text('Accept Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
