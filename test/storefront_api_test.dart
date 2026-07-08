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
}
