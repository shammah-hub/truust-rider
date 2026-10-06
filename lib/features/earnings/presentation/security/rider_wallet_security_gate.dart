import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:truust_rider/core/theme/app_theme.dart';

import '../../rider_pin_reset_page.dart';

// ═══════════════════════════════════════════════════════════════
//  WALLET SECURITY GATE
//
//  Usage — wrap any sensitive action (withdrawal, transfer):
//
//    WalletSecurityGate.authenticate(
//      context: context,
//      onSuccess: () => _openWithdrawalSheet(),
//    );
//
//  On first use, user is prompted to SET a PIN.
//  Subsequent uses: biometrics first → PIN fallback.
//
//  Files needed in pubspec.yaml:
//    local_auth: ^2.1.8
//    flutter_secure_storage: ^9.0.0
//
//  Android — add to AndroidManifest.xml:
//    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
//    <uses-permission android:name="android.permission.USE_FINGERPRINT"/>
//  Also in MainActivity, change FlutterActivity to FlutterFragmentActivity.
//
//  iOS — add to Info.plist:
//    <key>NSFaceIDUsageDescription</key>
//    <string>Authenticate to access your wallet</string>
//
//  Place at: lib/features/wallet/presentation/wallet_security_gate.dart
// ═══════════════════════════════════════════════════════════════

const _kPinKey = 'truust_wallet_pin';
final _auth    = LocalAuthentication();
final _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class WalletSecurityGate {
  /// Returns true if the user has already created a wallet PIN.
  static Future<bool> hasPinSet() async {
    try {
      final pin = await _storage.read(key: _kPinKey);
      return pin != null && pin.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Call this before any financial action.
  /// Handles: PIN setup (first time) → biometrics → PIN fallback.
  static Future<void> authenticate({
    required BuildContext context,
    required VoidCallback onSuccess,
    String reason = 'Confirm your identity to continue',
  }) async {
    final existingPin = await _storage.read(key: _kPinKey);

    if (existingPin == null) {
      // First time — set a PIN
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _PinSetupSheet(
          onPinSet: (pin) async {
            await _storage.write(key: _kPinKey, value: pin);
            if (context.mounted) Navigator.pop(context);
            onSuccess();
          },
        ),
      );
      return;
    }

    // Try biometrics first
    final biometricAvailable = await _tryBiometrics(reason);
    if (biometricAvailable == _BiometricResult.success) {
      onSuccess();
      return;
    }

    // Biometrics failed or unavailable — fall back to PIN
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => _PinEntrySheet(
        reason: reason,
        onSuccess: () {
          Navigator.pop(context);
          onSuccess();
        },
        showBiometricButton: biometricAvailable == _BiometricResult.failed,
        onBiometricRetry: () async {
          Navigator.pop(context);
          final result = await _tryBiometrics(reason);
          if (result == _BiometricResult.success && context.mounted) {
            onSuccess();
          } else if (context.mounted) {
            authenticate(context: context, onSuccess: onSuccess, reason: reason);
          }
        },
      ),
    );
  }

  /// Let user change their PIN (from wallet settings).
  static Future<void> changePin({
    required BuildContext context,
    required VoidCallback onSuccess,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _PinSetupSheet(
        isChanging: true,
        onPinSet: (pin) async {
          await _storage.write(key: _kPinKey, value: pin);
          if (context.mounted) Navigator.pop(context);
          onSuccess();
        },
      ),
    );
  }

  static Future<_BiometricResult> _tryBiometrics(String reason) async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return _BiometricResult.unavailable;

      final available = await _auth.getAvailableBiometrics();
      if (available.isEmpty) return _BiometricResult.unavailable;

      final didAuth = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return didAuth ? _BiometricResult.success : _BiometricResult.failed;
    } catch (_) {
      return _BiometricResult.unavailable;
    }
  }
}

enum _BiometricResult { success, failed, unavailable }

// ═══════════════════════════════════════════════════════════════
//  PIN SETUP SHEET
// ═══════════════════════════════════════════════════════════════

class _PinSetupSheet extends StatefulWidget {
  final void Function(String pin) onPinSet;
  final bool isChanging;
  const _PinSetupSheet({required this.onPinSet, this.isChanging = false});

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  String _pin        = '';
  String _confirmPin = '';
  bool _confirming   = false;
  bool _error        = false;
  String _errorMsg   = '';

  void _onKey(String digit) {
    setState(() {
      _error = false;
      if (!_confirming) {
        if (_pin.length < 6) {
          _pin += digit;
          if (_pin.length == 6) {
            // Move to confirm
            Future.delayed(const Duration(milliseconds: 180), () {
              if (mounted) setState(() => _confirming = true);
            });
          }
        }
      } else {
        if (_confirmPin.length < 6) {
          _confirmPin += digit;
          if (_confirmPin.length == 6) {
            Future.delayed(const Duration(milliseconds: 180), () {
              if (_confirmPin == _pin) {
                widget.onPinSet(_pin);
              } else {
                if (mounted) {
                  setState(() {
                    _confirmPin = '';
                    _error      = true;
                    _errorMsg   = 'PINs don\'t match. Try again.';
                  });
                  HapticFeedback.heavyImpact();
                }
              }
            });
          }
        }
      }
    });
    HapticFeedback.lightImpact();
  }

