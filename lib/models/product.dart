class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final int stockQuantity;
  final double rating;
  final int reviewsCount;
  final List<String> skinTypes;
  final String ingredients;
  final String volume;
  final String brand;

  String get subtitle {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('purifying gel') || lowerName.contains('alpine purifying')) {
      return 'Gentle Daily Exfoliation';
    } else if (lowerName.contains('lipid recovery') || lowerName.contains('lipid recovery cream')) {
      return 'Deep Barrier Support';
    } else if (lowerName.contains('night oil') || lowerName.contains('botanical night')) {
      return 'Cellular Renewal';
    } else if (lowerName.contains('rosewater') || lowerName.contains('rosewater tonic')) {
      return 'Hydrating Prep Step';
    } else if (lowerName.contains('luminosity') || lowerName.contains('luminosity serum')) {
      return '15% Vitamin C Complex';
    } else if (lowerName.contains('detox mask') || lowerName.contains('clay mask') || lowerName.contains('mineral detox')) {
      return 'Weekly Pore Clarifying';
    } else if (lowerName.contains('renewal complex') || lowerName.contains('cellular renewal')) {
      return 'Cellular Renewal';
    }
    
    // Fallback: extract first sentence from description
    if (description.isNotEmpty) {
      final firstPeriod = description.indexOf('.');
      if (firstPeriod != -1) {
        return description.substring(0, firstPeriod).trim();
      }
      return description.length > 30 ? '${description.substring(0, 30)}...' : description;
    }
    return category;
  }

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.stockQuantity,
    required this.rating,
    required this.reviewsCount,
    required this.skinTypes,
    required this.ingredients,
    required this.volume,
    required this.brand,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final attributes = _attributeMap(json['attributes']);
    final description = json['description'] ?? json['short_description'];
    final imageUrl = json['imageUrl'] ?? json['image_url'];
    final price = json['price'] ?? json['base_price'];
    final category = json['category'] ?? json['category_name'];
    final brandName = json['brand'] ?? json['brand_name'];
    final stockQuantity = json['stockQuantity'] ?? json['available_qty'];

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: description?.toString() ?? '',
      price: _toDouble(price),
      imageUrl: imageUrl?.toString() ?? '',
      category: category?.toString() ?? 'General',
      stockQuantity: _toDouble(stockQuantity).toInt(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 12,
      skinTypes: _stringList(json['skinTypes'] ?? attributes['skin_types']) ??
          ['All Skintypes'],
      ingredients:
          (json['ingredients'] ?? attributes['ingredients'])?.toString() ?? '',
      volume: (json['volume'] ?? attributes['volume'])?.toString() ?? '50ml',
      brand: brandName?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'stockQuantity': stockQuantity,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'skinTypes': skinTypes,
      'ingredients': ingredients,
      'volume': volume,
      'brand': brand,
    };
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

List<String>? _stringList(dynamic value) {
  if (value is List) {
    final items = value
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    return items.isEmpty ? null : items;
  }

  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  return null;
}

Map<String, dynamic> _attributeMap(dynamic attributes) {
  if (attributes is! List) {
    return {};
  }

  final mapped = <String, dynamic>{};
  for (final item in attributes) {
    if (item is! Map) {
      continue;
    }

    final code = (item['code'] ?? item['attribute_code'] ?? item['label'])
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (code == null || code.isEmpty) {
      continue;
    }

    mapped[code] = item['value'] ??
        item['value_text'] ??
        item['value_json'] ??
        item['display_value'];
  }

  return mapped;
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get totalPrice => product.price * quantity;
}
