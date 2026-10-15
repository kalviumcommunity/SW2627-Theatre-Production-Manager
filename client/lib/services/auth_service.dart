import 'package:firebase_auth/firebase_auth.dart';
import 'package:client/services/user_service.dart';

class AuthService {
  final FirebaseAuth? _firebaseAuth;
  final UserService? _userService;

  AuthService({this._firebaseAuth, this._userService});

  FirebaseAuth get firebaseAuth => _firebaseAuth ?? FirebaseAuth.instance;
  UserService get userService => _userService ?? UserService();

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  /// Gets the currently authenticated Firebase user.
  User? get currentUser => firebaseAuth.currentUser;

  /// Registers a new user with email and password and creates a profile in Firestore.
  ///
  /// Public registration always assigns the 'Cast Member' role.
  /// Any [role] argument supplied by a caller is ignored to prevent privilege escalation.
  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
    String? role,
  }) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await userService.createUserProfile(
        uid: user.uid,
        name: name,
        email: email,
        // Public registration never grants elevated privileges.
        role: 'Cast Member',
      );
    }

    return credential;
  }

  /// Signs in an existing user with email and password.
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> logout() async {
    await firebaseAuth.signOut();
  }

  /// Converts Firebase Authentication error codes to user-friendly messages.
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'invalid-credential':
        case 'wrong-password':
          return 'Invalid email or password.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
