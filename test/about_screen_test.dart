import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_find/M400/screens/auth/about_screen.dart';

void main() {
  for (final width in [320.0, 390.0, 800.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('Welcome screen fits width $width at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previewKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: previewKey,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const AboutScreen(),
            ),
          ),
        );

        if (const bool.fromEnvironment('CAPTURE_ABOUT_PREVIEW') &&
            width == 390 &&
            scale == 1) {
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                previewKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final preview = await boundary.toImage();
            final data = await preview.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/about_screen_preview.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            preview.dispose();
          });
        }

        expect(find.text('Log in'), findsOneWidget);
        expect(find.text('Your next chapter\nin Malaysia.'), findsOneWidget);
        expect(find.text('VISITING MALAYSIA'), findsOneWidget);
        expect(find.text('CALLING MALAYSIA HOME'), findsOneWidget);
        expect(find.textContaining('modules'), findsNothing);
        expect(find.textContaining('Collaborative Development'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.text('Your MyFind starts here.'),
          400,
          scrollable: find.byType(Scrollable),
          maxScrolls: 30,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Your MyFind starts here.'), findsOneWidget);
      });
    }
  }
}
