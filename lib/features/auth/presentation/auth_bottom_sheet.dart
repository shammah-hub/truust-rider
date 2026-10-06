import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import 'agent_setup_page.dart';
import 'pending_verification_page.dart';
import '../../../navigation/main_navigation.dart';

// ═══════════════════════════════════════════════════════════════
//  RIDER AUTH BOTTOM SHEET
//  Same floating-sheet pattern as the main app's auth flow.
//  Call showAuthFlow(context) from anywhere with AuthBloc
//  provided above the call site.
// ═══════════════════════════════════════════════════════════════

Future<void> showAuthFlow(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _AuthSheetContent(),
  );
}

enum _AuthStep { phone, otp }

class _AuthSheetContent extends StatefulWidget {
  const _AuthSheetContent();

  @override
  State<_AuthSheetContent> createState() => _AuthSheetContentState();
}

class _AuthSheetContentState extends State<_AuthSheetContent> {
  _AuthStep _step = _AuthStep.phone;
  String _verificationId = '';
  String _phoneNumber = '';
  int? _resendToken;
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = context.read<AuthBloc>();
  }

  @override
  void dispose() {
    _authBloc.add(ResetAuthEvent());
    super.dispose();
  }

  void _goToOtp(String verificationId, String phoneNumber, int? resendToken) {
    setState(() {
      _verificationId = verificationId;
      _phoneNumber = phoneNumber;
      _resendToken = resendToken;
      _step = _AuthStep.otp;
    });
  }

  void _backToPhone() => setState(() => _step = _AuthStep.phone);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthVerified) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!context.mounted) return;
            Navigator.of(context).pop(); // close sheet

            Widget destination;
            if (!state.isRegisteredAgent) {
              destination = AgentSetupPage(userId: state.user.uid);
            } else if (state.isVerified) {
              destination = MainNavigation(userId: state.user.uid);
            } else {
              destination = PendingVerificationPage(userId: state.user.uid);
            }

            Navigator.of(context).pushAndRemoveUntil(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => destination,
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 350),
              ),
                  (route) => false,
            );
          });
        }
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 48,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            22, 16, 22,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) {
                final goingToOtp = child.key == const ValueKey('otp');
                final slide = Tween<Offset>(
                  begin: Offset(goingToOtp ? 0.08 : -0.08, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: _step == _AuthStep.phone
                  ? _PhoneStep(key: const ValueKey('phone'), onCodeSent: _goToOtp)
                  : _OtpStep(
                key: const ValueKey('otp'),
                verificationId: _verificationId,
                phoneNumber: _phoneNumber,
                resendToken: _resendToken,
                onEditNumber: _backToPhone,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED HEADER
// ═══════════════════════════════════════════════════════════════

class _StepHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  const _StepHeader({required this.title, this.subtitle, this.onClose});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (onClose != null)
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.close, size: 16,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
            ),
          ),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PHONE STEP
// ═══════════════════════════════════════════════════════════════

class _PhoneStep extends StatefulWidget {
  final void Function(String verificationId, String phoneNumber, int? resendToken) onCodeSent;

  const _PhoneStep({super.key, required this.onCodeSent});

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  final _phoneCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
    _phoneCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _formattedPhone {
    String n = _phoneCtrl.text.trim();
    if (n.startsWith('0')) n = n.substring(1);
    if (n.startsWith('234')) n = n.substring(3);
    return '+234$n';
  }

  bool get _isValid {
    String n = _phoneCtrl.text.trim();
    if (n.startsWith('0')) n = n.substring(1);
    if (n.startsWith('234')) n = n.substring(3);
    return n.length == 10 && RegExp(r'^\d+$').hasMatch(n);
  }

  void _submit(BuildContext context) {
    if (!_isValid) return;
    HapticFeedback.lightImpact();
    setState(() => _errorMessage = null);
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(SendOTPEvent(_formattedPhone));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is OTPSent) {
          widget.onCodeSent(state.verificationId, _formattedPhone, state.resendToken);
        } else if (state is AuthError) {
          setState(() => _errorMessage = state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Column(
          key: const ValueKey('phone-col'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeader(
              title: 'Phone Number',
              subtitle: "We'll send a confirmation code.",
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 18),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(_isFocused ? 1.8 : 1),
              decoration: BoxDecoration(
                color: _isFocused
                    ? AppTheme.blue
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2,
                  borderRadius: BorderRadius.circular(12.5),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Text('🇳🇬', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text('+234',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                              )),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        onSubmitted: (_) => _submit(context),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '8012345678',
                          hintStyle: TextStyle(
                            color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_phoneCtrl.text.isNotEmpty && !_isValid) ...[
              const SizedBox(height: 6),
              Text('Enter your 10-digit Nigerian number',
                  style: TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w500)),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(_errorMessage!,
                  style: TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: isLoading
                  ? _GradientLoader()
                  : ElevatedButton(
                onPressed: _isValid ? () => _submit(context) : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _isValid ? AppTheme.primaryGradient : null,
                    color: _isValid ? null : (isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      'Get OTP',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _isValid
                            ? Colors.white
                            : (isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  OTP STEP
// ═══════════════════════════════════════════════════════════════

class _OtpStep extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;
  final VoidCallback onEditNumber;

  const _OtpStep({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.onEditNumber,
    this.resendToken,
  });

  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late String _currentVerificationId;
  int? _currentResendToken;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _currentResendToken = widget.resendToken;
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _resend() {
    for (final c in _controllers) c.clear();
    setState(() => _isError = false);
    _focusNodes[0].requestFocus();
    context.read<AuthBloc>().add(
      SendOTPEvent(widget.phoneNumber, resendToken: _currentResendToken),
    );
    _startCountdown();
  }

  String get _fullOtp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (_isError) setState(() => _isError = false);
    if (value.length == 1 && index < 5) _focusNodes[index + 1].requestFocus();
    setState(() {});
    if (_fullOtp.length == 6) {
      FocusScope.of(context).unfocus();
      context.read<AuthBloc>().add(VerifyOTPEvent(_currentVerificationId, _fullOtp));
    }
  }

  void _onKeyPress(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is OTPSent) {
          setState(() {
            _currentVerificationId = state.verificationId;
            _currentResendToken = state.resendToken;
          });
        } else if (state is AuthError) {
          for (final c in _controllers) c.clear();
          _focusNodes[0].requestFocus();
          setState(() => _isError = true);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Column(
            key: const ValueKey('otp-col'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepHeader(
                title: 'Verification Code',
                subtitle: 'Enter the 6-digit code sent to ${widget.phoneNumber}',
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 44,
                    height: 54,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isError
                              ? AppTheme.error
                              : (_controllers[i].text.isNotEmpty
                              ? AppTheme.blue
                              : (isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.08))),
                          width: _controllers[i].text.isNotEmpty || _isError ? 2 : 1,
                        ),
                      ),
                      child: RawKeyboardListener(
                        focusNode: FocusNode(),
                        onKey: (e) => _onKeyPress(i, e),
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) => _onDigitChanged(i, v),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              if (_isError) ...[
                const SizedBox(height: 10),
                Text('Wrong OTP. Please try again.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error)),
              ],
              if (isLoading) ...[
                const SizedBox(height: 14),
                const Center(child: CircularProgressIndicator(color: AppTheme.blue)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onEditNumber,
                    child: Text(
                      'Wrong number? Edit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _secondsRemaining > 0
                      ? Text('Resend in ${_secondsRemaining}s',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary))
                      : GestureDetector(
                    onTap: _resend,
                    child: const Text('Resend code',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.blue)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  GRADIENT LOADER
// ═══════════════════════════════════════════════════════════════

class _GradientLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(color: AppTheme.blue, borderRadius: BorderRadius.circular(30)),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }
}
