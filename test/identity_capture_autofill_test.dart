import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_find/M400/services/document_ocr_service.dart';
import 'package:my_find/M400/widgets/identity_document_capture.dart';

class _Picker extends Fake implements ImagePicker {
  _Picker(this.path);
  final String path;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #pickImage) {
      return Future<XFile?>.value(XFile(path));
    }
    return super.noSuchMethod(invocation);
  }
}

class _Ocr extends DocumentOcrService {
  _Ocr(this.text);
  final String text;
  @override
  Future<String> extractAndValidate({
    required File image,
    required String requestedRole,
    IdentityDocumentSide side = IdentityDocumentSide.front,
  }) async {
    DocumentOcrService.validateDocumentText(
      text: text,
      requestedRole: requestedRole,
      side: side,
    );
    return text;
  }
}

void main() {
  late Directory temp;
  late File photo;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('m400-capture-test-');
    photo = await File('${temp.path}/sample.png').writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      ),
    );
  });
  tearDownAll(() async {
    await photo.delete();
    await temp.delete();
  });

  for (final initialNumber in ['', 'WRONG123']) {
    testWidgets(
      'passport autofills with "$initialNumber" but is not accepted until number matches',
      (tester) async {
        var number = initialNumber;
        final scanned = <String?>[];
        RecognizedDocument? accepted;
        const text =
            'PASSPORT NO C03005988\nDATE OF ISSUE 02 JAN 2025\nDATE OF EXPIRY 02 JAN 2030\nCOUNTRY CODE MYS';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, update) => Column(
                    children: [
                      TextField(
                        onChanged: (value) => update(() => number = value),
                      ),
                      IdentityDocumentCapture(
                        requestedRole: 'tourist',
                        expectedIdentityNumber: number,
                        imagePicker: _Picker(photo.path),
                        ocrService: _Ocr(text),
                        onTextExtracted: scanned.add,
                        onDocumentChanged: (document) => accepted = document,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Capture Passport'));
        await tester.pumpAndSettle();
        expect(scanned.last, text);
        expect(accepted, isNull);
        expect(find.text(text), findsNothing);
        await tester.enterText(find.byType(TextField), 'C03005988');
        await tester.pumpAndSettle();
        expect(accepted?.extractedText, text);
        expect(
          find.text('Document number verified successfully.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        // Evict the test image before its fixture is deleted.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'non-passport image never supplies autofill or a valid document',
    (tester) async {
      final scanned = <String?>[];
      RecognizedDocument? accepted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentityDocumentCapture(
              requestedRole: 'tourist',
              imagePicker: _Picker(photo.path),
              ocrService: _Ocr(
                'SHOPPING RECEIPT TOTAL 50 THANK YOU VISIT AGAIN',
              ),
              onTextExtracted: scanned.add,
              onDocumentChanged: (document) => accepted = document,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Capture Passport'));
      await tester.pumpAndSettle();
      expect(scanned.whereType<String>(), isEmpty);
      expect(accepted, isNull);
      expect(
        find.textContaining('does not appear to be a passport'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
