import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:truust_rider/core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  WALLET PIN SETUP PAGE
//
//  A full-screen page for first-time PIN creation or changing PIN.
//
//  Usage — first time (from wallet page banner or withdraw button):
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => WalletPinSetupPage(
//        onComplete: () => Navigator.pop(context),
//      ),
//    ));
//
//  Usage — change PIN (from settings):
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => WalletPinSetupPage(
//        isChanging: true,
//        onComplete: () => Navigator.pop(context),
//      ),
//    ));
//
//  Place at: lib/features/wallet/presentation/wallet_pin_setup_page.dart
// ═══════════════════════════════════════════════════════════════

const _kPinKey = 'truust_wallet_pin';
final _storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class WalletPinSetupPage extends StatefulWidget {
  final VoidCallback onComplete;
  final bool isChanging;

  const WalletPinSetupPage({
    super.key,
    required this.onComplete,
    this.isChanging = false,
  });

  @override
  State<WalletPinSetupPage> createState() => _WalletPinSetupPageState();
}

class _WalletPinSetupPageState extends State<WalletPinSetupPage>
    with TickerProviderStateMixin {
  // Steps:
  //   isChanging == false  → step 0: enter new PIN, step 1: confirm, step 2: success
  //   isChanging == true   → step -1: verify old PIN, step 0: enter new PIN, step 1: confirm, step 2: success
  bool _verifyingOld = false;
  String _oldPin     = '';
  bool _oldPinError  = false;

  int    _step    = 0;
  String _pin     = '';
  String _confirm = '';
  bool   _error   = false;
  String _errorMsg = '';

  late AnimationController _successCtrl;
  late Animation<double>   _successScale;
  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _successScale = CurvedAnimation(
        parent: _successCtrl, curve: Curves.elasticOut);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _slideAnim = Tween<Offset>(
        begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _slideCtrl, curve: Curves.easeOutCubic));

    _slideCtrl.forward();

    if (widget.isChanging) _verifyingOld = true;
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Key input ───────────────────────────────────────────────

  void _onKey(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _error       = false;
      _oldPinError = false;

      if (_verifyingOld) {
        if (_oldPin.length < 6) {
          _oldPin += digit;
          if (_oldPin.length == 6) {
            Future.delayed(
                const Duration(milliseconds: 180), _verifyOldPin);
          }
        }
        return;
      }

      if (_step == 0) {
        if (_pin.length < 6) {
          _pin += digit;
          if (_pin.length == 6) {
            Future.delayed(
                const Duration(milliseconds: 260), _advanceToConfirm);
          }
        }
      } else if (_step == 1) {
        if (_confirm.length < 6) {
          _confirm += digit;
          if (_confirm.length == 6) {
            Future.delayed(const Duration(milliseconds: 180), _savePin);
          }
        }
      }
    });
  }

  void _onDelete() {
    HapticFeedback.lightImpact();
    setState(() {
      _error = false;
      _oldPinError = false;
      if (_verifyingOld) {
        if (_oldPin.isNotEmpty) {
          _oldPin = _oldPin.substring(0, _oldPin.length - 1);
        }
      } else if (_step == 0) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_step == 1) {
        if (_confirm.isNotEmpty) {
          _confirm = _confirm.substring(0, _confirm.length - 1);
        }
      }
    });
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _verifyOldPin() async {
    final stored = await _storage.read(key: _kPinKey);
    if (_oldPin == stored) {
      setState(() {
        _verifyingOld = false;
        _oldPin       = '';
      });
      _animateSlide();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _oldPin      = '';
        _oldPinError = true;
      });
    }
  }

  void _advanceToConfirm() {
    setState(() => _step = 1);
    _animateSlide();
  }

  Future<void> _savePin() async {
    if (_confirm != _pin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error    = true;
        _errorMsg = "PINs don't match. Try again.";
        _confirm  = '';
      });
      return;
    }
    await _storage.write(key: _kPinKey, value: _pin);
    setState(() => _step = 2);
    _successCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onComplete();
  }

  void _resetToStep0() {
    setState(() {
      _step    = 0;
      _pin     = '';
      _confirm = '';
      _error   = false;
    });
    _animateSlide();
  }

  void _animateSlide() {
    _slideCtrl.reset();
    _slideCtrl.forward();
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
            // ── Top bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                if (_step != 2)
                  GestureDetector(
                    onTap: () {
                      if (_step == 1) {
                        _resetToStep0();
                      } else {
                        Navigator.pop(context);
                      }
                    },
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
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 40),
                const Spacer(),
                // Step dots
                if (_step != 2 && !_verifyingOld) ...[
                  _StepDots(
                    total:   widget.isChanging ? 3 : 2,
                    current: _verifyingOld ? 0 : _step,
                  ),
                ],
              ]),
            ),

            // ── Content ──────────────────────────────────────
            Expanded(
              child: _step == 2
                  ? _SuccessView(
                isDark:    isDark,
                scaleAnim: _successScale,
                isChanging: widget.isChanging,
              )
                  : SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _slideCtrl,
                  child: _verifyingOld
                      ? _PinInputStep(
                    isDark:    isDark,
                    title:     'Enter current PIN',
                    subtitle:  'Verify your existing wallet PIN',
                    pin:       _oldPin,
                    error:     _oldPinError,
                    errorMsg:  'Incorrect PIN. Try again.',
                    icon:      Icons.lock_outline_rounded,
                    iconColor: AppTheme.indigo,
                    onKey:     _onKey,
                    onDelete:  _onDelete,
                  )
                      : _step == 0
                      ? _PinInputStep(
                    isDark:       isDark,
                    title:        widget.isChanging
                        ? 'Enter new PIN'
                        : 'Create your wallet PIN',
                    subtitle:     widget.isChanging
                        ? 'Choose a strong 6-digit PIN'
                        : 'Protects all withdrawals and transfers',
                    pin:          _pin,
                    error:        false,
                    errorMsg:     '',
                    icon:         Icons.lock_rounded,
                    iconColor:    AppTheme.blue,
                    onKey:        _onKey,
                    onDelete:     _onDelete,
                    showExplainer: !widget.isChanging,
                  )
                      : _PinInputStep(
                    isDark:    isDark,
                    title:     'Confirm your PIN',
                    subtitle:  'Re-enter the same 6-digit PIN',
                    pin:       _confirm,
                    error:     _error,
                    errorMsg:  _errorMsg,
                    icon:      Icons.check_circle_outline_rounded,
                    iconColor: AppTheme.success,
                    onKey:     _onKey,
                    onDelete:  _onDelete,
                    onStartOver: _resetToStep0,
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

// ═══════════════════════════════════════════════════════════════
//  PIN INPUT STEP  (reused for every input step)
// ═══════════════════════════════════════════════════════════════

class _PinInputStep extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final String pin;
  final bool error;
  final String errorMsg;
  final IconData icon;
  final Color iconColor;
  final void Function(String) onKey;
  final VoidCallback onDelete;
  final bool showExplainer;
  final VoidCallback? onStartOver;

  const _PinInputStep({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.pin,
    required this.error,
    required this.errorMsg,
    required this.icon,
    required this.iconColor,
    required this.onKey,
    required this.onDelete,
    this.showExplainer = false,
    this.onStartOver,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        children: [
          // Icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: iconColor.withOpacity(0.25)),
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(height: 22),

          // Title
          Text(title,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              )),
          const SizedBox(height: 8),

          // Subtitle
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              )),

          // Explainer bullets (first-time setup only)
          if (showExplainer) ...[
            const SizedBox(height: 20),
            _ExplainerBox(isDark: isDark),
          ],

          const SizedBox(height: 36),

          // PIN dots
          _PinDots(
            length:    pin.length,
            isDark:    isDark,
            error:     error,
          ),
          const SizedBox(height: 12),

          // Error message
          AnimatedOpacity(
            opacity:  error ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(errorMsg,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error)),
          ),

          const SizedBox(height: 28),

          // Keypad
          _Keypad(
            isDark:   isDark,
            onKey:    onKey,
            onDelete: onDelete,
          ),

          // Start over link (confirm step)
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

// ═══════════════════════════════════════════════════════════════
//  EXPLAINER BOX  (shown on first-time setup step 0)
// ═══════════════════════════════════════════════════════════════

class _ExplainerBox extends StatelessWidget {
  final bool isDark;
  const _ExplainerBox({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.blue.withOpacity(0.15)),
      ),
      child: Column(
        children: const [
          _ExplainerRow(
            icon:  Icons.shield_outlined,
            color: AppTheme.blue,
            text:  'Required every time you withdraw funds',
          ),
          SizedBox(height: 8),
          _ExplainerRow(
            icon:  Icons.fingerprint_rounded,
            color: AppTheme.indigo,
            text:  'You can also use Face ID or fingerprint',
          ),
          SizedBox(height: 8),
          _ExplainerRow(
            icon:  Icons.lock_outline_rounded,
            color: AppTheme.success,
            text:  'Stored securely — never sent to our servers',
          ),
        ],
      ),
    );
  }
}

