import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:client/features/auth/screens/login_screen.dart';
import 'package:client/features/auth/screens/register_screen.dart';
import 'package:client/features/auditions/screens/auditions_screen.dart';
import 'package:client/features/dashboard/screens/dashboard_screen.dart';
import 'package:client/features/productions/screens/productions_screen.dart';
import 'package:client/features/productions/services/production_service.dart';
import 'package:client/features/productions/models/production_model.dart';
import 'package:client/services/auth_service.dart';
import 'package:client/services/user_service.dart';

class _FakeProductionService extends ProductionService {
  final List<Production> productions;
  _FakeProductionService({this.productions = const []});

  @override
  Stream<List<Production>> streamProductions() => Stream.value(productions);

  @override
  Future<List<Production>> getProductions() async => productions;
}

class FakeAuthService extends AuthService {
  bool loginCalled = false;
  bool registerCalled = false;
  bool logoutCalled = false;
  bool shouldThrowError = false;
  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastRegisterEmail;
  String? lastRegisterPassword;
  String? lastRegisterName;
  String? lastRegisterRole;

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    loginCalled = true;
    lastLoginEmail = email;
    lastLoginPassword = password;
    if (shouldThrowError) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Invalid email or password.',
      );
    }
    return _FakeUserCredential();
  }

  @override
  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
    String? role,
  }) async {
    registerCalled = true;
    lastRegisterName = name;
    lastRegisterEmail = email;
    lastRegisterPassword = password;
    lastRegisterRole = 'Cast Member';
    if (shouldThrowError) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'An account already exists with this email.',
      );
    }
    return _FakeUserCredential();
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

class _FakeUserCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuthForRegister extends Fake implements FirebaseAuth {
  final User? _user;
  _FakeFirebaseAuthForRegister(this._user);

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _FakeUserCredentialForRegister(_user);
  }
}

class _FakeUserForRegister extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;

  _FakeUserForRegister({required this.uid, this.email});
}

class _FakeUserCredentialForRegister extends Fake implements UserCredential {
  @override
  final User? user;
  _FakeUserCredentialForRegister(this.user);
}

class _TrackingUserService extends UserService {
  Map<String, dynamic>? lastCreatedProfile;

  @override
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String role,
  }) async {
    lastCreatedProfile = {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
    };
  }
}

