import 'package:firebase_auth/firebase_auth.dart';

class AdminAuthService {
  final FirebaseAuth _auth;
  final Set<String> _adminEmails;

  AdminAuthService({FirebaseAuth? auth, Set<String> adminEmails = const {}})
    : _auth = auth ?? FirebaseAuth.instance,
      _adminEmails = adminEmails;

  User? get currentUser => _auth.currentUser;

  bool get isSignedInAdmin {
    final email = currentUser?.email?.toLowerCase().trim();
    return email != null && _adminEmails.contains(email);
  }

  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) return false;

    final token = await user.getIdTokenResult(forceRefresh);
    final hasAdminClaim = token.claims?['admin'] == true;
    if (hasAdminClaim) return true;

    final email = user.email?.toLowerCase().trim();
    return email != null && _adminEmails.contains(email);
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
