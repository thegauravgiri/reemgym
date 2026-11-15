import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  const AppUser(this.uid, this.email, {this.name = '', this.photoUrl});
}

/// A sign-in problem with a message that is safe to show to the user.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}

abstract class AuthService {
  /// Emits the current user immediately, then on every sign-in or sign-out.
  Stream<AppUser?> get userChanges;

  /// Returns normally when the user backs out of the Google sheet.
  Future<void> signInWithGoogle();
  Future<void> signOut();
}

/// OAuth "web client" of the main Firebase project; Google sign-in on Android
/// needs it to issue an ID token that Firebase accepts.
const _serverClientId =
    '138160043852-v4th24n3bq3iqjr7fkaopqmdm24havum.apps.googleusercontent.com';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<void>? _ready;

  Future<void> _init() => _ready ??= GoogleSignIn.instance.initialize(
    serverClientId: _serverClientId,
  );

  @override
  Stream<AppUser?> get userChanges => _auth.authStateChanges().map(
    (u) => u == null
        ? null
        : AppUser(
            u.uid,
            u.email ?? '',
            name: u.displayName ?? '',
            photoUrl: u.photoURL,
          ),
  );

  @override
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
        return;
      }
      await _init();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure('Google did not return a sign-in token.');
      }
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      debugPrint('Google sign-in failed: ${e.code} ${e.description}');
      throw AuthFailure(switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not set up for this build of the app.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google sign-in could not be shown on this device.',
        _ =>
          'Google sign-in failed. Check your internet connection and that '
              'a Google account is added on this device.',
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }
      throw AuthFailure(switch (e.code) {
        'network-request-failed' =>
          'No internet connection. Check your network and try again.',
        'user-disabled' => 'This account has been disabled.',
        'operation-not-allowed' =>
          'Google sign-in is not enabled for this app yet.',
        _ => e.message ?? 'Sign-in failed. Please try again.',
      });
    }
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _init();
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('Google sign-out failed: $e');
      }
    }
    await _auth.signOut();
  }
}

/// Preview-mode auth: signs in a stand-in user, forgets on restart.
class MemoryAuthService implements AuthService {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  Stream<AppUser?> get userChanges async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    _user = const AppUser('preview-user', 'preview@example.com', name: 'Reem');
    _controller.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }
}
