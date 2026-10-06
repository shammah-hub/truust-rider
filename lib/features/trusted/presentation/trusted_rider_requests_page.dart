import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/wdgets/app_loader.dart';

// ═══════════════════════════════════════════════════════════════
//  TRUSTED RIDER REQUESTS — a buyer or seller wants to add this
//  rider to their trusted list. No money involved here — this is
//  consent to be contacted directly for future jobs, not a job
//  itself. Separate from TrustedAssignRequestPage, which is an
//  actual job request once this rider is already trusted.
// ═══════════════════════════════════════════════════════════════

class TrustedRiderRequestsPage extends StatelessWidget {
  const TrustedRiderRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg(isDark),
      appBar: AppBar(
        title: const Text('Trusted Rider Requests'),
        backgroundColor: AppTheme.surface(isDark),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trustedRiderRequests')
            .where('riderId', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: AppLoader());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text('No pending requests',
                  style: TextStyle(fontSize: 14, color: AppTheme.textTertiary(isDark))),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _RequestCard(
              requestId: docs[i].id,
              data: docs[i].data() as Map<String, dynamic>,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;
  final bool isDark;
  const _RequestCard({required this.requestId, required this.data, required this.isDark});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _loading = false;

  Future<void> _respond(bool accept) async {
    setState(() => _loading = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('respondToTrustedRiderRequest').call({
        'requestId': widget.requestId,
        'accept': accept,
      });
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed — try again.'),
          backgroundColor: AppTheme.redFor(widget.isDark),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final ownerName = widget.data['ownerName'] as String? ?? 'A Truust user';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$ownerName wants to add you as a trusted rider',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(isDark))),
          const SizedBox(height: 4),
          Text('You\'ll get sent directly to them for future deliveries — no cost if you decline.',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary(isDark))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _loading ? null : () => _respond(false),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.redFor(isDark).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text('Decline', style: TextStyle(color: AppTheme.redFor(isDark), fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _loading ? null : () => _respond(true),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.greenFor(isDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _loading
                        ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                        : const Center(child: Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
