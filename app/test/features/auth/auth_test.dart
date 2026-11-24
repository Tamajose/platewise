import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/app/app.dart';
import 'package:platewise/core/data/core_providers.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/auth/data/account_providers.dart';
import 'package:platewise/features/auth/data/account_repositories.dart';
import 'package:platewise/features/auth/data/auth_backend.dart';
import 'package:platewise/features/auth/domain/account_info.dart';
import 'package:platewise/features/auth/domain/account_repository.dart';
import 'package:platewise/features/auth/domain/account_rules.dart';
import 'package:platewise/features/onboarding/data/onboarding_providers.dart';
import 'package:platewise/features/onboarding/data/onboarding_repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:timezone/data/latest_all.dart' as timezone;

import '../meal_logging/fakes.dart';

class FakeBackend implements AuthBackend {
  BackendUser current = (
    anonymous: true,
    email: null,
    emailConfirmed: false,
    pendingEmail: null,
  );
  Object? error;
  final calls = <String>[];

  @override
  Future<BackendUser> user() async {
    if (error != null) throw error!;
    return current;
  }

  @override
  Future<void> setEmail(String email) async {
    calls.add('email:$email');
    if (error != null) throw error!;
  }

  @override
  Future<void> setPassword(String password) async {
    calls.add('password');
    if (error != null) throw error!;
  }

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signin:$email');
    if (error != null) throw error!;
  }

  @override
  Future<void> signOut() async => calls.add('signout');
}

class FakeAccounts implements AccountRepository {
  AccountInfo info = (
    guest: true,
    email: null,
    emailConfirmed: false,
    pendingEmail: null,
  );
  final calls = <String>[];
  Object? error;

  @override
  Future<AccountInfo> account() async => info;
  @override
  Future<void> linkEmail(String email) async {
    calls.add('link:$email');
    if (error != null) throw error!;
  }

  @override
  Future<void> setPassword(String password) async {
    calls.add('password');
    if (error != null) throw error!;
  }

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signin:$email');
    if (error != null) throw error!;
  }

  @override
  Future<void> signOut() async => calls.add('signout');
}

