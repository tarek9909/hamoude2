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

  test('parses attributes images and product variants', () {
    final product = Product.fromJson({
      'id': 45,
      'name': 'Tinted Serum',
      'base_price': '30.00',
      'category_name': 'Serums',
      'available_qty': '5',
      'measurement_label': '30ml',
      'attributes': [
        {'code': 'skin_types', 'value_text': 'All'},
        {
          'code': 'volume',
          'label': 'Volume',
          'value_text': '30',
          'unit_label': 'ml'
        },
      ],
      'images': [
        {
          'id': 1,
          'image_url': 'https://example.test/base.jpg',
          'is_primary': 1,
        },
        {
          'id': 2,
          'variant_id': 'shade-rose',
          'image_url': 'https://example.test/rose.jpg',
        },
      ],
      'variants': [
        {
          'id': 'shade-rose',
          'name': 'Rose',
          'variant_display_name': 'Rose / 30ml',
          'price': '32.50',
          'available_qty': '3',
          'is_default': 1,
          'color_hexes': '["#AA3366"]',
          'variant_attributes': [
            {
              'code': 'color',
              'label': 'Color',
              'value_text': 'Rose',
              'options': ['Rose', 'Sand']
            },
            {
              'code': 'size',
              'label': 'Size',
              'value_text': '30ml',
            },
          ],
        },
      ],
    });

    expect(product.measurementLabel, '30ml');
    expect(product.attributes.map((attribute) => attribute.code),
        contains('volume'));
    expect(product.images, hasLength(2));
    expect(product.variants, hasLength(1));
    expect(product.variants.single.id, 'shade-rose');
    expect(product.variants.single.displayName, 'Rose / 30ml');
    expect(product.variants.single.price, 32.5);
    expect(product.variants.single.stockQuantity, 3);
    expect(product.variants.single.isDefault, isTrue);
    expect(product.variants.single.colorHexes, ['#AA3366']);
    expect(product.variants.single.imageUrl, 'https://example.test/rose.jpg');
    expect(product.variants.single.attributeValue('size'), '30ml');
  });
}
