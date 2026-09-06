import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_find/M400/screens/auth/about_screen.dart';
import 'package:my_find/M400/screens/auth/login_screen.dart';
import 'package:my_find/M400/services/auth_service.dart';

void main() {
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient(
      'https://project.example.test',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() => client.dispose());
  testWidgets('root login returns to landing even without a previous route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: AuthService(client: client)),
      ),
    );
    expect(find.byTooltip('Back to home'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to home'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