void main() {
  setUpAll(timezone.initializeTimeZones);

  group('rules', () {
    test('emails', () {
      expect(isValidEmail(' a@b.co '), isTrue);
      for (final bad in ['', 'a', 'a@b', 'a b@c.d', '@b.co']) {
        expect(isValidEmail(bad), isFalse, reason: bad);
      }
    });

    test('the app starts again only when the person changes', () {
      expect(resetsOnUserChange(null, 'a'), isFalse); // the first guest session
      expect(resetsOnUserChange('a', 'a'), isFalse);
      expect(resetsOnUserChange('a', 'b'), isTrue); // signed in elsewhere
      expect(resetsOnUserChange('a', null), isTrue); // signed out
      expect(resetsOnUserChange(null, null), isFalse);
    });
  });

  group('live repository', () {
    late FakeBackend backend;
    late LiveAccountRepository repo;
    setUp(() {
      backend = FakeBackend();
      repo = LiveAccountRepository(backend);
    });

    test('describes a guest and a verified account', () async {
      expect((await repo.account()).guest, isTrue);
      backend.current = (
        anonymous: false,
        email: 'a@b.co',
        emailConfirmed: true,
        pendingEmail: null,
      );
      final info = await repo.account();
      expect(
        (info.guest, info.email, info.emailConfirmed),
        (false, 'a@b.co', true),
      );
    });

    test('a password needs a verified email first', () async {
      await expectLater(
        repo.setPassword('long enough password'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Verify your email first.',
          ),
        ),
      );
      expect(backend.calls, isEmpty);
      backend.current = (
        anonymous: true,
        email: 'a@b.co',
        emailConfirmed: true,
        pendingEmail: null,
      );
      await repo.setPassword('long enough password');
      expect(backend.calls, ['password']);
    });

    test('service errors become clear messages', () {
      Failure of(String code) => authFailure(AuthException('x', code: code));
      expect(of('email_exists').code, 'ACCOUNT_EXISTS');
      expect(of('invalid_credentials').message, contains('did not match'));
      expect(of('email_not_confirmed').message, contains('Verify your email'));
      expect(of('weak_password').message, contains('stronger password'));
      expect(of('over_request_rate_limit').retryable, isTrue);
      expect(of('anything_else').retryable, isTrue);
      expect(
        authFailure(StateError('secret')).message,
        isNot(contains('secret')),
      );
      const own = Failure('mine');
      expect(authFailure(own), same(own));
    });

    test('a failing call surfaces as a failure', () async {
      backend.error = AuthException('x', code: 'invalid_credentials');
      await expectLater(repo.signIn('a@b.co', 'pw'), throwsA(isA<Failure>()));
    });

    test('demo mode has no accounts', () async {
      const demo = DemoAccountRepository();
      expect((await demo.account()).guest, isTrue);
      await expectLater(demo.linkEmail('a@b.co'), throwsA(isA<Failure>()));
      await expectLater(demo.signIn('a@b.co', 'x'), throwsA(isA<Failure>()));
      await demo.signOut();
    });
  });

  group('screen', () {
    Future<(FakeAccounts, StreamController<String?>)> open(
      WidgetTester tester, {
      bool demo = false,
      String path = '/account',
    }) async {
      tester.view.physicalSize = const Size(700, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final accounts = FakeAccounts();
      final users = StreamController<String?>();
      addTearDown(users.close);
      final rig = Rig(
        demo: demo,
        overview: const Overview(
          profile: Profile(height: 170, weight: 70, target: 2000),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            accountRepositoryProvider.overrideWithValue(accounts),
            userChangesProvider.overrideWith((ref) => users.stream),
            onboardingRepositoryProvider.overrideWithValue(
              const LiveOnboardingRepository(),
            ),
          ],
          child: const PlateWiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(
        demo
            ? find.text('Settings and privacy')
            : find.byIcon(Icons.manage_accounts_outlined),
      );
      await tester.pumpAndSettle();
      return (accounts, users);
    }

    testWidgets('a guest can link an email', (tester) async {
      final (accounts, _) = await open(tester);
      expect(find.text('Keep your guest log'), findsOneWidget);
      await tester.tap(find.text('Link my email'));
      await tester.pumpAndSettle();
      expect(find.text(emailMessage), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Email address'),
        'me@example.com',
      );
      await tester.tap(find.text('Link my email'));
      await tester.pumpAndSettle();
      expect(accounts.calls, ['link:me@example.com']);
      expect(find.textContaining('Email link requested'), findsOneWidget);
    });

    testWidgets(
      'a verified email can get a password of at least ten characters',
      (tester) async {
        final (accounts, _) = await open(tester);
        accounts.info = (
          guest: true,
          email: 'me@example.com',
          emailConfirmed: true,
          pendingEmail: null,
        );
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.manage_accounts_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'short',
        );
        await tester.tap(find.text('Set account password'));
        await tester.pumpAndSettle();
        expect(find.text(passwordLengthMessage), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'a long enough one',
        );
        await tester.tap(find.text('Set account password'));
        await tester.pumpAndSettle();
        expect(accounts.calls, ['password']);
        expect(find.textContaining('Password saved'), findsOneWidget);
        expect(find.text('Set account password'), findsNothing);
      },
    );

    testWidgets('a pending verification can be rechecked', (tester) async {
      final (accounts, _) = await open(tester);
      accounts.info = (
        guest: true,
        email: null,
        emailConfirmed: false,
        pendingEmail: 'me@example.com',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.manage_accounts_outlined));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Verification is pending for me@example.com'),
        findsOneWidget,
      );
      expect(find.text('Resend verification'), findsOneWidget);
    });

    testWidgets('signing in warns that the guest log stays behind', (
      tester,
    ) async {
      final (accounts, _) = await open(tester);
      await tester.tap(find.text('Sign in to an existing account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text(signInInputMessage), findsNothing);
      expect(find.text('Open another account?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(accounts.calls, isEmpty);
    });

    testWidgets('a failed sign in shows why', (tester) async {
      final (accounts, _) = await open(tester);
      accounts.error = const Failure('The email or password did not match.');
      await tester.tap(find.text('Sign in to an existing account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Email address'),
        'me@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'wrong',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open existing account'));
      await tester.pumpAndSettle();
      expect(find.text('The email or password did not match.'), findsOneWidget);
    });

    testWidgets('the profile page shows the details and signs out', (
      tester,
    ) async {
      final (accounts, _) = await open(tester);
      accounts.info = (
        guest: false,
        email: 'me@example.com',
        emailConfirmed: true,
        pendingEmail: null,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('2,000 kcal'), findsOneWidget);
      expect(find.text('170 cm'), findsOneWidget);
      expect(find.text('70.0 kg'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(accounts.calls, ['signout']);
    });

    testWidgets('a guest is warned before signing out', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot be reopened'), findsOneWidget);
    });

    testWidgets('a signed-in account can sign out', (tester) async {
      final (accounts, _) = await open(tester);
      accounts.info = (
        guest: false,
        email: 'me@example.com',
        emailConfirmed: true,
        pendingEmail: null,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.manage_accounts_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Your account'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(accounts.calls, ['signout']);
    });

    testWidgets(
      'a different person signing in sends the app back to the start',
      (tester) async {
        final (_, users) = await open(tester);
        users.add('person-a');
        await tester.pumpAndSettle();
        expect(find.text('Your account'), findsNothing);
        expect(find.text('Keep your guest log'), findsOneWidget);
        users.add('person-b');
        await tester.pumpAndSettle();
        expect(find.text('Keep your guest log'), findsNothing);
        expect(find.text('Today'), findsWidgets);
      },
    );
  });
}
