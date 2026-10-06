import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:truust_rider/core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  PIN RESET PAGE
//
//  Flow:
//  Step 0 — send OTP to user's registered phone
//  Step 1 — enter 6-digit OTP
//  Step 2 — enter new PIN
//  Step 3 — confirm new PIN
//  Step 4 — success
//
//  Uses Firebase Phone Auth (re-auth) to verify identity,
//  then writes new PIN to flutter_secure_storage.
//
//  Usage — from wallet_security_gate.dart PIN entry sheet:
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => PinResetPage(
//        onComplete: () => Navigator.pop(context),
//      ),
//    ));
//
//  Place at: lib/features/wallet/presentation/pin_reset_page.dart
// ═══════════════════════════════════════════════════════════════

const _kPinKey = 'truust_wallet_pin';
final _storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class PinResetPage extends StatefulWidget {
  final VoidCallback onComplete;
  const PinResetPage({super.key, required this.onComplete});

  @override
  State<PinResetPage> createState() => _PinResetPageState();
}

class _PinResetPageState extends State<PinResetPage>
    with TickerProviderStateMixin {
  // Steps: 0=sending OTP, 1=enter OTP, 2=new PIN, 3=confirm PIN, 4=success
  int _step = 0;

  // OTP state
  bool   _sendingOtp  = false;
  bool   _otpSent     = false;
  String _otpCode     = '';
  bool   _otpError    = false;
  String _verificationId = '';
  bool   _verifying   = false;

  // Resend timer
  int  _resendSeconds = 60;
  bool _canResend     = false;

  // PIN state
  String _newPin     = '';
  String _confirmPin = '';
  bool   _pinError   = false;

  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;
  late AnimationController _successCtrl;
  late Animation<double>   _successScale;

  // OTP input controllers (6 boxes)
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes  = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _slideAnim = Tween<Offset>(
        begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _slideCtrl, curve: Curves.easeOutCubic));

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _successScale = CurvedAnimation(
        parent: _successCtrl, curve: Curves.elasticOut);

    _slideCtrl.forward();
    _sendOtp();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _successCtrl.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes)  f.dispose();
    super.dispose();
  }

  // ── OTP ─────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phone == null) {
      _showSnack('No phone number found on account', isError: true);
      return;
    }

    setState(() { _sendingOtp = true; _canResend = false; _resendSeconds = 60; });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Auto-verified on Android
        await _verifyCredential(credential);
      },
      verificationFailed: (e) {
        setState(() { _sendingOtp = false; });
        _showSnack('Failed to send OTP: ${e.message}', isError: true);
      },
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _sendingOtp     = false;
          _otpSent        = true;
          _step           = 1;
        });
        _animateSlide();
        _startResendTimer();
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) _canResend = true;
      });
      return _resendSeconds > 0;
    });
  }

  Future<void> _submitOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() { _verifying = true; _otpError = false; });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode:        code,
      );
      await _verifyCredential(credential);
    } catch (_) {
      HapticFeedback.heavyImpact();
      setState(() {
        _otpError  = true;
        _verifying = false;
        for (final c in _otpControllers) c.clear();
      });
      _otpFocusNodes[0].requestFocus();
    }
  }

  Future<void> _verifyCredential(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.currentUser
          ?.reauthenticateWithCredential(credential);
      // OTP verified — move to PIN entry
      setState(() {
        _verifying = false;
        _step      = 2;
      });
      _animateSlide();
    } catch (_) {
      HapticFeedback.heavyImpact();
      setState(() {
        _otpError  = true;
        _verifying = false;
        for (final c in _otpControllers) c.clear();
      });
      _otpFocusNodes[0].requestFocus();
    }
  }

  // ── PIN ─────────────────────────────────────────────────────

  void _onPinKey(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _pinError = false;
      if (_step == 2) {
        if (_newPin.length < 6) {
          _newPin += digit;
          if (_newPin.length == 6) {
            Future.delayed(const Duration(milliseconds: 250), () {
              setState(() => _step = 3);
              _animateSlide();
            });
          }
        }
      } else if (_step == 3) {
        if (_confirmPin.length < 6) {
          _confirmPin += digit;
          if (_confirmPin.length == 6) {
            Future.delayed(const Duration(milliseconds: 180), _savePin);
          }
        }
      }
    });
  }

  void _onPinDelete() {
    HapticFeedback.lightImpact();
    setState(() {
      _pinError = false;
      if (_step == 2) {
        if (_newPin.isNotEmpty) {
          _newPin = _newPin.substring(0, _newPin.length - 1);
        }
      } else if (_step == 3) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  Future<void> _savePin() async {
    if (_confirmPin != _newPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pinError   = true;
        _confirmPin = '';
      });
      return;
    }
    await _storage.write(key: _kPinKey, value: _newPin);
    setState(() => _step = 4);
    _successCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onComplete();
  }

  void _animateSlide() {
    _slideCtrl.reset();
    _slideCtrl.forward();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                if (_step != 4)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurface
                            : AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.07),
                        ),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary),
                    ),
                  ),
                const Spacer(),
                // Step indicator
                if (_step > 0 && _step < 4)
                  Row(
                    children: List.generate(3, (i) {
                      final active = i < _step;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(left: 6),
                        width:  active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.blue
                              : (isDark
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
              ]),
            ),

            Expanded(
              child: _step == 4
                  ? _SuccessView(isDark: isDark, scaleAnim: _successScale)
                  : SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _slideCtrl,
                  child: _step == 0
                      ? _SendingView(isDark: isDark)
                      : _step == 1
                      ? _OtpView(
                    isDark:       isDark,
                    controllers:  _otpControllers,
                    focusNodes:   _otpFocusNodes,
                    error:        _otpError,
                    verifying:    _verifying,
                    canResend:    _canResend,
                    resendSeconds: _resendSeconds,
                    onSubmit:     _submitOtp,
                    onResend:     _sendOtp,
                    phone: _maskedPhone(),
                  )
                      : _PinView(
                    isDark:  isDark,
                    step:    _step,
                    newPin:  _newPin,
                    confirm: _confirmPin,
                    error:   _pinError,
                    onKey:   _onPinKey,
                    onDelete: _onPinDelete,
                    onStartOver: _step == 3
                        ? () => setState(() {
                      _step       = 2;
                      _newPin     = '';
                      _confirmPin = '';
                      _pinError   = false;
                    })
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskedPhone() {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    if (phone.length < 4) return phone;
    return '${phone.substring(0, phone.length - 4).replaceAll(RegExp(r'\d'), '*')}${phone.substring(phone.length - 4)}';
  }
}

// ═══════════════════════════════════════════════════════════════
//  STEP VIEWS
// ═══════════════════════════════════════════════════════════════

class _SendingView extends StatelessWidget {
  final bool isDark;
  const _SendingView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.blue, strokeWidth: 3),
          const SizedBox(height: 20),
          Text('Sending verification code...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  OTP ENTRY
// ─────────────────────────────────────────────────────────────

class _OtpView extends StatelessWidget {
  final bool isDark;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool error;
  final bool verifying;
  final bool canResend;
  final int resendSeconds;
  final String phone;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  const _OtpView({
    required this.isDark,
    required this.controllers,
    required this.focusNodes,
    required this.error,
    required this.verifying,
    required this.canResend,
    required this.resendSeconds,
    required this.phone,
    required this.onSubmit,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.blue.withOpacity(0.25)),
            ),
            child: const Icon(Icons.sms_outlined,
                color: AppTheme.blue, size: 32),
          ),
          const SizedBox(height: 22),

          Text('Verify your identity',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              )),
          const SizedBox(height: 8),
          Text('Enter the 6-digit code sent to $phone',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              )),
          const SizedBox(height: 36),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 46,
                child: TextField(
                  controller:  controllers[i],
                  focusNode:   focusNodes[i],
                  textAlign:   TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength:   1,
                  style: TextStyle(
                    fontSize:   22,
                    fontWeight: FontWeight.w800,
                    color: error
                        ? AppTheme.error
                        : (isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled:      true,
                    fillColor:   isDark
                        ? AppTheme.darkSurface
                        : AppTheme.lightSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: error
                            ? AppTheme.error
                            : (isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1)),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: error
                            ? AppTheme.error
                            : (isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1)),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: error ? AppTheme.error : AppTheme.blue,
                          width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && i < 5) {
                      focusNodes[i + 1].requestFocus();
                    }
                    if (val.isEmpty && i > 0) {
                      focusNodes[i - 1].requestFocus();
                    }
                    // Auto submit when last box filled
                    if (i == 5 && val.isNotEmpty) {
                      Future.delayed(
                        const Duration(milliseconds: 100),
                            () => FocusScope.of(context).unfocus(),
                      );
                    }
                  },
                ),
              );
            }),
          ),

          const SizedBox(height: 12),
          AnimatedOpacity(
            opacity:  error ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Text('Incorrect code. Please try again.',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error)),
          ),

          const SizedBox(height: 28),

          // Verify button
          GestureDetector(
            onTap: verifying ? null : onSubmit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:  AppTheme.blue.withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: verifying
                    ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                    : const Text('Verify Code',
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w800,
                      color:      Colors.white,
                    )),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Resend
          GestureDetector(
            onTap: canResend ? onResend : null,
            child: Text(
              canResend
                  ? 'Resend code'
                  : 'Resend in ${resendSeconds}s',
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color: canResend
                    ? AppTheme.blue
                    : (isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PIN ENTRY  (new PIN + confirm)
// ─────────────────────────────────────────────────────────────

class _PinView extends StatelessWidget {
  final bool isDark;
  final int step;
  final String newPin;
  final String confirm;
  final bool error;
  final void Function(String) onKey;
  final VoidCallback onDelete;
  final VoidCallback? onStartOver;

  const _PinView({
    required this.isDark,
    required this.step,
    required this.newPin,
    required this.confirm,
    required this.error,
    required this.onKey,
    required this.onDelete,
    this.onStartOver,
  });

  @override
  Widget build(BuildContext context) {
    final isConfirm = step == 3;
    final pin       = isConfirm ? confirm : newPin;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.blue.withOpacity(0.25)),
            ),
            child: Icon(
              isConfirm
                  ? Icons.check_circle_outline_rounded
                  : Icons.lock_rounded,
              color: AppTheme.blue,
              size: 32,
            ),
          ),
          const SizedBox(height: 22),

          Text(
            isConfirm ? 'Confirm new PIN' : 'Set new PIN',
            style: TextStyle(
              fontSize:   26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isConfirm
                ? 'Re-enter the same 6-digit PIN'
                : 'Choose a new 6-digit wallet PIN',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 36),

          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final filled = i < pin.length;
              final color  = error ? AppTheme.error : AppTheme.blue;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 9),
                width:  filled ? 16 : 14,
                height: filled ? 16 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? color : Colors.transparent,
                  border: Border.all(
                    color: filled
                        ? color
                        : (isDark
                        ? Colors.white.withOpacity(0.25)
                        : Colors.black.withOpacity(0.2)),
                    width: 2,
                  ),
                  boxShadow: filled && !error
                      ? [BoxShadow(
                      color: AppTheme.blue.withOpacity(0.4),
                      blurRadius: 8, spreadRadius: 1)]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          AnimatedOpacity(
            opacity:  error ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Text("PINs don't match. Try again.",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error)),
          ),

          const SizedBox(height: 28),

          // Keypad
          _Keypad(isDark: isDark, onKey: onKey, onDelete: onDelete),

          if (onStartOver != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onStartOver,
              child: Text('Start over',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.lightTextTertiary,
                  )),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SUCCESS VIEW
// ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final bool isDark;
  final Animation<double> scaleAnim;
  const _SuccessView({required this.isDark, required this.scaleAnim});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: scaleAnim,
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color:      AppTheme.blue.withOpacity(0.35),
                    blurRadius: 28,
                    offset:     const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          Text('PIN Reset!',
              style: TextStyle(
                fontSize:   26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              )),
          const SizedBox(height: 10),
          Text('Your new wallet PIN is active.',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  KEYPAD
// ═══════════════════════════════════════════════════════════════

class _Keypad extends StatelessWidget {
  final bool isDark;
  final void Function(String) onKey;
  final VoidCallback onDelete;
  const _Keypad({
    required this.isDark,
    required this.onKey,
    required this.onDelete,
  });

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 80);
              if (key == 'del') {
                return _KeyBtn(
                  isDark: isDark,
                  onTap:  onDelete,
                  child:  Icon(Icons.backspace_outlined,
                      size: 20,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary),
                );
              }
              return _KeyBtn(
                isDark: isDark,
                onTap:  () => onKey(key),
                child:  Text(key,
                    style: TextStyle(
                      fontSize:   22,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    )),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _KeyBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;
  const _KeyBtn({
    required this.child,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 64,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.07),
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}
