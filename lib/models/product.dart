import 'dart:convert';

class ProductAttribute {
  final String code;
  final String label;
  final dynamic value;
  final String displayValue;
  final List<String> options;
  final String unitLabel;

  const ProductAttribute({
    required this.code,
    required this.label,
    this.value,
    required this.displayValue,
    this.options = const [],
    this.unitLabel = '',
  });

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    final rawValue = json['display_value'] ??
        json['value'] ??
        json['value_text'] ??
        json['value_json'] ??
        json['value_decimal'] ??
        json['value_number'];
    final displayValue = _attributeDisplayValue(rawValue);
    final unitLabel = json['unit_label']?.toString() ?? '';

    return ProductAttribute(
      code: (json['code'] ?? json['attribute_code'] ?? json['label'])
              ?.toString()
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'^_+|_+$'), '') ??
          '',
      label: json['label']?.toString() ?? '',
      value: rawValue,
      displayValue: unitLabel.isNotEmpty &&
              displayValue.isNotEmpty &&
              !displayValue.toLowerCase().endsWith(unitLabel.toLowerCase())
          ? '$displayValue $unitLabel'
          : displayValue,
      options: _attributeOptions(json['options_json'] ?? json['options']),
      unitLabel: unitLabel,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'value': value,
        'display_value': displayValue,
        if (options.isNotEmpty) 'options_json': options,
        if (unitLabel.isNotEmpty) 'unit_label': unitLabel,
      };
}

class ProductImage {
  final String id;
  final String? variantId;
  final String imageUrl;
  final String altText;
  final bool isPrimary;
  final int sortOrder;

  const ProductImage({
    required this.id,
    this.variantId,
    required this.imageUrl,
    this.altText = '',
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: (json['id'] ?? '').toString(),
      variantId: json['variant_id']?.toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? '').toString(),
      altText: (json['alt_text'] ?? json['altText'] ?? '').toString(),
      isPrimary: _toBool(json['is_primary'] ?? json['isPrimary']),
      sortOrder: _toDouble(json['sort_order'] ?? json['sortOrder']).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (variantId != null) 'variant_id': variantId,
        'image_url': imageUrl,
        'alt_text': altText,
        'is_primary': isPrimary,
        'sort_order': sortOrder,
      };
}

class ProductVariant {
  final String id;
  final String name;
  final String displayName;
  final String sku;
  final String barcode;
  final double? price;
  final int stockQuantity;
  final bool isDefault;
  final String imageUrl;
  final List<String> colorHexes;
  final List<ProductAttribute> attributes;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.displayName,
    this.sku = '',
    this.barcode = '',
    this.price,
    this.stockQuantity = 0,
    this.isDefault = false,
    this.imageUrl = '',
    this.colorHexes = const [],
    this.attributes = const [],
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final attributes =
        _productAttributes(json['attributes'] ?? json['variant_attributes']);
    final name = (json['name'] ?? '').toString();
    final displayName =
        (json['variant_display_name'] ?? json['display_name'] ?? name)
            .toString()
            .trim();

    return ProductVariant(
      id: (json['id'] ?? json['variant_id'] ?? '').toString(),
      name: name,
      displayName: displayName.isNotEmpty ? displayName : name,
      sku: (json['sku'] ?? '').toString(),
      barcode: (json['barcode'] ?? '').toString(),
      price: _nullableDouble(json['price']),
      stockQuantity:
          _toDouble(json['stockQuantity'] ?? json['available_qty']).toInt(),
      isDefault: _toBool(json['is_default'] ?? json['isDefault']),
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? '').toString(),
      colorHexes:
          _hexColorList(json['color_hexes'] ?? json['color_hexes_json']),
      attributes: attributes,
    );
  }

  String attributeValue(String code) {
    final normalized = _normalizeAttributeCode(code);
    for (final attribute in attributes) {
      if (attribute.code == normalized) {
        return attribute.displayValue;
      }
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'variant_display_name': displayName,
        'sku': sku,
        'barcode': barcode,
        'price': price,
        'available_qty': stockQuantity,
        'is_default': isDefault,
        'image_url': imageUrl,
        if (colorHexes.isNotEmpty) 'color_hexes': colorHexes,
        'attributes':
            attributes.map((attribute) => attribute.toJson()).toList(),
      };
}

