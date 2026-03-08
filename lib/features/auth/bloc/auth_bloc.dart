import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/auth_repository.dart';

// ── Events ───────────────────────────────────────────────────
abstract class AuthEvent {}

class CheckAuthEvent extends AuthEvent {}

class SendOTPEvent extends AuthEvent {
  final String phoneNumber;
  final int? resendToken;
  SendOTPEvent(this.phoneNumber, {this.resendToken});
}

class VerifyOTPEvent extends AuthEvent {
  final String verificationId;
  final String otp;
  VerifyOTPEvent(this.verificationId, this.otp);
}

class SignOutEvent extends AuthEvent {}

// ── States ───────────────────────────────────────────────────
abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class OTPSent extends AuthState {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;
  OTPSent(this.verificationId, this.phoneNumber, {this.resendToken});
}

// User verified OTP — now check registration + verification status
class AuthVerified extends AuthState {
  final User user;
  final bool isRegisteredAgent;
  final bool isVerified;
  AuthVerified(this.user,
      {required this.isRegisteredAgent, this.isVerified = false});
}

// Fully authenticated registered agent
class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// ── Bloc ─────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  AuthBloc({required this.repository}) : super(AuthInitial()) {
    on<CheckAuthEvent>(_onCheck);
    on<SendOTPEvent>(_onSendOTP);
    on<VerifyOTPEvent>(_onVerifyOTP);
    on<SignOutEvent>(_onSignOut);
  }

  Future<void> _onCheck(
      CheckAuthEvent event, Emitter<AuthState> emit) async {
    final user = repository.currentUser;
    if (user == null) {
      emit(AuthUnauthenticated());
    } else {
      emit(AuthAuthenticated(user));
    }
  }

  Future<void> _onSendOTP(
      SendOTPEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final verificationId = await repository.verifyPhoneNumber(
        event.phoneNumber,
        resendToken: event.resendToken,
      );
      emit(OTPSent(
        verificationId,
        event.phoneNumber,
        resendToken: repository.lastResendToken,
      ));
    } catch (e) {
      emit(AuthError(_friendly(e)));
    }
  }

  Future<void> _onVerifyOTP(
      VerifyOTPEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await repository.verifyOTP(
        event.verificationId,
        event.otp,
      );
      emit(AuthVerified(
        result.user,
        isRegisteredAgent: result.isRegisteredAgent,
        isVerified: result.isVerified,
      ));
    } catch (e) {
      emit(AuthError(_friendly(e)));
    }
  }

  Future<void> _onSignOut(
      SignOutEvent event, Emitter<AuthState> emit) async {
    await repository.signOut();
    emit(AuthUnauthenticated());
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('invalid-verification-code')) return 'Wrong OTP. Please try again.';
    if (msg.contains('too-many-requests')) return 'Too many attempts. Wait a moment.';
    if (msg.contains('invalid-phone-number')) return 'Invalid phone number.';
    if (msg.startsWith('Exception: ')) return msg.substring(11);
    return 'Something went wrong. Please try again.';
  }
}
