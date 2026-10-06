import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class ResetAuthEvent extends AuthEvent {}

class SetAvailabilityEvent extends AuthEvent {
  final bool isAvailable;
  SetAvailabilityEvent(this.isAvailable);
}

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

class AuthVerified extends AuthState {
  final User user;
  final bool isRegisteredAgent;
  final bool isVerified;
  AuthVerified(this.user,
      {required this.isRegisteredAgent, this.isVerified = false});
}

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
  final _db = FirebaseFirestore.instance;

  AuthBloc({required this.repository}) : super(AuthInitial()) {
    on<CheckAuthEvent>(_onCheck);
    on<SendOTPEvent>(_onSendOTP);
    on<VerifyOTPEvent>(_onVerifyOTP);
    on<SignOutEvent>(_onSignOut);
    on<SetAvailabilityEvent>(_onSetAvailability);
    on<ResetAuthEvent>((event, emit) => emit(AuthInitial()));
  }

  Future<void> _onCheck(
      CheckAuthEvent event, Emitter<AuthState> emit) async {
    final user = repository.currentUser;
    if (user == null) {
      emit(AuthUnauthenticated());
    } else {
      // Set available on app resume / restart
      await _setAvailable(user.uid, true);
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

      // ── Set online when rider logs in ──────────────────────
      if (result.isRegisteredAgent && result.isVerified) {
        await _setAvailable(result.user.uid, true);
      }

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
    // ── Set offline before signing out ─────────────────────
    final user = repository.currentUser;
    if (user != null) {
      await _setAvailable(user.uid, false);
    }
    await repository.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onSetAvailability(
      SetAvailabilityEvent event, Emitter<AuthState> emit) async {
    final user = repository.currentUser;
    if (user == null) return;
    await _setAvailable(user.uid, event.isAvailable);
  }

  // ── Helper ────────────────────────────────────────────────
  Future<void> _setAvailable(String userId, bool isAvailable) async {
    try {
      final doc = await _db.collection('deliveryAgents').doc(userId).get();
      if (!doc.exists) return; // not registered yet — skip
      await _db.collection('deliveryAgents').doc(userId).update({
        'isAvailable': isAvailable,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-critical — don't crash the app
    }
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