class _ExplainerRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _ExplainerRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            )),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  SUCCESS VIEW
// ═══════════════════════════════════════════════════════════════

class _SuccessView extends StatelessWidget {
  final bool isDark;
  final Animation<double> scaleAnim;
  final bool isChanging;
  const _SuccessView({
    required this.isDark,
    required this.scaleAnim,
    required this.isChanging,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
                      color: AppTheme.blue.withOpacity(0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isChanging ? 'PIN updated!' : 'Wallet secured!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isChanging
                  ? 'Your new wallet PIN is active.'
                  : 'Your wallet PIN has been set.\nYou can now withdraw funds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STEP DOTS
// ═══════════════════════════════════════════════════════════════

class _StepDots extends StatelessWidget {
  final int total;
  final int current;
  const _StepDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PIN DOTS
// ═══════════════════════════════════════════════════════════════

class _PinDots extends StatelessWidget {
  final int length;
  final bool isDark;
  final bool error;
  const _PinDots({
    required this.length,
    required this.isDark,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < length;
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
                ? [
              BoxShadow(
                color:       AppTheme.blue.withOpacity(0.4),
                blurRadius:  8,
                spreadRadius: 1,
              )
            ]
                : null,
          ),
        );
      }),
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
                  child:  Icon(
                    Icons.backspace_outlined,
                    size: 20,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                );
              }

              return _KeyBtn(
                isDark: isDark,
                onTap:  () => onKey(key),
                child:  Text(key,
                    style: TextStyle(
                      fontSize: 22,
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
          color: isDark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
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
