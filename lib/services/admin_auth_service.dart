import 'package:firebase_auth/firebase_auth.dart';

class AdminAuthService {
  final FirebaseAuth _auth;

  AdminAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) return false;

    final token = await user.getIdTokenResult(forceRefresh);
    return token.claims?['admin'] == true;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (!await isCurrentUserAdmin(forceRefresh: true)) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message: 'This account is not allowed to access the admin dashboard.',
      );
    }

    return credential;
  }

  Future<void> signOut() {
    return _auth.signOut();
  }
}
