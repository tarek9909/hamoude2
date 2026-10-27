import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront_template/screens/policies_webview_screen.dart';
import 'package:storefront_template/widgets/top_toast.dart';

void main() {
  group('userFacingError', () {
    test('keeps short user-facing messages', () {
      expect(
        userFacingError(Exception('Current password is incorrect.')),
        'Current password is incorrect.',
      );
      expect(
        userFacingError(ArgumentError('Choose an image smaller than 5 MB.')),
        'Choose an image smaller than 5 MB.',
      );
      expect(
        userFacingError(StateError('Your bag is empty.')),
        'Your bag is empty.',
      );
    });

    test('hides raw server bodies behind the fallback', () {
      const fallback = 'Try again.';
      expect(
        userFacingError(Exception('{"success":false,"error":"boom"}'),
            fallback: fallback),
        fallback,
      );
      expect(
        userFacingError(Exception('<!DOCTYPE html><html>502</html>'),
            fallback: fallback),
        fallback,
      );
      expect(userFacingError('x' * 400, fallback: fallback), fallback);
      expect(userFacingError(null, fallback: fallback), fallback);
    });

    test('maps timeouts to a connection message', () {
      expect(
        userFacingError(TimeoutException('slow')),
        contains('timed out'),
      );
    });
  });

  group('safeExternalUri', () {
    test('accepts https links', () {
      expect(
        safeExternalUri('https://dashboard.zeyy.app/legal/terms')?.host,
        'dashboard.zeyy.app',
      );
    });

    test('rejects non-https and malformed links', () {
      expect(safeExternalUri('http://example.com/page'), isNull);
      expect(safeExternalUri('javascript:alert(1)'), isNull);
      expect(safeExternalUri('file:///etc/passwd'), isNull);
      expect(safeExternalUri('intent://scan#Intent;end'), isNull);
      expect(safeExternalUri(''), isNull);
      expect(safeExternalUri(null), isNull);
    });

    test('allows http only for local hosts in debug builds', () {
      expect(
        safeExternalUri('http://10.0.2.2:3000/policy') != null,
        kDebugMode,
      );
    });
  });

  testWidgets('PoliciesWebViewScreen shows an error for an unsafe link',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PoliciesWebViewScreen(
          url: 'http://example.com/policy',
          title: 'Terms',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TERMS'), findsOneWidget);
    expect(find.text('This link cannot be opened securely.'), findsWidgets);

    // Let the toast's auto-dismiss timer finish.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
