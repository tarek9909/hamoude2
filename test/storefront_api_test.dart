import 'package:flutter_test/flutter_test.dart';
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
}