class Product {
  final String id;
  final String name;
  final String description;
  final String shortDescription;
  final double price;
  final double? retailPrice;
  final double? wholesalePrice;
  final String imageUrl;
  final String category;
  final int stockQuantity;
  final double rating;
  final int reviewsCount;
  final List<String> skinTypes;
  final String ingredients;
  final String volume;
  final String measurementLabel;
  final String unitName;
  final String unitSymbol;
  final String unitLabel;
  final String productType;
  final String sellBy;
  final List<ProductAttribute> attributes;
  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final String brand;
  final int sortOrder;

  int get availableStockQuantity {
    if (variants.isEmpty) {
      return stockQuantity;
    }
    return variants.fold<int>(
      0,
      (sum, variant) =>
          sum + (variant.stockQuantity > 0 ? variant.stockQuantity : 0),
    );
  }

  bool get isAvailable => availableStockQuantity > 0;

  String get subtitle {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('purifying gel') ||
        lowerName.contains('alpine purifying')) {
      return 'Gentle Daily Exfoliation';
    } else if (lowerName.contains('lipid recovery') ||
        lowerName.contains('lipid recovery cream')) {
      return 'Deep Barrier Support';
    } else if (lowerName.contains('night oil') ||
        lowerName.contains('botanical night')) {
      return 'Cellular Renewal';
    } else if (lowerName.contains('rosewater') ||
        lowerName.contains('rosewater tonic')) {
      return 'Hydrating Prep Step';
    } else if (lowerName.contains('luminosity') ||
        lowerName.contains('luminosity serum')) {
      return '15% Vitamin C Complex';
    } else if (lowerName.contains('detox mask') ||
        lowerName.contains('clay mask') ||
        lowerName.contains('mineral detox')) {
      return 'Weekly Pore Clarifying';
    } else if (lowerName.contains('renewal complex') ||
        lowerName.contains('cellular renewal')) {
      return 'Cellular Renewal';
    }

    if (shortDescription.trim().isNotEmpty) {
      return shortDescription.trim();
    }

