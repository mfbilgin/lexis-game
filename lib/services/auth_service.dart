import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

/// Firebase Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final firestoreService = ref.read(firestoreServiceProvider);
  return AuthService(firestoreService);
});

/// Current user stream provider
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Current user provider (nullable)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Authentication service for Firebase
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService;

  AuthService(this._firestoreService);

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // User cancelled
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _firestoreService.createOrUpdateUser(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Delete account
  Future<bool> deleteAccount() async {
    try {
      final uid = currentUser?.uid;
      if (uid != null) {
        // Delete user's document
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        
        // Delete user's game scores
        final scores = await FirebaseFirestore.instance.collection('game_scores').where('uid', isEqualTo: uid).get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in scores.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      
      await currentUser?.delete();
      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  /// Update display name (Firebase Auth profile)
  /// Firestore display name is updated separately via FirestoreService
  Future<void> updateDisplayName(String displayName) async {
    try {
      await currentUser?.updateDisplayName(displayName);
    } catch (e) {
      print('Error updating display name: $e');
    }
  }
}