  void _onDelete() {
    setState(() {
      _error = false;
      if (_confirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final current  = _confirming ? _confirmPin : _pin;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(isDark),
          const SizedBox(height: 28),

          // Lock icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppTheme.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),

          Text(
            _confirming
                ? 'Confirm your PIN'
                : widget.isChanging
                ? 'Enter new PIN'
                : 'Create a wallet PIN',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.6,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _confirming
                ? 'Re-enter your 6-digit PIN'
                : 'This PIN protects your wallet & withdrawals',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 32),

          // Dots
          _PinDots(length: current.length, isDark: isDark, error: _error),
          const SizedBox(height: 12),

          // Error message
          AnimatedOpacity(
            opacity: _error ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              _errorMsg,
              style: const TextStyle(fontSize: 13, color: AppTheme.error, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 28),

          // Keypad
          _Keypad(onKey: _onKey, onDelete: _onDelete, isDark: isDark),

          // Back button if in confirm step
          if (_confirming) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() {
                _confirming  = false;
                _pin         = '';
                _confirmPin  = '';
                _error       = false;
              }),
              child: Text(
                'Start over',
                style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PIN ENTRY SHEET  (auth — not setup)
// ═══════════════════════════════════════════════════════════════

class _PinEntrySheet extends StatefulWidget {
  final String reason;
  final VoidCallback onSuccess;
  final bool showBiometricButton;
  final VoidCallback? onBiometricRetry;

  const _PinEntrySheet({
    required this.reason,
    required this.onSuccess,
    this.showBiometricButton = false,
    this.onBiometricRetry,
  });

  @override
  State<_PinEntrySheet> createState() => _PinEntrySheetState();
}

class _PinEntrySheetState extends State<_PinEntrySheet>
    with SingleTickerProviderStateMixin {
  String _pin       = '';
  bool _error       = false;
  int _attempts     = 0;
  bool _locked      = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_locked) return;
    setState(() {
      _error = false;
      if (_pin.length < 6) {
        _pin += digit;
        if (_pin.length == 6) {
          Future.delayed(const Duration(milliseconds: 180), _verify);
        }
      }
    });
    HapticFeedback.lightImpact();
  }

  void _onDelete() {
    if (_locked) return;
    setState(() {
      _error = false;
      if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _verify() async {
    final stored = await _storage.read(key: _kPinKey);
    if (_pin == stored) {
      widget.onSuccess();
    } else {
      _attempts++;
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
      setState(() {
        _error = true;
        _pin   = '';
        if (_attempts >= 5) _locked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(isDark),
          const SizedBox(height: 28),

          // Icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: (_locked ? AppTheme.error : AppTheme.blue).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (_locked ? AppTheme.error : AppTheme.blue).withOpacity(0.3)),
            ),
            child: Icon(
              _locked ? Icons.lock_outline_rounded : Icons.fingerprint_rounded,
              color: _locked ? AppTheme.error : AppTheme.blue,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _locked ? 'Wallet locked' : 'Enter your PIN',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.6,
              color: _locked ? AppTheme.error : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _locked
                ? 'Too many wrong attempts. Restart the app to try again.'
                : widget.reason,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 32),

          if (!_locked) ...[
            // Shake animation on dots
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) {
                final offset = _error
                    ? 8 * (0.5 - (_shakeAnim.value - 0.5).abs()) * 2
                    : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: _PinDots(length: _pin.length, isDark: isDark, error: _error),
            ),
            const SizedBox(height: 12),

            AnimatedOpacity(
              opacity: _error ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                _attempts >= 4
                    ? 'Last attempt before wallet locks'
                    : 'Incorrect PIN. ${5 - _attempts} attempts remaining.',
                style: const TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 28),

            _Keypad(onKey: _onKey, onDelete: _onDelete, isDark: isDark),

            // Biometric retry button
            if (widget.showBiometricButton) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: widget.onBiometricRetry,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fingerprint_rounded,
                        size: 18,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Use biometrics instead',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Forgot PIN
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(context); // close sheet first
                final ctx = context;
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (ctx.mounted) {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => PinResetPage(
                          onComplete: () {
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    );
                  }
                });
              },
              child: Text(
                'Forgot PIN?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.blue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PIN DOTS  (visual indicator)
// ═══════════════════════════════════════════════════════════════

class _PinDots extends StatelessWidget {
  final int length;
  final bool isDark;
  final bool error;
  const _PinDots({required this.length, required this.isDark, required this.error});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: filled ? 16 : 14,
          height: filled ? 16 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error
                ? AppTheme.error
                : filled
                ? AppTheme.blue
                : Colors.transparent,
            border: Border.all(
              color: error
                  ? AppTheme.error
                  : filled
                  ? AppTheme.blue
                  : (isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.2)),
              width: 2,
            ),
            boxShadow: filled && !error
                ? [BoxShadow(color: AppTheme.blue.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
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
  final void Function(String) onKey;
  final VoidCallback onDelete;
  final bool isDark;
  const _Keypad({required this.onKey, required this.onDelete, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Column(
      children: rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 80);
            if (key == 'del') {
              return _KeyBtn(
                isDark: isDark,
                onTap: onDelete,
                child: Icon(Icons.backspace_outlined,
                    size: 20,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              );
            }
            return _KeyBtn(
              isDark: isDark,
              onTap: () => onKey(key),
              child: Text(key,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            );
          }).toList(),
        ),
      )).toList(),
    );
  }
}

class _KeyBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;
  const _KeyBtn({required this.child, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 64,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.07),
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════

Widget _handle(bool isDark) => Container(
  width: 40, height: 4,
  decoration: BoxDecoration(
    color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1),
    borderRadius: BorderRadius.circular(2),
  ),
);