    if (description.isNotEmpty) {
      final firstPeriod = description.indexOf('.');
      if (firstPeriod != -1) {
        return description.substring(0, firstPeriod).trim();
      }
      return description.length > 30
          ? '${description.substring(0, 30)}...'
          : description;
    }
    return category;
  }

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.shortDescription,
    required this.price,
    this.retailPrice,
    this.wholesalePrice,
    required this.imageUrl,
    required this.category,
    required this.stockQuantity,
    required this.rating,
    required this.reviewsCount,
    required this.skinTypes,
    required this.ingredients,
    required this.volume,
    this.measurementLabel = '',
    this.unitName = '',
    this.unitSymbol = '',
    this.unitLabel = '',
    this.productType = 'physical',
    this.sellBy = 'unit',
    this.attributes = const [],
    this.images = const [],
    this.variants = const [],
    required this.brand,
    this.sortOrder = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final attributes = _attributeMap(json['attributes']);
    final attributeList = _productAttributes(json['attributes']);
    final images = _productImages(json['images']);
    final variants = _productVariants(json['variants'], images);
    final description = json['description'] ?? json['short_description'];
    final shortDescription = json['short_description'] ?? json['description'];
    final imageUrl = json['imageUrl'] ?? json['image_url'];
    final primaryImageUrl = (imageUrl?.toString() ?? '').isNotEmpty
        ? imageUrl.toString()
        : images.isNotEmpty
            ? images.first.imageUrl
            : '';
    final price = json['price'] ?? json['base_price'];
    final retailPrice = json['retailPrice'] ?? json['retail_price'];
    final wholesalePrice = json['wholesalePrice'] ?? json['wholesale_price'];
    final category = json['category'] ?? json['category_name'];
    final brandName = json['brand'] ?? json['brand_name'];
    final stockQuantity = json['stockQuantity'] ?? json['available_qty'];
    final unitName = json['unit_name']?.toString() ?? '';
    final unitSymbol = json['unit_symbol']?.toString() ?? '';
    final unitLabel = json['unit_label']?.toString() ?? '';
    final legacyVolume =
        (json['volume'] ?? attributes['volume'])?.toString() ?? '50ml';
    final measurementLabel = _measurementLabel(
        json, attributeList, unitSymbol, unitLabel, unitName, legacyVolume);

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: description?.toString() ?? '',
      shortDescription: shortDescription?.toString() ?? '',
      price: _toDouble(price),
      retailPrice: _nullableDouble(retailPrice),
      wholesalePrice: _nullableDouble(wholesalePrice),
      imageUrl: primaryImageUrl,
      category: category?.toString() ?? 'General',
      stockQuantity: _toDouble(stockQuantity).toInt(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 12,
      skinTypes: _stringList(json['skinTypes'] ?? attributes['skin_types']) ??
          ['All Skintypes'],
      ingredients:
          (json['ingredients'] ?? attributes['ingredients'])?.toString() ?? '',
      volume: legacyVolume,
      measurementLabel: measurementLabel,
      unitName: unitName,
      unitSymbol: unitSymbol,
      unitLabel: unitLabel,
      productType: json['product_type']?.toString() ?? 'physical',
      sellBy: json['sell_by']?.toString() ?? 'unit',
      attributes: attributeList,
      images: images.isNotEmpty
          ? images
          : [
              if (primaryImageUrl.isNotEmpty)
                ProductImage(
                  id: 'primary',
                  imageUrl: primaryImageUrl,
                  isPrimary: true,
                ),
            ],
      variants: variants,
      brand: brandName?.toString() ?? '',
      sortOrder:
          _toDouble(json['sort_order'] ?? json['sortOrder'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'shortDescription': shortDescription,
      'price': price,
      'retailPrice': retailPrice,
      'wholesalePrice': wholesalePrice,
      'imageUrl': imageUrl,
      'category': category,
      'stockQuantity': stockQuantity,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'skinTypes': skinTypes,
      'ingredients': ingredients,
      'volume': volume,
      'measurementLabel': measurementLabel,
      'measurement_label': measurementLabel,
      'unit_name': unitName,
      'unit_symbol': unitSymbol,
      'unit_label': unitLabel,
      'product_type': productType,
      'sell_by': sellBy,
      'attributes': attributes.map((attribute) => attribute.toJson()).toList(),
      'images': images.map((image) => image.toJson()).toList(),
      'variants': variants.map((variant) => variant.toJson()).toList(),
      'brand': brand,
      'sort_order': sortOrder,
    };
  }

  static bool compareIds(dynamic id1, dynamic id2) {
    if (id1 == null || id2 == null) return false;
    final s1 = id1.toString().trim();
    final s2 = id2.toString().trim();
    if (s1 == s2) return true;
    final d1 = double.tryParse(s1);
    final d2 = double.tryParse(s2);
    if (d1 != null && d2 != null) {
      return d1.toInt() == d2.toInt();
    }
    return false;
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

double? _nullableDouble(dynamic value) {
  if (value == null || value == '') {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

String _attributeDisplayValue(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  return value.toString().trim();
}

List<String> _attributeOptions(dynamic value) {
  if (value == null) {
    return const [];
  }
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
  final trimmed = value.toString().trim();
  if (trimmed.isEmpty) {
    return const [];
  }
  return trimmed
      .replaceAll('[', '')
      .replaceAll(']', '')
      .replaceAll('"', '')
      .split(RegExp(r'[\n,]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

String _normalizeAttributeCode(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

List<ProductAttribute> _productAttributes(dynamic attributes) {
  if (attributes is! List) {
    return const [];
  }

  return attributes
      .whereType<Map>()
      .map((item) => ProductAttribute.fromJson(Map<String, dynamic>.from(item)))
      .where((attribute) =>
          attribute.code.isNotEmpty && attribute.displayValue.isNotEmpty)
      .toList();
}

List<ProductImage> _productImages(dynamic images) {
  if (images is! List) {
    return const [];
  }

  return images
      .whereType<Map>()
      .map((item) => ProductImage.fromJson(Map<String, dynamic>.from(item)))
      .where((image) => image.imageUrl.isNotEmpty)
      .toList();
}

List<ProductVariant> _productVariants(
  dynamic variants,
  List<ProductImage> images,
) {
  if (variants is! List) {
    return const [];
  }

  return variants
      .whereType<Map>()
      .map((item) {
        final variant =
            ProductVariant.fromJson(Map<String, dynamic>.from(item));
        final variantImage = images
            .where((image) => image.variantId == variant.id)
            .map((image) => image.imageUrl)
            .where((url) => url.isNotEmpty)
            .cast<String?>()
            .firstWhere((url) => url != null, orElse: () => null);
        if (variant.imageUrl.isNotEmpty || variantImage == null) {
          return variant;
        }
        return ProductVariant(
          id: variant.id,
          name: variant.name,
          displayName: variant.displayName,
          sku: variant.sku,
          barcode: variant.barcode,
          price: variant.price,
          stockQuantity: variant.stockQuantity,
          isDefault: variant.isDefault,
          imageUrl: variantImage,
          colorHexes: variant.colorHexes,
          attributes: variant.attributes,
        );
      })
      .where((variant) => variant.id.isNotEmpty)
      .toList();
}

List<String> _hexColorList(dynamic value) {
  final rawValues = <dynamic>[];
  if (value is List) {
    rawValues.addAll(value);
  } else if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          rawValues.addAll(decoded);
        }
      } catch (_) {
        rawValues.addAll(trimmed.split(','));
      }
    } else {
      rawValues.addAll(trimmed.split(','));
    }
  }

  final normalized = <String>{};
  for (final raw in rawValues) {
    final text = raw.toString().trim();
    if (text.isEmpty) continue;
    final withHash = text.startsWith('#') ? text : '#$text';
    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(withHash)) {
      normalized.add(withHash.toUpperCase());
    }
  }
  return normalized.toList();
}

String _measurementLabel(
  Map<String, dynamic> json,
  List<ProductAttribute> attributes,
  String unitSymbol,
  String unitLabel,
  String unitName,
  String legacyVolume,
) {
  final explicit = (json['measurementLabel'] ?? json['measurement_label'])
      ?.toString()
      .trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  const priorityCodes = {
    'size',
    'package_size',
    'volume',
    'capacity',
    'weight',
    'storage',
    'quantity',
  };
  for (final attribute in attributes) {
    if (priorityCodes.contains(attribute.code) &&
        attribute.displayValue.trim().isNotEmpty) {
      return attribute.displayValue.trim();
    }
  }

  for (final value in [unitSymbol, unitLabel, unitName, legacyVolume]) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return '';
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
  final ProductVariant? variant;
  int quantity;

  CartItem({
    required this.product,
    this.variant,
    this.quantity = 1,
  });

  String get variantId => variant?.id ?? '';
  String get cartKey => '${product.id}::$variantId';
  String get displayName => variant == null
      ? product.name
      : '${product.name} - ${variant!.displayName}';
  String get imageUrl => variant?.imageUrl.isNotEmpty == true
      ? variant!.imageUrl
      : product.imageUrl;
  String get sku => variant?.sku ?? '';
  int get stockQuantity => variant?.stockQuantity ?? product.stockQuantity;
  double get unitPrice => variant?.price ?? product.price;
  double get totalPrice => unitPrice * quantity;

  String get selectedSize {
    if (variant != null) {
      final val = variant!.attributeValue('size');
      if (val.isNotEmpty) {
        return val;
      }
      for (final attr in variant!.attributes) {
        if (attr.code.contains('size') ||
            attr.label.toLowerCase().contains('size')) {
          return attr.displayValue;
        }
      }
      if (variant!.attributes.isNotEmpty) {
        return variant!.attributes.first.displayValue;
      }
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        if (variant != null) 'variant': variant!.toJson(),
        if (variant != null) 'variant_id': variant!.id,
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: Product.fromJson(json['product']),
        variant: json['variant'] is Map
            ? ProductVariant.fromJson(
                Map<String, dynamic>.from(json['variant'] as Map),
              )
            : null,
        quantity: json['quantity'] ?? 1,
      );
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}
