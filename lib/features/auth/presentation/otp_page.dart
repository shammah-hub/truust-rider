import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import 'agent_setup_page.dart';
import 'pending_verification_page.dart';
import '../../../navigation/main_navigation.dart';

class OtpPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;

  const OtpPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final List<TextEditingController> _ctrls =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  int _resendSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  void _onDigit(int index, String val) {
    if (val.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }
    _tryVerify();
  }

  void _tryVerify() {
    final otp = _ctrls.map((c) => c.text).join();
    if (otp.length == 6) {
      HapticFeedback.mediumImpact();
      context.read<AuthBloc>().add(
        VerifyOTPEvent(widget.verificationId, otp),
      );
    }
  }

  void _resend() {
    if (_resendSeconds > 0) return;
    setState(() => _resendSeconds = 60);
    _startTimer();
    context.read<AuthBloc>().add(
      SendOTPEvent(widget.phoneNumber,
          resendToken: widget.resendToken),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthVerified) {
            if (!state.isRegisteredAgent) {
              // New — go to setup
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => AgentSetupPage(
                    userId: state.user.uid,
                  ),
                ),
                (route) => false,
              );
            } else if (state.isVerified) {
              // Registered + verified → main app
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MainNavigation(userId: state.user.uid),
                ),
                (route) => false,
              );
            } else {
              // Registered but pending verification
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => PendingVerificationPage(
                    userId: state.user.uid,
                  ),
                ),
                (route) => false,
              );
            }
          } else if (state is AuthError) {
            // Clear OTP fields on error
            for (final c in _ctrls) c.clear();
            _nodes[0].requestFocus();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Padding(
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

                  Text(
                    'Enter OTP',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sent to ${widget.phoneNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.lightTextTertiary,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // OTP boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) {
                      return SizedBox(
                        width: 46,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : AppTheme.lightSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _ctrls[i].text.isNotEmpty
                                  ? AppTheme.blue
                                  : (isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.08)),
                              width:
                              _ctrls[i].text.isNotEmpty ? 2 : 1,
                            ),
                          ),
                          child: TextField(
                            controller: _ctrls[i],
                            focusNode: _nodes[i],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
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

                  const SizedBox(height: 28),

                  // Resend
                  Center(
                    child: GestureDetector(
                      onTap: _resend,
                      child: Text(
                        _resendSeconds > 0
                            ? 'Resend in ${_resendSeconds}s'
                            : 'Resend OTP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _resendSeconds > 0
                              ? (isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.lightTextTertiary)
                              : AppTheme.blue,
                        ),
                      ),
                    ),
                  ),

                  if (isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.blue),
                    ),
                  ],

                  const Spacer(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
