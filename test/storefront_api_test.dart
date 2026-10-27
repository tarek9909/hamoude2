import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storefront_template/models/product.dart';
import 'package:storefront_template/services/storefront_api.dart';

void main() {
  test('resolves backend upload media URLs from storefront API base', () {
    final api = StorefrontApi(
      baseUrl: 'http://192.168.10.210:4000/api/v1/storefront',
      storeSlug: 'skin-cella',
    );

    expect(
      api.resolveMediaUrl('/uploads/marketing/banner.webp'),
      'http://192.168.10.210:4000/uploads/marketing/banner.webp',
    );
    expect(
      api.resolveMediaUrl('uploads/marketing/story.webp'),
      'http://192.168.10.210:4000/uploads/marketing/story.webp',
    );
    expect(
      api.resolveMediaUrl('http://localhost:4000/uploads/marketing/old.webp'),
      'http://192.168.10.210:4000/uploads/marketing/old.webp',
    );
    expect(
      api.resolveMediaUrl('http://127.0.0.1:4000/uploads/marketing/old.webp'),
      'http://192.168.10.210:4000/uploads/marketing/old.webp',
    );
    expect(
      api.resolveMediaUrl('https://cdn.example.test/image.webp'),
      'https://cdn.example.test/image.webp',
    );
  });

  test('cart quote payload includes selected variant id', () async {
    Map<String, dynamic>? capturedBody;
    final api = StorefrontApi(
      baseUrl: 'http://example.test/api/v1/storefront',
      storeSlug: 'skin-cella',
      client: MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'data': {}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    const product = Product(
      id: '101',
      name: 'Barrier Cream',
      description: 'Barrier support cream.',
      shortDescription: 'Barrier support',
      price: 18.0,
      imageUrl: '/uploads/products/barrier.webp',
      category: 'Moisturizers',
      stockQuantity: 2,
      rating: 4.8,
      reviewsCount: 9,
      skinTypes: ['All'],
      ingredients: 'Ceramides',
      volume: '50ml',
      brand: 'Skin Cella',
    );
    const variant = ProductVariant(
      id: 'variant-30ml',
      name: '30ml',
      displayName: '30ml',
      stockQuantity: 2,
    );

    await api.quoteCart(
      branchId: 10,
      items: [CartItem(product: product, variant: variant, quantity: 2)],
    );

    expect(capturedBody?['items'], hasLength(1));
    expect(capturedBody?['items'].single['product_id'], '101');
    expect(capturedBody?['items'].single['variant_id'], 'variant-30ml');
    expect(capturedBody?['items'].single['quantity'], 2);
  });

  test('username registration uses username auth endpoint and payload',
      () async {
    Uri? capturedUrl;
    Map<String, dynamic>? capturedBody;
    final api = StorefrontApi(
      baseUrl: 'http://example.test/api/v1/storefront',
      storeSlug: 'skin-cella',
      client: MockClient((request) async {
        capturedUrl = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'customer_token': 'token-11',
              'customer': {'id': 11},
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final session = await api.registerWithUsernamePassword(
      name: 'Maya Customer',
      username: 'maya.customer',
      password: 'password123',
    );

    expect(capturedUrl?.path,
        '/api/v1/storefront/skin-cella/auth/register-username');
    expect(capturedBody, {
      'full_name': 'Maya Customer',
      'username': 'maya.customer',
      'password': 'password123',
      'policy_acceptance': {
        'terms_accepted': true,
        'privacy_accepted': true,
      },
    });
    expect(session.customerId, 11);
    expect(session.customerToken, 'token-11');
  });

  StorefrontApi capturingApi(
    List<http.Request> captured, {
    int status = 200,
    String? body,
  }) {
    return StorefrontApi(
      baseUrl: 'http://example.test/api/v1/storefront',
      storeSlug: 'skin-cella',
      client: MockClient((request) async {
        captured.add(request);
        return http.Response(
          body ?? jsonEncode({'success': true, 'data': {}}),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  const session = CustomerSession(customerId: 7, customerToken: 'token-7');

  test('PATCH me sends only full_name', () async {
    final captured = <http.Request>[];
    await capturingApi(captured)
        .updateProfile(session: session, name: 'Maya Customer');

    expect(captured.single.method, 'PATCH');
    expect(captured.single.url.path, '/api/v1/storefront/skin-cella/me');
    expect(jsonDecode(captured.single.body), {'full_name': 'Maya Customer'});
    expect(captured.single.headers['x-customer-token'], 'token-7');
  });

  test('change password posts current and new password', () async {
    final captured = <http.Request>[];
    await capturingApi(captured).changePassword(
      session: session,
      currentPassword: 'old-pass',
      newPassword: 'new-pass-123',
    );

    expect(captured.single.method, 'POST');
    expect(captured.single.url.path,
        '/api/v1/storefront/skin-cella/me/change-password');
    expect(jsonDecode(captured.single.body), {
      'current_password': 'old-pass',
      'new_password': 'new-pass-123',
    });
  });

  test('delete account sends the password', () async {
    final captured = <http.Request>[];
    await capturingApi(captured).deleteAccount(session, password: 'secret-1');

    expect(captured.single.method, 'DELETE');
    expect(captured.single.url.path, '/api/v1/storefront/skin-cella/me');
    expect(jsonDecode(captured.single.body), {'password': 'secret-1'});
  });

  test('password reset request sends the username and returns message',
      () async {
    final captured = <http.Request>[];
    final result = await capturingApi(
      captured,
      body: jsonEncode({
        'success': true,
        'message': 'Your reset request was sent. The store will contact you.',
        'data': {'mode': 'admin_review'},
      }),
    ).requestPasswordReset('maya.customer');

    expect(captured.single.url.path,
        '/api/v1/storefront/skin-cella/auth/password-reset-request');
    expect(jsonDecode(captured.single.body), {'username': 'maya.customer'});
    expect(result['mode'], 'admin_review');
    expect(result['message'],
        'Your reset request was sent. The store will contact you.');
  });

  test('mark all notifications read posts to read-all', () async {
    final captured = <http.Request>[];
    await capturingApi(captured).markAllNotificationsRead(session);

    expect(captured.single.method, 'POST');
    expect(captured.single.url.path,
        '/api/v1/storefront/skin-cella/notifications/read-all');
  });

  test('checkout sends the given idempotency key and notes', () async {
    final captured = <http.Request>[];
    const product = Product(
      id: '101',
      name: 'Barrier Cream',
      description: '',
      shortDescription: '',
      price: 18.0,
      imageUrl: '',
      category: 'Moisturizers',
      stockQuantity: 2,
      skinTypes: ['All'],
      ingredients: '',
      brand: 'Skin Cella',
    );
    await capturingApi(captured).checkout(
      branchId: 10,
      items: [CartItem(product: product)],
      orderType: 'pickup',
      notes: 'Leave at door',
      idempotencyKey: 'skin-cella-key-1',
    );

    final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
    expect(body['idempotency_key'], 'skin-cella-key-1');
    expect(body['notes'], 'Leave at door');
  });

  test('non-JSON error pages become StorefrontApiException', () async {
    final api = capturingApi([], status: 502, body: '<html>Bad Gateway</html>');

    await expectLater(
      api.getConfig(),
      throwsA(isA<StorefrontApiException>()
          .having((e) => e.statusCode, 'statusCode', 502)),
    );
  });

  test('401 customer token failures are flagged as expired sessions', () async {
    final api = capturingApi(
      [],
      status: 401,
      body: jsonEncode({
        'success': false,
        'message': 'Invalid or expired customer token',
      }),
    );

    await expectLater(
      api.getProfile(session),
      throwsA(isA<StorefrontApiException>()
          .having((e) => e.isSessionExpired, 'isSessionExpired', isTrue)),
    );
  });

  test('login parses token expiry', () async {
    final api = capturingApi(
      [],
      body: jsonEncode({
        'success': true,
        'data': {
          'customer_token': 'token-9',
          'token_expires_at': '2030-01-01T00:00:00.000Z',
          'customer': {'id': 9},
        },
      }),
    );

    final login = await api.loginWithPassword(username: 'maya', password: 'pw');
    expect(login.customerId, 9);
    expect(login.expiresAt, DateTime.utc(2030));
    expect(login.isExpired, isFalse);
  });

  test('legacy wholesale rows per variant merge into one product', () async {
    final api = capturingApi(
      [],
      body: jsonEncode({
        'success': true,
        'data': [
          {
            'id': 5,
            'variant_id': 51,
            'name': 'Serum',
            'variant_name': '30ml',
            'price': '10.00',
            'available_qty': 2,
          },
          {
            'id': 5,
            'variant_id': 52,
            'name': 'Serum',
            'variant_name': '50ml',
            'price': '14.00',
            'available_qty': 3,
          },
        ],
        'meta': {'total_pages': 1},
      }),
    );

    final products =
        await api.listWholesaleProducts(wholesaleToken: 'wholesale-token');
    expect(products, hasLength(1));
    expect(products.single.variants.map((v) => v.id), ['51', '52']);
    expect(products.single.variants.last.price, 14.0);
  });
}
