import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class AuthRepository {
  Future<String> verifyPhoneNumber(String phoneNumber, {int? resendToken});
  Future<({User user, bool isRegisteredAgent, bool isVerified})> verifyOTP(
      String verificationId, String otp);
  Future<void> signOut();
  User? get currentUser;
  int? get lastResendToken;
}

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int? _resendToken;

  @override
  int? get lastResendToken => _resendToken;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<String> verifyPhoneNumber(
      String phoneNumber, {
        int? resendToken,
      }) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        if (!completer.isCompleted) completer.complete('');
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(
              Exception(e.message ?? 'Verification failed'));
        }
      },
      codeSent: (String verificationId, int? token) {
        _resendToken = token;
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );

    return completer.future;
  }

  @override
  Future<({User user, bool isRegisteredAgent, bool isVerified})> verifyOTP(
      String verificationId, String otp) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    final result = await _auth.signInWithCredential(credential);
    final user = result.user!;

    // Check if this user has already registered as a delivery agent
    final agentDoc =
    await _db.collection('deliveryAgents').doc(user.uid).get();
    final isRegisteredAgent = agentDoc.exists;
    final isVerified = agentDoc.data()?['isVerified'] == true;

    // Create stub user doc if first time
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      await _db.collection('users').doc(user.uid).set({
        'phoneNumber': user.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeliveryAgent': false,
      });
    }

    return (user: user, isRegisteredAgent: isRegisteredAgent, isVerified: isVerified);
  }

  @override
  Future<void> signOut() async => _auth.signOut();
}
