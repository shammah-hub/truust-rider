// ═══════════════════════════════════════════════════════════════
//  EARNINGS PAGE  +  RIDER WITHDRAW SHEET
//
//  Drop-in replacement for the existing EarningsPage.
//  The Withdraw button now opens RiderWithdrawSheet which:
//    1. Reads rider's wallet balance from Firestore
//    2. Loads bank list via getBanksList Cloud Function
//    3. Verifies account name via verifyAccountName
//    4. Calls initiateTransfer to withdraw
//
//  Place this file at:
//    lib/features/earnings/earnings_page.dart
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:truust_rider/core/theme/app_theme.dart';
import 'package:truust_rider/data/repositories/delivery_repository.dart';

import 'earnings/presentation/security/rider_wallet_security_gate.dart';

// ═══════════════════════════════════════════════════════════════
//  EARNINGS PAGE
// ═══════════════════════════════════════════════════════════════

class EarningsPage extends StatefulWidget {
  final String userId;
  const EarningsPage({super.key, required this.userId});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await context
          .read<DeliveryRepository>()
          .getEarningsSummary(widget.userId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  Future<void> _openWithdraw() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await WalletSecurityGate.authenticate(
      context:   context,
      onSuccess: () {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => RiderWithdrawSheet(
            userId:    widget.userId,
            isDark:    isDark,
            onSuccess: _load,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total =
        (_summary?['totalEarnings'] as num?)?.toDouble() ?? 0;
    final thisMonth =
        (_summary?['thisMonth'] as num?)?.toDouble() ?? 0;
    final deliveries =
        (_summary?['totalDeliveries'] as num?)?.toInt() ?? 0;
    final rating =
        (_summary?['rating'] as num?)?.toDouble() ?? 5.0;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Earnings',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openWithdraw,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.blue.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Text(
                        'Withdraw',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (_loading)
                const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.blue))
              else ...[
                // ── Wallet balance card ──────────────────────
                _WalletBalanceCard(
                  userId: widget.userId,
                  isDark: isDark,
                  onWithdraw: _openWithdraw,
                ),

                const SizedBox(height: 12),

                // ── Total earned card ────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.earningsGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.green.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Earned',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₦${_fmt(total)}',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '10% fee\ndeducted',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Three stat tiles ─────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        isDark: isDark,
                        label: 'This Month',
                        value: '₦${_fmt(thisMonth)}',
                        icon: Icons.calendar_month_rounded,
                        iconColor: AppTheme.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        isDark: isDark,
                        label: 'Deliveries',
                        value: '$deliveries',
                        icon: Icons.local_shipping_rounded,
                        iconColor: AppTheme.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        isDark: isDark,
                        label: 'Rating',
                        value: rating.toStringAsFixed(1),
                        icon: Icons.star_rounded,
                        iconColor: AppTheme.amber,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Commission note ──────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurface
                        : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.06),
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.blue, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Truust takes 10% commission per delivery. Earnings shown are after commission.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  WALLET BALANCE CARD
//  Real-time stream of wallets/{userId}
// ═══════════════════════════════════════════════════════════════

class _WalletBalanceCard extends StatelessWidget {
  final String userId;
  final bool isDark;
  final VoidCallback onWithdraw;

  const _WalletBalanceCard({
    required this.userId,
    required this.isDark,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('riderWallets')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final available =
            (data?['availableBalance'] as num?)?.toDouble() ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
            isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.lightTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₦${_fmt(available)}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onWithdraw,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.green.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '💸 Cash Out',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.green,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }
}

// ═══════════════════════════════════════════════════════════════
//  RIDER WITHDRAW SHEET
//
//  Step 1 — Enter amount + bank + account number
//  Step 2 — Confirm verified account name
//  Step 3 — Success / error
// ═══════════════════════════════════════════════════════════════

class RiderWithdrawSheet extends StatefulWidget {
  final String userId;
  final bool isDark;
  final VoidCallback? onSuccess;

  const RiderWithdrawSheet({
    super.key,
    required this.userId,
    required this.isDark,
    this.onSuccess,
  });

  @override
  State<RiderWithdrawSheet> createState() => _RiderWithdrawSheetState();
}

class _RiderWithdrawSheetState extends State<RiderWithdrawSheet> {
  // ── State ────────────────────────────────────────────────
  int _step = 1; // 1 = form, 2 = confirm, 3 = success

  final _amountCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();

  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;
  bool _loadingBanks = true;

  bool _verifying = false;
  String? _verifiedName;
  String? _verifyError;

  bool _submitting = false;
  double _availableBalance = 0;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _fetchBanks();
    _accountCtrl.addListener(_onAccountChanged);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  // ── Fetch wallet balance ─────────────────────────────────
  Future<void> _fetchBalance() async {
    final snap = await FirebaseFirestore.instance
        .collection('riderWallets')
        .doc(widget.userId)
        .get();
    if (mounted) {
      setState(() {
        _availableBalance =
            (snap.data()?['availableBalance'] as num?)?.toDouble() ?? 0;
      });
    }
  }

  // ── Fetch bank list ──────────────────────────────────────
  Future<void> _fetchBanks() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getBanksList')
          .call();
      final list =
      List<Map<String, dynamic>>.from(result.data['banks'] ?? []);
      if (mounted) {
        setState(() {
          _banks = list;
          _loadingBanks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  // ── Auto-verify when account number reaches 10 digits ───
  void _onAccountChanged() {
    if (_accountCtrl.text.length == 10 && _selectedBank != null) {
      _verifyAccount();
    } else {
      setState(() {
        _verifiedName = null;
        _verifyError = null;
      });
    }
  }

  Future<void> _verifyAccount() async {
    if (_selectedBank == null || _accountCtrl.text.length != 10) return;
    setState(() {
      _verifying = true;
      _verifiedName = null;
      _verifyError = null;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyAccountName')
          .call({
        'accountNumber': _accountCtrl.text.trim(),
        'bankCode': _selectedBank!['code'],
      });
      if (mounted) {
        setState(() {
          _verifying = false;
          _verifiedName =
              result.data['accountName'] ?? 'Unknown';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _verifyError = 'Could not verify account';
        });
      }
    }
  }

  // ── Proceed to confirmation step ─────────────────────────
  void _goToConfirm() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || amount > _availableBalance) return;
    if (_verifiedName == null) return;
    setState(() => _step = 2);
  }

  // ── Submit withdrawal ────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _submitting = true);
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('initiateRiderTransfer')
          .call({
        'userId': widget.userId,
        'amount': amount,
        'bankCode': _selectedBank!['code'],
        'bankName': _selectedBank!['name'],
        'accountNumber': _accountCtrl.text.trim(),
        'accountName': _verifiedName,
      });

      if (mounted) {
        setState(() {
          _submitting = false;
          _step = 3;
        });
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Withdrawal failed: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────
  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  bool get _formValid {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    return amount >= 100 &&
        amount <= _availableBalance &&
        _selectedBank != null &&
        _accountCtrl.text.length == 10 &&
        _verifiedName != null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _step == 1
              ? _FormStep()
              : _step == 2
              ? _ConfirmStep()
              : _SuccessStep(),
        ),
      ),
    );
  }

  // ── STEP 1: Form ─────────────────────────────────────────
  Widget _FormStep() {
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _drag(),
        const SizedBox(height: 22),

        // Title
        Text(
          '💸 Withdraw Earnings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: widget.isDark
                ? AppTheme.darkTextPrimary
                : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Available: ₦${_fmt(_availableBalance)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.green,
          ),
        ),

        const SizedBox(height: 22),

        // Amount
        _label('Amount (₦)'),
        const SizedBox(height: 8),
        _input(
          controller: _amountCtrl,
          hint: 'Min ₦100',
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'^\d+\.?\d{0,2}')),
          ],
          onChanged: (_) => setState(() {}),
          suffix: GestureDetector(
            onTap: () {
              _amountCtrl.text =
                  _availableBalance.toStringAsFixed(0);
              setState(() {});
            },
            child: const Text(
              'MAX',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.blue,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Bank picker
        _label('Bank'),
        const SizedBox(height: 8),
        _loadingBanks
            ? Container(
          height: 52,
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppTheme.darkSurface2
                : AppTheme.lightSurface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.blue),
            ),
          ),
        )
            : GestureDetector(
          onTap: () => _showBankPicker(),
          child: Container(
            height: 52,
            padding:
            const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppTheme.darkSurface2
                  : AppTheme.lightSurface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedBank?['name'] ?? 'Select bank…',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedBank != null
                          ? (widget.isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary)
                          : (widget.isDark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.lightTextTertiary),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: widget.isDark
                      ? AppTheme.darkTextTertiary
                      : AppTheme.lightTextTertiary,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Account number
        _label('Account Number'),
        const SizedBox(height: 8),
        _input(
          controller: _accountCtrl,
          hint: '10-digit account number',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (_) => setState(() {}),
        ),

        // Account name verification feedback
        if (_verifying)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.blue)),
              const SizedBox(width: 8),
              Text(
                'Verifying account…',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark
                      ? AppTheme.darkTextTertiary
                      : AppTheme.lightTextTertiary,
                ),
              ),
            ]),
          )
        else if (_verifiedName != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.green, size: 14),
              const SizedBox(width: 6),
              Text(
                _verifiedName!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.green,
                ),
              ),
            ]),
          )
        else if (_verifyError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.error, size: 14),
                const SizedBox(width: 6),
                Text(
                  _verifyError!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.error),
                ),
              ]),
            ),

        const SizedBox(height: 24),

        // Continue button
        _BigBtn(
          label: 'Continue',
          enabled: _formValid,
          isDark: widget.isDark,
          onTap: _goToConfirm,
        ),
      ],
    );
  }

  // ── STEP 2: Confirm ──────────────────────────────────────
  Widget _ConfirmStep() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    return Column(
      key: const ValueKey('confirm'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _drag(),
        const SizedBox(height: 22),

        Text(
          'Confirm Withdrawal',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: widget.isDark
                ? AppTheme.darkTextPrimary
                : AppTheme.lightTextPrimary,
          ),
        ),

        const SizedBox(height: 24),

        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppTheme.darkSurface2
                : AppTheme.lightSurface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Column(
            children: [
              _ConfirmRow(
                label: 'Amount',
                value: '₦${_fmt(amount)}',
                valueColor: AppTheme.green,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 12),
              _ConfirmRow(
                label: 'Bank',
                value: _selectedBank?['name'] ?? '',
                isDark: widget.isDark,
              ),
              const SizedBox(height: 12),
              _ConfirmRow(
                label: 'Account',
                value: _accountCtrl.text,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 12),
              _ConfirmRow(
                label: 'Account Name',
                value: _verifiedName ?? '',
                valueColor: AppTheme.green,
                isDark: widget.isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border:
            Border.all(color: AppTheme.amber.withOpacity(0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppTheme.amber, size: 13),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Transfers usually arrive within minutes but may take up to 24 hours.',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            // Back
            GestureDetector(
              onTap: () => setState(() => _step = 1),
              child: Container(
                height: 52,
                padding:
                const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppTheme.darkSurface2
                      : AppTheme.lightSurface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigBtn(
                label: _submitting ? '' : 'Withdraw Now',
                enabled: !_submitting,
                isDark: widget.isDark,
                loading: _submitting,
                onTap: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── STEP 3: Success ──────────────────────────────────────
  Widget _SuccessStep() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _drag(),
        const SizedBox(height: 28),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.green.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: AppTheme.green, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          '₦${_fmt(amount)} on the way!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: widget.isDark
                ? AppTheme.darkTextPrimary
                : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Transfer to ${_selectedBank?['name']} · ${_accountCtrl.text}',
          style: TextStyle(
            fontSize: 13,
            color: widget.isDark
                ? AppTheme.darkTextTertiary
                : AppTheme.lightTextTertiary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        _BigBtn(
          label: 'Done',
          enabled: true,
          isDark: widget.isDark,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  // ── Bank picker modal ─────────────────────────────────────
  void _showBankPicker() {
    final search = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          final filtered = _banks
              .where((b) => (b['name'] as String)
              .toLowerCase()
              .contains(search.text.toLowerCase()))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppTheme.darkSurface
                  : AppTheme.lightSurface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                _drag(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: _input(
                    controller: search,
                    hint: 'Search bank…',
                    onChanged: (_) => setModal(() {}),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final bank = filtered[i];
                      final selected =
                          _selectedBank?['code'] == bank['code'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedBank = bank;
                            _verifiedName = null;
                            _verifyError = null;
                          });
                          Navigator.pop(ctx);
                          if (_accountCtrl.text.length == 10) {
                            _verifyAccount();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.blue.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius:
                            BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.blue.withOpacity(0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bank['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? AppTheme.blue
                                        : (widget.isDark
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme
                                        .lightTextPrimary),
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.blue,
                                    size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────

  Widget _drag() => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.15)
            : Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: widget.isDark
          ? AppTheme.darkTextSecondary
          : AppTheme.lightTextSecondary,
    ),
  );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppTheme.darkSurface2
            : AppTheme.lightSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 14,
                color: widget.isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: widget.isDark
                      ? AppTheme.darkTextTertiary
                      : AppTheme.lightTextTertiary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
            ),
          ),
          if (suffix != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: suffix,
            ),
        ],
      ),
    );
  }
}

// ── Confirm row ───────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;

  const _ConfirmRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppTheme.darkTextTertiary
                : AppTheme.lightTextTertiary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ??
                (isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary),
          ),
        ),
      ],
    );
  }
}

// ── Big CTA button ────────────────────────────────────────────
class _BigBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final bool isDark;
  final VoidCallback onTap;

  const _BigBtn({
    required this.label,
    required this.enabled,
    required this.isDark,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !loading
          ? () {
        HapticFeedback.mediumImpact();
        onTap();
      }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: enabled ? AppTheme.primaryGradient : null,
          color: enabled
              ? null
              : (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
            BoxShadow(
              color: AppTheme.blue.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 5),
            )
          ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          )
              : Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: enabled
                  ? Colors.white
                  : (isDark
                  ? AppTheme.darkTextTertiary
                  : AppTheme.lightTextTertiary),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STAT TILE (unchanged from original)
// ═══════════════════════════════════════════════════════════════

class _StatTile extends StatelessWidget {
  final bool isDark;
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatTile({
    required this.isDark,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppTheme.darkTextTertiary
                  : AppTheme.lightTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
