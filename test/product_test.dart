import 'package:flutter_test/flutter_test.dart';
import 'package:storefront_template/models/product.dart';

void main() {
  test('maps storefront product payloads into universal product fields', () {
    final product = Product.fromJson({
      'id': 44,
      'name': 'Barrier Serum',
      'short_description': 'Short fallback description',
      'base_price': '42.50',
      'image_url': 'https://example.test/serum.jpg',
      'category_name': 'Serums',
      'available_qty': '9.000',
      'attributes': [
        {'code': 'volume', 'value_text': '30ml'},
        {'code': 'skin_types', 'value_text': 'Sensitive,Dry'},
        {'code': 'ingredients', 'value_text': 'Peptides, Squalane'},
      ],
    });

    expect(product.id, '44');
    expect(product.description, 'Short fallback description');
    expect(product.price, 42.5);
    expect(product.imageUrl, 'https://example.test/serum.jpg');
    expect(product.category, 'Serums');
    expect(product.stockQuantity, 9);
    expect(product.volume, '30ml');
    expect(product.skinTypes, ['Sensitive', 'Dry']);
    expect(product.ingredients, 'Peptides, Squalane');
  });
}
