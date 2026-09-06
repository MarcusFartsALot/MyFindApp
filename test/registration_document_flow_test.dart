import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_find/M400/screens/auth/register_screen.dart';
import 'package:my_find/M400/services/document_ocr_service.dart';
import 'package:my_find/M400/services/registration_service.dart';
import 'package:my_find/M400/widgets/identity_document_capture.dart';
import 'package:my_find/core/exceptions/app_exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var requests = 0;
  var identityAvailable = true;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://project.example.test',
      publishableKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path ==
            '/rest/v1/rpc/module400_registration_identity_available') {
          return http.Response(
            '$identityAvailable',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        requests++;
        throw StateError('This test must not upload or submit any documents.');
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    requests = 0;
    identityAvailable = true;
  });
  tearDown(() => expect(requests, 0));

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  String value(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Future<void> reveal(WidgetTester tester, Finder target) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> touristForm(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.tap(find.text('Tourist'));
    await tester.pumpAndSettle();
  }

  void scan(WidgetTester tester, String text) {
    tester
        .widget<IdentityDocumentCapture>(
          find.byKey(const ValueKey('tourist_front')),
        )
        .onTextExtracted!(text);
  }

  testWidgets('both MyKad captures request OCR and receive the typed number', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await reveal(tester, field('MyKad number'));
    await tester.enterText(field('MyKad number'), '900101-14-5566');
    await tester.pump();
    final front = tester.widget<IdentityDocumentCapture>(
      find.byKey(const ValueKey('citizen_front')),
    );
    final back = tester.widget<IdentityDocumentCapture>(
      find.byKey(const ValueKey('citizen_back')),
    );
    expect(front.side, IdentityDocumentSide.front);
    expect(back.side, IdentityDocumentSide.back);
    expect(back.expectedIdentityNumber, front.expectedIdentityNumber);
    expect(back.expectedIdentityNumber, '900101-14-5566');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('passport scan fills requested fields without revealing raw text', (
    tester,
  ) async {
    await touristForm(tester);
    await reveal(tester, field('Passport number'));
    await tester.enterText(field('Passport number'), 'C03005988');
    await tester.pump();
    scan(
      tester,
      'PASSPORT NO C03005988\nNAME PRIVATE OCR NAME\n'
      'ISSUING COUNTRY MALAYSIA\nDATE OF ISSUE 02 JAN 2025\nDATE OF EXPIRY 02 JAN 2035',
    );
    await tester.pump();
    expect(value(tester, 'Passport number'), 'C03005988');
    expect(value(tester, 'Full name'), isEmpty);
    expect(value(tester, 'Nationality'), isEmpty);
    expect(value(tester, 'Passport issuing country'), 'MALAYSIA');
    expect(value(tester, 'Passport issue date (optional)'), '2025-01-02');
    expect(value(tester, 'Passport expiry date'), '2035-01-02');
    expect(find.textContaining('PRIVATE OCR NAME'), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retake updates scanned dates, keeps edited country, role change clears data',
    (tester) async {
      await touristForm(tester);
      scan(
        tester,
        'PASSPORT\nISSUING COUNTRY MYS\nDATE OF ISSUE 01/02/2025\nDATE OF EXPIRY 01/02/2030',
      );
      await tester.pump();
      await reveal(tester, field('Passport issuing country'));
      await tester.enterText(field('Passport issuing country'), 'Malaysia');
      scan(tester, 'PASSPORT\nISSUING COUNTRY MYS\nDATE OF EXPIRY 01/03/2031');
      await tester.pump();
      expect(value(tester, 'Passport issuing country'), 'Malaysia');
      expect(value(tester, 'Passport issue date (optional)'), isEmpty);
      expect(value(tester, 'Passport expiry date'), '2031-03-01');
      await reveal(tester, find.text('Citizen'));
      await tester.tap(find.text('Citizen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tourist'));
      await tester.pumpAndSettle();
      expect(value(tester, 'Passport issuing country'), isEmpty);
      expect(value(tester, 'Passport expiry date'), isEmpty);
      expect(value(tester, 'Passport number'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expired scanned date is rejected but can be corrected without picker crash',
    (tester) async {
      await touristForm(tester);
      scan(
        tester,
        'PASSPORT\nDATE OF ISSUE 01/02/2099\nDATE OF EXPIRY 01/02/2012',
      );
      await tester.pump();
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(
        find.text('Enter a valid future passport expiry date'),
        findsOneWidget,
      );
      expect(
        find.text('Passport issue date cannot be in the future'),
        findsOneWidget,
      );
      for (final label in [
        'Passport expiry date',
        'Passport issue date (optional)',
      ]) {
        await reveal(tester, field(label));
        await tester.tap(field(label));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
    },
  );

  for (final backText in [
    null,
    '',
    'MALAYSIA SHOPPING RECEIPT THANK YOU TOTAL 50',
    'KETUA PENGARAH PENDAFTARAN NEGARA\n900101-14-5567',
  ]) {
    test(
      'submission rejects invalid/unverified MyKad back before upload: $backText',
      () async {
        await expectLater(
          RegistrationService().submitApplication(
            fullName: 'Test Applicant',
            email: 'applicant@example.test',
            requestedRole: 'citizen',
            identityNumber: '900101-14-5566',
            phoneNumber: '0123456789',
            nationality: 'Malaysian',
            documentImage: File('test-front.jpg'),
            documentBackImage: File('test-back.jpg'),
            extractedText: 'KAD PENGENALAN MALAYSIA\n900101-14-5566',
            documentBackExtractedText: backText,
          ),
          throwsA(isA<AppException>()),
        );
      },
    );
  }

  for (final role in ['citizen', 'tourist']) {
    test('duplicate $role number stops submission before any upload', () async {
      identityAvailable = false;
      await expectLater(
        RegistrationService().submitApplication(
          fullName: 'Test Applicant',
          email: 'applicant@example.test',
          requestedRole: role,
          identityNumber: role == 'citizen' ? '900101-14-5566' : 'C03005988',
          phoneNumber: '0123456789',
          nationality: 'Malaysian',
          documentImage: File('missing-front.jpg'),
          documentBackImage: role == 'citizen'
              ? File('missing-back.jpg')
              : null,
          extractedText: role == 'citizen'
              ? 'KAD PENGENALAN MALAYSIA\n900101-14-5566'
              : 'MALAYSIA PASSPORT NO C03005988',
          documentBackExtractedText:
              'KETUA PENGARAH PENDAFTARAN NEGARA\n900101-14-5566',
          passportIssuingCountry: 'MYS',
          passportExpiryDate: DateTime(DateTime.now().year + 2),
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'identity_already_registered',
          ),
        ),
      );
    });
  }

  testWidgets('typing an existing IC shows a database duplicate message', (
    tester,
  ) async {
    identityAvailable = false;
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await reveal(tester, field('MyKad number'));
    await tester.enterText(field('MyKad number'), '900101-14-5566');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('This IC number is already registered.'),
      findsOneWidget,
    );
  });
}