void main() {
  Widget buildApp(Widget home) {
    return MaterialApp(
      home: home,
    );
  }

  group('AuthService Tests', () {
    test('converts error codes to friendly messages', () {
      expect(
        AuthService.getErrorMessage(FirebaseAuthException(code: 'invalid-email')),
        'Please enter a valid email address.',
      );
      expect(
        AuthService.getErrorMessage(FirebaseAuthException(code: 'invalid-credential')),
        'Invalid email or password.',
      );
      expect(
        AuthService.getErrorMessage(FirebaseAuthException(code: 'wrong-password')),
        'Invalid email or password.',
      );
      expect(
        AuthService.getErrorMessage(FirebaseAuthException(code: 'user-not-found')),
        'No account found with this email.',
      );
      expect(
        AuthService.getErrorMessage(FirebaseAuthException(code: 'email-already-in-use')),
        'An account already exists with this email.',
      );
      expect(
        AuthService.getErrorMessage(FirebaseAuthException(code: 'weak-password')),
        'Password is too weak. Use at least 6 characters.',
      );
      expect(
        AuthService.getErrorMessage(FirebaseAuthException(code: 'network-request-failed')),
        'Network error. Please check your internet connection.',
      );
      expect(
        AuthService.getErrorMessage(Exception('unknown')),
        'Something went wrong. Please try again.',
      );
    });

    test('register creates a Cast Member profile in Firestore', () async {
      final fakeUser = _FakeUserForRegister(uid: 'user-actor-1', email: 'actor@theatre.org');
      final fakeAuth = _FakeFirebaseAuthForRegister(fakeUser);
      final fakeUserService = _TrackingUserService();
      final authService = AuthService(
        firebaseAuth: fakeAuth,
        userService: fakeUserService,
      );

      await authService.register(
        name: 'Jane Actor',
        email: 'actor@theatre.org',
        password: 'password123',
      );

      expect(fakeUserService.lastCreatedProfile, isNotNull);
      expect(fakeUserService.lastCreatedProfile!['uid'], 'user-actor-1');
      expect(fakeUserService.lastCreatedProfile!['name'], 'Jane Actor');
      expect(fakeUserService.lastCreatedProfile!['email'], 'actor@theatre.org');
      expect(fakeUserService.lastCreatedProfile!['role'], 'Cast Member');
    });

    test('register ignores caller-supplied role and prevents obtaining Director role', () async {
      final fakeUser = _FakeUserForRegister(uid: 'user-attacker-1', email: 'attacker@theatre.org');
      final fakeAuth = _FakeFirebaseAuthForRegister(fakeUser);
      final fakeUserService = _TrackingUserService();
      final authService = AuthService(
        firebaseAuth: fakeAuth,
        userService: fakeUserService,
      );

      // Caller attempts to supply the privileged 'Director' role
      await authService.register(
        name: 'Malicious User',
        email: 'attacker@theatre.org',
        password: 'password123',
        role: 'Director',
      );

      expect(fakeUserService.lastCreatedProfile, isNotNull);
      expect(fakeUserService.lastCreatedProfile!['role'], 'Cast Member');
      expect(fakeUserService.lastCreatedProfile!['role'], isNot('Director'));
    });
  });

  group('LoginScreen Tests', () {
    testWidgets('shows validation errors when submitted empty', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(const LoginScreen()));

      final loginButton = find.widgetWithText(FilledButton, 'Login');
      await tester.tap(loginButton);
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('validates invalid email and short password', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(const LoginScreen()));

      final emailField = find.widgetWithText(TextFormField, 'Email Address');
      final passwordField = find.widgetWithText(TextFormField, 'Password');

      await tester.enterText(emailField, 'invalidemail');
      await tester.enterText(passwordField, '12345');

      final loginButton = find.widgetWithText(FilledButton, 'Login');
      await tester.tap(loginButton);
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('calls login and navigates to DashboardScreen when form is valid', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();
      await tester.pumpWidget(buildApp(LoginScreen(authService: fakeAuth)));

      final emailField = find.widgetWithText(TextFormField, 'Email Address');
      final passwordField = find.widgetWithText(TextFormField, 'Password');

      await tester.enterText(emailField, 'user@example.com');
      await tester.enterText(passwordField, 'password123');

      final loginButton = find.widgetWithText(FilledButton, 'Login');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(fakeAuth.loginCalled, isTrue);
      expect(fakeAuth.lastLoginEmail, 'user@example.com');
      expect(fakeAuth.lastLoginPassword, 'password123');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('shows friendly error SnackBar on login failure', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()..shouldThrowError = true;
      await tester.pumpWidget(buildApp(LoginScreen(authService: fakeAuth)));

      final emailField = find.widgetWithText(TextFormField, 'Email Address');
      final passwordField = find.widgetWithText(TextFormField, 'Password');

      await tester.enterText(emailField, 'user@example.com');
      await tester.enterText(passwordField, 'password123');

      final loginButton = find.widgetWithText(FilledButton, 'Login');
      await tester.tap(loginButton);
      await tester.pump();

      expect(find.text('Invalid email or password.'), findsOneWidget);
    });

    testWidgets('navigates to RegisterScreen when Register is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(const LoginScreen()));

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });

  group('RegisterScreen Tests', () {
    testWidgets('shows validation errors on empty submission without role prompt', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(const RegisterScreen()));

      final createButton = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
      expect(find.text('Please select a role'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('verifies form has all required fields and no role selection dropdown', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(const RegisterScreen()));

      expect(find.widgetWithText(TextFormField, 'Full Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email Address'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create Account'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Login'), findsOneWidget);

      // Verify no role dropdown or role selection UI exists
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Role'), findsNothing);
      expect(find.text('Select your role'), findsNothing);
    });

    testWidgets('validates password mismatch', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(const RegisterScreen()));

      final nameField = find.widgetWithText(TextFormField, 'Full Name');
      final emailField = find.widgetWithText(TextFormField, 'Email Address');
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      final confirmPasswordField = find.widgetWithText(TextFormField, 'Confirm Password');

      await tester.enterText(nameField, 'Jane Doe');
      await tester.enterText(emailField, 'jane@theatre.org');
      await tester.enterText(passwordField, 'secret123');
      await tester.enterText(confirmPasswordField, 'different123');

      final createButton = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('registers user without role selection and navigates to DashboardScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAuthService();
      await tester.pumpWidget(buildApp(RegisterScreen(authService: fakeAuth)));

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Jane Doe');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'jane@theatre.org');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'secret123');

      final createButton = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(fakeAuth.registerCalled, isTrue);
      expect(fakeAuth.lastRegisterName, 'Jane Doe');
      expect(fakeAuth.lastRegisterEmail, 'jane@theatre.org');
      expect(fakeAuth.lastRegisterRole, 'Cast Member');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('shows friendly error SnackBar on registration failure', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAuthService()..shouldThrowError = true;
      await tester.pumpWidget(buildApp(RegisterScreen(authService: fakeAuth)));

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Jane Doe');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'jane@theatre.org');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'secret123');

      final createButton = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('An account already exists with this email.'), findsOneWidget);
    });

    testWidgets('navigates back to Login on tapping Login link', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(const LoginScreen()));

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);

      final loginLink = find.widgetWithText(TextButton, 'Login');
      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('DashboardScreen Tests', () {
    testWidgets('shows welcome message and user details', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();
      await tester.pumpWidget(buildApp(DashboardScreen(authService: fakeAuth)));

      expect(find.text('Theatre Production Manager'), findsOneWidget);
      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('You are logged in.'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('displays overview summary cards with neutral placeholders', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();
      await tester.pumpWidget(buildApp(DashboardScreen(authService: fakeAuth)));

      expect(find.text('Total Productions'), findsOneWidget);
      expect(find.text('Upcoming Rehearsals'), findsWidgets);
      expect(find.text('Auditions'), findsOneWidget);
      expect(find.text('Venues'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(4));
    });

    testWidgets('shows friendly empty state for upcoming rehearsals', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();
      await tester.pumpWidget(buildApp(DashboardScreen(authService: fakeAuth)));

      expect(find.text('No Upcoming Rehearsals'), findsOneWidget);
    });

    testWidgets('navigates to Auditions module when Auditions is tapped', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();
      await tester.pumpWidget(buildApp(DashboardScreen(authService: fakeAuth)));

      // Tap on Auditions metric card
      await tester.tap(find.text('Auditions'));
      await tester.pumpAndSettle();

      expect(find.byType(AuditionsScreen), findsOneWidget);
    });

    testWidgets('navigates to Productions module when Total Productions is tapped', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();
      final fakeProductions = _FakeProductionService(productions: const []);
      await tester.pumpWidget(buildApp(DashboardScreen(
        authService: fakeAuth,
        productionService: fakeProductions,
      )));

      // Tap on Total Productions metric card
      await tester.tap(find.text('Total Productions'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductionsScreen), findsOneWidget);
      expect(find.text('Productions Catalog'), findsOneWidget);
    });

    testWidgets('calls logout and navigates to LoginScreen on logout button tap', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();
      await tester.pumpWidget(buildApp(DashboardScreen(authService: fakeAuth)));

      final logoutButton = find.widgetWithText(FilledButton, 'Logout');
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(fakeAuth.logoutCalled, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
