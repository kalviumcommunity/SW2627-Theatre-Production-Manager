import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/auth/screens/login_screen.dart';
import 'package:client/features/auth/screens/register_screen.dart';

void main() {
  Widget buildApp(Widget home) {
    return MaterialApp(
      home: home,
    );
  }

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

    testWidgets('shows feedback SnackBar when form is valid', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(const LoginScreen()));

      final emailField = find.widgetWithText(TextFormField, 'Email Address');
      final passwordField = find.widgetWithText(TextFormField, 'Password');

      await tester.enterText(emailField, 'user@example.com');
      await tester.enterText(passwordField, 'password123');

      final loginButton = find.widgetWithText(FilledButton, 'Login');
      await tester.tap(loginButton);
      await tester.pump();

      expect(find.text('Authentication will be connected soon.'), findsOneWidget);
    });

    testWidgets('navigates to RegisterScreen when Register is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp(const LoginScreen()));

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });

  group('RegisterScreen Tests', () {
    testWidgets('shows validation errors on empty submission', (WidgetTester tester) async {
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
      expect(find.text('Please select a role'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
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

    testWidgets('selects role and shows SnackBar when valid', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(const RegisterScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Jane Doe');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'jane@theatre.org');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'secret123');

      // Select role from dropdown
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cast Member').last);
      await tester.pumpAndSettle();

      final createButton = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('Account creation will be connected soon.'), findsOneWidget);
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
}
