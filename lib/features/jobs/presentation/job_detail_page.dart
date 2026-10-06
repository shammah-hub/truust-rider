import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:truust_rider/core/wdgets/app_loader.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/delivery_models.dart';
import '../../../data/repositories/delivery_repository.dart';

class JobDetailPage extends StatefulWidget {
  final DeliveryJob job;
  final String agentId;

  const JobDetailPage({
    super.key,
    required this.job,
    required this.agentId,
  });

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  final _bidCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  DeliveryBid? _existingBid;
  DeliveryAgent? _agent;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _bidCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final repo = context.read<DeliveryRepository>();
    final results = await Future.wait([
      repo.getMyBidForJob(widget.job.id, widget.agentId),
      repo.getAgent(widget.agentId),
    ]);
    if (mounted) {
      setState(() {
        _existingBid = results[0] as DeliveryBid?;
        _agent = results[1] as DeliveryAgent?;
      });
    }
  }

  Future<void> _placeBid() async {
    final amount = double.tryParse(_bidCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }

    setState(() => _loading = true);
    try {
      // Pick the best vehicle type for this job
      final vehicleType = _agent?.vehicles.isNotEmpty == true
          ? _agent!.vehicles.first.type.name
          : 'bike';

      await context.read<DeliveryRepository>().placeBid(
        jobId: widget.job.id,
        agentId: widget.agentId,
        agentName: _agent?.name ?? 'Agent',
        agentRating: _agent?.rating ?? 5.0,
        vehicleType: vehicleType,
        amount: amount,
        buyerId: widget.job.buyerId,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      HapticFeedback.heavyImpact();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Bid placed successfully! 🎉'),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to place bid. Please try again.');
    }
  }

  Future<void> _withdrawBid() async {
    if (_existingBid == null) return;
    setState(() => _loading = true);
    try {
      await context
          .read<DeliveryRepository>()
          .withdrawBid(_existingBid!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Bid withdrawn'),
          backgroundColor: AppTheme.amber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to withdraw bid.');
    }
  }

  Future<void> _respondToCounter(bool accept) async {
    if (_existingBid == null) return;
    setState(() => _loading = true);
    try {
      await context.read<DeliveryRepository>().respondToCounter(
        bidId: _existingBid!.id,
        agentId: widget.agentId,
        accept: accept,
      );
      if (mounted) {
        if (accept) {
          Navigator.pop(context);
        } else {
          await _loadData();
          setState(() => _loading = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept
              ? 'Counter accepted! 🎉'
              : 'Counter declined — your original bid is back open'),
          backgroundColor: accept ? AppTheme.green : AppTheme.amber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError(accept
          ? 'Failed to accept counter. Please try again.'
          : 'Failed to decline counter. Please try again.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final job = widget.job;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route card
            _SectionCard(
              isDark: isDark,
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.radio_button_checked_rounded,
                    iconColor: AppTheme.blue,
                    label: 'Pickup',
                    value: job.pickupAddress,
                    isDark: isDark,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Container(
                      width: 1,
                      height: 20,
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.08),
                    ),
                  ),
                  _DetailRow(
                    icon: Icons.location_on_rounded,
                    iconColor: AppTheme.green,
                    label: 'Destination',
                    value: job.destination,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Item details
            _SectionCard(
              isDark: isDark,
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppTheme.blue,
                    label: 'Item',
                    value: job.itemDescription,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.scale_outlined,
                    iconColor: AppTheme.pickupColor,
                    label: 'Weight',
                    value:
                        '${job.weightKg}kg — ${job.weightCategory.label}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.people_outline_rounded,
                    iconColor: AppTheme.indigo,
                    label: 'Bids so far',
                    value: '${job.bidCount} agent${job.bidCount != 1 ? 's' : ''} have bid',
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_existingBid != null) ...[
              // Already bid — branch on whether the buyer has
              // countered, or the bid is still sitting as posted.
              if (_existingBid!.status == 'countered') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.reply_rounded,
                            color: AppTheme.blue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Buyer sent a counter offer',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.blue,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₦${(_existingBid!.counterAmount ?? _existingBid!.amount).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'was ₦${_existingBid!.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: isDark
                                    ? AppTheme.darkTextTertiary
                                    : AppTheme.lightTextTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Accept to lock in this job, or decline to keep your original bid open.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.lightTextTertiary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _loading
                                  ? null
                                  : () => _respondToCounter(false),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                      AppTheme.error.withOpacity(0.3)),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Decline',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: _loading
                                  ? null
                                  : () => _respondToCounter(true),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: _loading
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                      : const Text(
                                    'Accept',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.amber.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.how_to_reg_rounded,
                            color: AppTheme.amber, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Your bid is active',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.amber,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '₦${_existingBid!.currentAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Waiting for buyer to respond...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.lightTextTertiary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _loading ? null : _withdrawBid,
                        child: Container(
                          width: double.infinity,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(92),
                            border: Border.all(
                                color: AppTheme.error.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: AppLoader(),
                            )
                                : const Text(
                              'Withdraw Bid',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Place bid form
              Text(
                'Place Your Bid',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Set your delivery price. Buyer can accept or counter.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.darkTextTertiary
                      : AppTheme.lightTextTertiary,
                ),
              ),
              const SizedBox(height: 16),

              // Amount
              _InputField(
                controller: _bidCtrl,
                label: 'Your Price (₦)',
                hint: '2000',
                isDark: isDark,
                keyboard: const TextInputType.numberWithOptions(
                    decimal: false),
                prefix: const Text('₦',
                    style: TextStyle(
                        color: AppTheme.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),

              const SizedBox(height: 12),

              _InputField(
                controller: _noteCtrl,
                label: 'Message to buyer (optional)',
                hint: 'I can pick up within 30 minutes...',
                isDark: isDark,
                maxLines: 3,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _placeBid,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                  ),
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(100)),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      width: double.infinity,
                      height: 54,
                      child: _loading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gavel_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Place Bid',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppTheme.darkTextTertiary
                      : AppTheme.lightTextTertiary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isDark;
  final TextInputType? keyboard;
  final Widget? prefix;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.isDark,
    this.keyboard,
    this.prefix,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color:
                isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboard,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
              prefixIcon: prefix != null
                  ? Padding(
                      padding: const EdgeInsets.only(
                          left: 14, right: 8, top: 2),
                      child: prefix,
                    )
                  : null,
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
