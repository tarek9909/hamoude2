import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
// http_parser ships with package:http; MediaType is needed so multipart
// uploads carry the real MIME type the backend validates.
import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/product.dart';

class StoreBranding {
  final String name;
  final String slug;
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? accentColor;
  final String? textColor;
  final String? backgroundColor;

  const StoreBranding({
    required this.name,
    required this.slug,
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.accentColor,
    this.textColor,
    this.backgroundColor,
  });

  factory StoreBranding.fromJson(Map<String, dynamic> json) {
    return StoreBranding(
      name: (json['name'] ?? StorefrontApi.defaultStoreSlug).toString(),
      slug: (json['slug'] ?? StorefrontApi.defaultStoreSlug).toString(),
      logoUrl: json['logo_url']?.toString(),
      primaryColor: json['primary_color']?.toString(),
      secondaryColor: json['secondary_color']?.toString(),
      accentColor: json['accent_color']?.toString(),
      textColor: json['text_color']?.toString(),
      backgroundColor: json['background_color']?.toString(),
    );
  }

  factory StoreBranding.fromConfig(
    Map<String, dynamic> config, {
    required String fallbackSlug,
  }) {
    final store = (config['store'] as Map<String, dynamic>?) ?? {};
    final theme = (config['theme_settings'] as Map<String, dynamic>?) ?? {};

    return StoreBranding(
      name: (theme['app_name'] ?? store['name'] ?? fallbackSlug).toString(),
      slug: (store['slug'] ?? fallbackSlug).toString(),
      logoUrl: (theme['logo_url'] ?? store['logo_url'])?.toString(),
      primaryColor: theme['primary_color']?.toString(),
      secondaryColor: theme['secondary_color']?.toString(),
      accentColor: theme['accent_color']?.toString(),
      textColor: theme['text_color']?.toString(),
      backgroundColor: theme['background_color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (primaryColor != null) 'primary_color': primaryColor,
      if (secondaryColor != null) 'secondary_color': secondaryColor,
      if (accentColor != null) 'accent_color': accentColor,
      if (textColor != null) 'text_color': textColor,
      if (backgroundColor != null) 'background_color': backgroundColor,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreBranding &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          slug == other.slug &&
          logoUrl == other.logoUrl &&
          primaryColor == other.primaryColor &&
          secondaryColor == other.secondaryColor &&
          accentColor == other.accentColor &&
          textColor == other.textColor &&
          backgroundColor == other.backgroundColor;

  @override
  int get hashCode => Object.hash(
        name,
        slug,
        logoUrl,
        primaryColor,
        secondaryColor,
        accentColor,
        textColor,
        backgroundColor,
      );
}

class StorefrontApiException implements Exception {
  static const expiredTokenMessage = 'Invalid or expired customer token';

  final String message;
  final int? statusCode;

  const StorefrontApiException(this.message, {this.statusCode});

  /// True when the backend rejected the customer token (expired, revoked or
  /// invalid). Only meaningful for requests that carried a customer session.
  bool get isSessionExpired {
    if (statusCode == 401) return true;
    return statusCode == 403 &&
        message.toLowerCase().contains(expiredTokenMessage.toLowerCase());
  }

  @override
  String toString() => message;
}

class ProductPage {
  final List<Product> items;
  final int page;
  final int total;
  final bool hasMore;

  const ProductPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
  });
}

class BranchHour {
  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;

  const BranchHour({
    required this.dayOfWeek,
    this.openTime,
    this.closeTime,
    required this.isClosed,
  });

  factory BranchHour.fromJson(Map<String, dynamic> json) {
    return BranchHour(
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
      openTime: json['open_time']?.toString(),
      closeTime: json['close_time']?.toString(),
      isClosed: (json['is_closed'] as num?)?.toInt() == 1,
    );
  }
}

class StorefrontBranch {
  final int id;
  final String name;
  final String? address;
  final List<BranchHour> hours;

  const StorefrontBranch({
    required this.id,
    required this.name,
    this.address,
    required this.hours,
  });

  factory StorefrontBranch.fromJson(Map<String, dynamic> json) {
    final rawHours = json['hours'] as List? ?? [];
    final hoursList = rawHours
        .whereType<Map<String, dynamic>>()
        .map(BranchHour.fromJson)
        .toList();

    return StorefrontBranch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Store Branch',
      address: json['address_line_1']?.toString(),
      hours: hoursList,
    );
  }
}

class CustomerSession {
  final int customerId;
  final String customerToken;

  /// When the backend says the token stops working, if known.
  final DateTime? expiresAt;

  const CustomerSession({
    required this.customerId,
    required this.customerToken,
    this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc());

  CustomerSession copyWith({String? customerToken, DateTime? expiresAt}) {
    return CustomerSession(
      customerId: customerId,
      customerToken: customerToken ?? this.customerToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  factory CustomerSession.fromAuthData(Map<String, dynamic> data) {
    final customer = (data['customer'] as Map<String, dynamic>?) ?? {};
    return CustomerSession(
      customerId: (customer['id'] as num?)?.toInt() ??
          int.tryParse(customer['id']?.toString() ?? '') ??
          0,
      customerToken:
          (data['customer_token'] ?? data['token'])?.toString() ?? '',
      expiresAt: parseExpiry(data['token_expires_at']),
    );
  }

  static DateTime? parseExpiry(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toUtc();
  }
}

class StorefrontApi {
  static const defaultStoreSlug = String.fromEnvironment(
    'STORE_SLUG',
    defaultValue: 'skin-cella',
  );

  static const defaultTimeout = Duration(seconds: 8);

  /// Checkout can take longer than a normal read; the idempotency key makes a
  /// retry after a timeout safe.
  static const checkoutTimeout = Duration(seconds: 30);
  static const uploadTimeout = Duration(seconds: 60);

  final String baseUrl;
  final String storeSlug;
  final http.Client _client;

  StorefrontApi({
    String? baseUrl,
    this.storeSlug = defaultStoreSlug,
    http.Client? client,
  })  : baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'STOREFRONT_API_BASE_URL',
                  defaultValue: 'https://dashboard.zeyy.app/api/v1/storefront',
                ))
            .replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    final encodedSlug = Uri.encodeComponent(storeSlug);
    final url = '$baseUrl/$encodedSlug/$cleanPath';
    return Uri.parse(url).replace(
      queryParameters: query
          ?.map((key, value) => MapEntry(key, value?.toString()))
          .cast<String, String>(),
    );
  }

  String getLegalPolicyUrl(String type) {
    const overrideUrl = String.fromEnvironment('DASHBOARD_URL');
    if (overrideUrl.isNotEmpty) {
      return '${overrideUrl.replaceAll(RegExp(r"/+$"), "")}/admin/$storeSlug/legal/$type';
    }

    final uri = Uri.parse(baseUrl);
    String host = uri.host;
    int? port = uri.port;
    String scheme = uri.scheme;

    String dashboardHost = host;
    if (port == 4000) {
      dashboardHost = '$host:5173';
    } else if (port > 0) {
      dashboardHost = '$host:$port';
    }

    return '$scheme://$dashboardHost/admin/$storeSlug/legal/$type';
  }

  String resolveMediaUrl(String? value) {
    final rawValue = value?.trim() ?? '';
    if (rawValue.isEmpty || rawValue.startsWith('data:')) {
      return rawValue;
    }

    final apiUri = Uri.parse(baseUrl);
    final origin = apiUri.hasScheme && apiUri.authority.isNotEmpty
        ? '${apiUri.scheme}://${apiUri.authority}'
        : '';

    final parsedMediaUri = Uri.tryParse(rawValue);
    if (parsedMediaUri != null && parsedMediaUri.hasScheme) {
      final host = parsedMediaUri.host.toLowerCase();
      if (host == '127.0.0.1' || host == 'localhost') {
        return '$origin${parsedMediaUri.path}${parsedMediaUri.hasQuery ? "?${parsedMediaUri.query}" : ""}';
      }
    }

    if (parsedMediaUri != null &&
        parsedMediaUri.hasScheme &&
        parsedMediaUri.path.startsWith('/uploads/')) {
      return '$origin${parsedMediaUri.path}';
    }

    if (rawValue.startsWith('http://') || rawValue.startsWith('https://')) {
      return rawValue;
    }

    if (rawValue.startsWith('/')) {
      return '$origin${rawValue.replaceFirst(RegExp(r'^/+'), '/')}';
    }

    if (rawValue.startsWith('uploads/')) {
      return '$origin/$rawValue';
    }

    return rawValue;
  }

  Map<String, dynamic> _normalizeMediaUrls(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    const mediaKeys = {
      'image_url',
      'imageUrl',
      'mobile_image_url',
      'media_url',
      'preview_media_url',
      'logo_url',
      'primary_image_url',
      'profile_image_url',
    };

    for (final key in mediaKeys) {
      final value = normalized[key];
      if (value is String) {
        normalized[key] = resolveMediaUrl(value);
      }
    }

    for (final entry in normalized.entries.toList()) {
      final value = entry.value;
      if (value is Map) {
        normalized[entry.key] =
            _normalizeMediaUrls(Map<String, dynamic>.from(value));
      } else if (value is List) {
        normalized[entry.key] = value.map((item) {
          return item is Map
              ? _normalizeMediaUrls(Map<String, dynamic>.from(item))
              : item;
        }).toList();
      }
    }

    return normalized;
  }

  Map<String, dynamic> _cartItemPayload(CartItem item) => {
        'product_id': item.product.id,
        if (item.variantId.isNotEmpty) 'variant_id': item.variantId,
        'quantity': item.quantity,
      };

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    CustomerSession? session,
    String? wholesaleToken,
    Duration timeout = defaultTimeout,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (session != null) 'x-customer-token': session.customerToken,
      if (wholesaleToken != null) 'x-wholesale-token': wholesaleToken,
    };

    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(headers)
      ..body = body == null ? '' : json.encode(body);
    return _send(request, timeout);
  }

  Future<Map<String, dynamic>> _send(
    http.BaseRequest request,
    Duration timeout,
  ) async {
    final int statusCode;
    final String text;
    try {
      final response = await _client.send(request).timeout(timeout);
      statusCode = response.statusCode;
      text = await response.stream.bytesToString().timeout(timeout);
    } on TimeoutException {
      throw const StorefrontApiException(
          'The store took too long to respond. Check your connection and try again.');
    } on http.ClientException {
      throw const StorefrontApiException(
          'Could not reach the store. Check your connection and try again.');
    }
    return _decodeResponse(statusCode, text);
  }

  /// Turns any response into a JSON payload or a [StorefrontApiException].
  /// HTML error pages (proxy 502/504) never surface as a FormatException.
  Map<String, dynamic> _decodeResponse(int statusCode, String text) {
    Map<String, dynamic>? payload;
    if (text.trim().isEmpty) {
      payload = <String, dynamic>{};
    } else {
      try {
        final decoded = json.decode(text);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } on FormatException {
        payload = null;
      }
    }

    final ok = statusCode >= 200 && statusCode < 300;
    if (payload == null) {
      throw StorefrontApiException(
        _fallbackErrorMessage(statusCode, ok),
        statusCode: statusCode,
      );
    }
    if (!ok || payload['success'] == false) {
      final message = payload['message']?.toString().trim() ?? '';
      throw StorefrontApiException(
        message.isNotEmpty ? message : _fallbackErrorMessage(statusCode, ok),
        statusCode: statusCode,
      );
    }
    return payload;
  }

  static String _fallbackErrorMessage(int statusCode, bool ok) {
    if (ok) {
      return 'The store sent an unexpected response. Please try again.';
    }
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return 'The store is temporarily unavailable. Please try again shortly.';
    }
    if (statusCode == 413) {
      return 'That file is too large to upload.';
    }
    if (statusCode == 429) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    return 'Storefront API request failed.';
  }

  /// Parses product rows. Older wholesale catalogs return one row per
  /// variant (same `id`, different `variant_id`); those rows are merged into a
  /// single product with a `variants` array so every cart line keeps its
  /// variant id.
  List<Product> _parseProducts(List data) {
    final rows = data
        .whereType<Map<String, dynamic>>()
        .map(_normalizeMediaUrls)
        .toList();
    final merged = <String, Map<String, dynamic>>{};
    final order = <String>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final variantId = row['variant_id']?.toString() ?? '';
      final isVariantRow = variantId.isNotEmpty && row['variants'] is! List;
      final existing = merged[id];
      if (existing == null) {
        final copy = Map<String, dynamic>.from(row);
        if (isVariantRow) {
          copy['variants'] = [_variantFromRow(row)];
          copy['available_qty'] = _num(row['available_qty']);
        }
        merged[id] = copy;
        order.add(id);
      } else if (isVariantRow && existing['variants'] is List) {
        (existing['variants'] as List).add(_variantFromRow(row));
        existing['available_qty'] =
            _num(existing['available_qty']) + _num(row['available_qty']);
      }
    }
    return order
        .map((id) => Product.fromJson(merged[id]!))
        .where((product) => product.id.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic> _variantFromRow(Map<String, dynamic> row) => {
        'id': row['variant_id'],
        'name': row['variant_name'] ?? row['display_name'] ?? row['name'],
        'variant_display_name': row['variant_name'] ?? row['display_name'],
        'sku': row['sku'],
        'barcode': row['barcode'],
        'price': row['price'],
        'available_qty': row['available_qty'],
        'image_url': row['image_url'],
      };

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Future<ProductPage> listProductsPage({
    required int page,
    int perPage = 20,
    int? branchId,
    String? wholesaleToken,
    bool excludePreorder = false,
  }) async {
    final payload = await _request(
      wholesaleToken != null ? 'wholesale/products' : 'products',
      wholesaleToken: wholesaleToken,
      query: {
        'page': page,
        'per_page': perPage,
        if (branchId != null) 'branch_id': branchId,
        if (excludePreorder) 'exclude_preorder': 1,
      },
    );
    final data = payload['data'];
    final items = data is List ? _parseProducts(data) : <Product>[];

    final meta = payload['meta'];
    final total =
        meta is Map ? int.tryParse(meta['total']?.toString() ?? '') : null;
    final totalPages = meta is Map
        ? int.tryParse(meta['total_pages']?.toString() ?? '')
        : null;

    return ProductPage(
      items: items,
      page: page,
      total: total ?? items.length,
      hasMore: totalPages != null
          ? page < totalPages
          : (data is List && data.length >= perPage),
    );
  }

  Future<List<Product>> _listProductPages(
    String path, {
    int? branchId,
    String? search,
    String? categoryId,
    String? wholesaleToken,
  }) async {
    const perPage = 100;
    final rows = <dynamic>[];
    var page = 1;

    while (true) {
      final payload = await _request(
        path,
        wholesaleToken: wholesaleToken,
        query: {
          'page': page,
          'per_page': perPage,
          if (branchId != null) 'branch_id': branchId,
          if (search != null && search.isNotEmpty) 'search': search,
          if (categoryId != null && categoryId.isNotEmpty)
            'category_id': categoryId,
        },
      );
      final data = payload['data'];
      if (data is! List) {
        break;
      }

      rows.addAll(data);

      final meta = payload['meta'];
      final totalPages = meta is Map
          ? int.tryParse(meta['total_pages']?.toString() ?? '')
          : null;
      if (totalPages != null) {
        if (page >= totalPages) break;
      } else if (data.length < perPage) {
        break;
      }

      page++;
    }

    return _parseProducts(rows);
  }

  Future<Map<String, dynamic>> getConfig() async {
    final payload = await _request('config');
    final data = (payload['data'] as Map<String, dynamic>?) ?? {};
    return _normalizeMediaUrls(data);
  }

  Future<Map<String, dynamic>> requestWholesaleAccess(String password) async {
    final payload = await _request(
      'wholesale/access',
      method: 'POST',
      body: {'password': password},
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Product>> listWholesaleProducts({
    required String wholesaleToken,
    int? branchId,
    String? search,
    String? categoryId,
  }) async {
    return _listProductPages(
      'wholesale/products',
      wholesaleToken: wholesaleToken,
      branchId: branchId,
      search: search,
      categoryId: categoryId,
    );
  }

  Future<Map<String, dynamic>> checkoutWholesale({
    required String wholesaleToken,
    required int branchId,
    required List<CartItem> items,
    required String orderType,
    int? customerId,
    String? customerToken,
    int? deliveryAddressId,
    int? deliveryZoneId,
    String? notes,
    String? pickupTime,
    String? idempotencyKey,
  }) async {
    final session = customerId != null && customerToken != null
        ? CustomerSession(customerId: customerId, customerToken: customerToken)
        : null;
    final payload = await _request(
      'wholesale/checkout',
      method: 'POST',
      session: session,
      wholesaleToken: wholesaleToken,
      timeout: checkoutTimeout,
      body: {
        'branch_id': branchId,
        'order_type': orderType,
        'payment_method': 'cod',
        'idempotency_key': idempotencyKey ??
            '$storeSlug-wholesale-${DateTime.now().millisecondsSinceEpoch}',
        if (customerId != null) 'customer_id': customerId,
        if (deliveryAddressId != null) 'delivery_address_id': deliveryAddressId,
        if (deliveryZoneId != null) 'delivery_zone_id': deliveryZoneId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (pickupTime != null && pickupTime.isNotEmpty)
          'pickup_time': pickupTime,
        'items': items.map(_cartItemPayload).toList(),
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> getContent({int? branchId}) async {
    final payload = await _request(
      'content',
      query: {if (branchId != null) 'branch_id': branchId},
    );
    final data = (payload['data'] as Map<String, dynamic>?) ?? {};
    return _normalizeMediaUrls(data);
  }

  Future<List<Map<String, dynamic>>> listCategories({int? branchId}) async {
    return _listData('categories',
        query: {if (branchId != null) 'branch_id': branchId});
  }

  Future<List<Map<String, dynamic>>> listBrands({int? branchId}) async {
    return _listData('brands',
        query: {if (branchId != null) 'branch_id': branchId});
  }

  Future<Map<String, dynamic>> getCatalogSummary({int? branchId}) async {
    final payload = await _request(
      'catalog/summary',
      query: {if (branchId != null) 'branch_id': branchId},
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> getCatalogFilters({int? branchId}) async {
    final payload = await _request(
      'catalog/filters',
      query: {if (branchId != null) 'branch_id': branchId},
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Product>> listProducts({
    int? branchId,
    String? search,
    String? categoryId,
  }) async {
    return _listProductPages(
      'products',
      branchId: branchId,
      search: search,
      categoryId: categoryId,
    );
  }

  Future<Product?> getProduct(String productId, {int? branchId}) async {
    final payload = await _request(
      'products/${Uri.encodeComponent(productId)}',
      query: {if (branchId != null) 'branch_id': branchId},
    );
    final data = payload['data'];
    return data is Map<String, dynamic>
        ? Product.fromJson(_normalizeMediaUrls(data))
        : null;
  }

  Future<List<Map<String, dynamic>>> listPromotions({int? branchId}) async {
    return _listData('promotions',
        query: {if (branchId != null) 'branch_id': branchId});
  }

  Future<List<Map<String, dynamic>>> listBundles({int? branchId}) async {
    return _listData('bundles',
        query: {if (branchId != null) 'branch_id': branchId});
  }

  Future<List<Map<String, dynamic>>> listDeliveryZones({int? branchId}) async {
    return _listData('delivery-zones',
        query: {if (branchId != null) 'branch_id': branchId});
  }

  Future<List<Map<String, dynamic>>> listReviews({
    int? branchId,
    String? productId,
  }) async {
    return _listData(
      productId == null ? 'reviews' : 'products/$productId/reviews',
      query: {
        if (branchId != null) 'branch_id': branchId,
        'per_page': 100,
      },
    );
  }

  Future<Map<String, dynamic>> quoteCart({
    required int branchId,
    required List<CartItem> items,
    String orderType = 'delivery',
    int? deliveryZoneId,
    CustomerSession? session,
    String? wholesaleToken,
  }) async {
    final payload = await _request(
      wholesaleToken != null ? 'wholesale/cart/quote' : 'cart/quote',
      method: 'POST',
      session: session,
      wholesaleToken: wholesaleToken,
      body: {
        'branch_id': branchId,
        'order_type': orderType,
        if (deliveryZoneId != null) 'delivery_zone_id': deliveryZoneId,
        'items': items.map(_cartItemPayload).toList(),
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> checkout({
    required int branchId,
    required List<CartItem> items,
    required String orderType,
    int? customerId,
    String? customerToken,
    int? deliveryAddressId,
    int? deliveryZoneId,
    String? notes,
    String? pickupTime,
    String? idempotencyKey,
  }) async {
    final session = customerId != null && customerToken != null
        ? CustomerSession(customerId: customerId, customerToken: customerToken)
        : null;
    final payload = await _request(
      'checkout',
      method: 'POST',
      session: session,
      timeout: checkoutTimeout,
      body: {
        'branch_id': branchId,
        'order_type': orderType,
        'payment_method': 'cod',
        'idempotency_key': idempotencyKey ??
            '$storeSlug-${DateTime.now().millisecondsSinceEpoch}',
        if (customerId != null) 'customer_id': customerId,
        if (deliveryAddressId != null) 'delivery_address_id': deliveryAddressId,
        if (deliveryZoneId != null) 'delivery_zone_id': deliveryZoneId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (pickupTime != null && pickupTime.isNotEmpty)
          'pickup_time': pickupTime,
        'items': items.map(_cartItemPayload).toList(),
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> requestOtp(String identifier,
      {bool checkExists = false, bool checkNotExists = false}) async {
    final payload = await _request(
      'auth/request-otp',
      method: 'POST',
      body: {
        'identifier': identifier,
        'checkExists': checkExists,
        'checkNotExists': checkNotExists,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Asks the store to reset a password. Usernames go to admin review;
  /// emails use the OTP flow. The returned map is `data` plus the server
  /// `message`.
  Future<Map<String, dynamic>> requestPasswordReset(String identifier) async {
    final value = identifier.trim();
    final payload = await _request(
      'auth/password-reset-request',
      method: 'POST',
      body: value.contains('@') ? {'email': value} : {'username': value},
    );
    return {
      ...((payload['data'] as Map<String, dynamic>?) ?? {}),
      if (payload['message'] != null) 'message': payload['message'].toString(),
    };
  }

  Future<CustomerSession> verifyOtp({
    required String identifier,
    required String challenge,
    required String code,
    String? fullName,
  }) async {
    final payload = await _request(
      'auth/verify-otp',
      method: 'POST',
      body: {
        'identifier': identifier,
        'challenge': challenge,
        'code': code,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      },
    );
    final data = (payload['data'] as Map<String, dynamic>?) ?? {};
    return CustomerSession.fromAuthData(data);
  }

  Future<List<Map<String, dynamic>>> listOrders(CustomerSession session) async {
    final payload = await _request(
      'me/orders',
      query: {'customer_id': session.customerId},
      session: session,
    );
    return (payload['data'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
  }

  Future<Map<String, dynamic>> getOrder({
    required String orderId,
    required CustomerSession session,
  }) async {
    final payload = await _request(
      'orders/$orderId',
      query: {'customer_id': session.customerId},
      session: session,
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Map<String, dynamic>>> getOrderTimeline({
    required String orderId,
    required CustomerSession session,
  }) async {
    return _listData(
      'orders/$orderId/timeline',
      query: {'customer_id': session.customerId},
      session: session,
    );
  }

  Future<Map<String, dynamic>> reorder({
    required String orderId,
    required CustomerSession session,
  }) async {
    final payload = await _request(
      'orders/$orderId/reorder',
      method: 'POST',
      session: session,
      body: {'customer_id': session.customerId},
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required CustomerSession session,
  }) async {
    final payload = await _request(
      'orders/$orderId/cancel',
      method: 'POST',
      session: session,
      body: {'customer_id': session.customerId},
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Map<String, dynamic>>> listNotifications(
      CustomerSession session) async {
    final payload = await _request(
      'notifications',
      query: {'customer_id': session.customerId},
      session: session,
    );
    return (payload['data'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
  }

  Future<void> markNotificationRead({
    required String notificationId,
    required CustomerSession session,
  }) async {
    await _request(
      'notifications/$notificationId/read',
      method: 'PATCH',
      session: session,
      body: {'customer_id': session.customerId},
    );
  }

  Future<void> markAllNotificationsRead(CustomerSession session) async {
    await _request(
      'notifications/read-all',
      method: 'POST',
      session: session,
      body: const {},
    );
  }

  Future<void> markNotificationClicked({
    required String notificationId,
    required CustomerSession session,
  }) async {
    await _request(
      'notifications/$notificationId/click',
      method: 'PATCH',
      session: session,
      body: {'customer_id': session.customerId},
    );
  }

  Future<Map<String, dynamic>> getProfile(CustomerSession session) async {
    final payload = await _request(
      'me',
      query: {'customer_id': session.customerId},
      session: session,
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  /// `PATCH me` accepts only `full_name` and `phone`.
  Future<Map<String, dynamic>> updateProfile({
    required CustomerSession session,
    required String name,
    String? phone,
  }) async {
    final payload = await _request(
      'me',
      method: 'PATCH',
      session: session,
      body: {
        'full_name': name,
        if (phone != null) 'phone': phone,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Changes the password after verifying the current one. The response may
  /// carry a rotated `token` and `token_expires_at`.
  Future<Map<String, dynamic>> changePassword({
    required CustomerSession session,
    required String currentPassword,
    required String newPassword,
  }) async {
    final payload = await _request(
      'me/change-password',
      method: 'POST',
      session: session,
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<CustomerSession> loginWithPassword({
    required String username,
    required String password,
  }) async {
    final payload = await _request(
      'auth/login',
      method: 'POST',
      body: {
        'username': username,
        'password': password,
      },
    );
    final data = (payload['data'] as Map<String, dynamic>?) ?? {};
    return CustomerSession.fromAuthData(data);
  }

  Future<CustomerSession> registerWithUsernamePassword({
    required String name,
    required String username,
    required String password,
  }) async {
    final payload = await _request(
      'auth/register-username',
      method: 'POST',
      body: {
        'full_name': name,
        'username': username,
        'password': password,
        'policy_acceptance': {
          'terms_accepted': true,
          'privacy_accepted': true,
        },
      },
    );
    final data = (payload['data'] as Map<String, dynamic>?) ?? {};
    return CustomerSession.fromAuthData(data);
  }

  Future<void> logout(CustomerSession session) async {
    await _request(
      'auth/logout',
      method: 'POST',
      session: session,
      body: {'customer_id': session.customerId},
    );
  }

  /// Deletes the account, confirmed with the customer's password (username
  /// accounts) or an email OTP verification token.
  Future<void> deleteAccount(
    CustomerSession session, {
    String? password,
    String? verificationToken,
  }) async {
    await _request(
      'me',
      method: 'DELETE',
      session: session,
      body: {
        if (password != null) 'password': password,
        if (verificationToken != null) 'verification_token': verificationToken,
      },
    );
  }

  /// MIME type for an upload, from its file name. Defaults to JPEG for
  /// images picked without an extension.
  static String mimeTypeForFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    final extension = dot >= 0 ? filename.substring(dot + 1).toLowerCase() : '';
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'image/jpeg';
    }
  }

  Future<Map<String, dynamic>> _uploadBytes({
    required String path,
    required String field,
    required List<int> bytes,
    required String filename,
    required CustomerSession session,
    String? mimeType,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll({
        'Accept': 'application/json',
        'x-customer-token': session.customerToken,
        'Authorization': 'Bearer ${session.customerToken}',
      })
      ..files.add(http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType ?? mimeTypeForFilename(filename)),
      ));
    final payload = await _send(request, uploadTimeout);
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> uploadProfileImage({
    required CustomerSession session,
    required List<int> bytes,
    required String filename,
    String? mimeType,
  }) {
    return _uploadBytes(
      path: 'me/profile-image',
      field: 'image',
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      session: session,
    );
  }

  Future<Map<String, dynamic>> removeProfileImage(
      CustomerSession session) async {
    final payload = await _request(
      'me/profile-image',
      method: 'DELETE',
      session: session,
      body: {'customer_id': session.customerId},
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Map<String, dynamic>>> listAddresses(
      CustomerSession session) async {
    return _listData(
      'me/addresses',
      query: {'customer_id': session.customerId},
      session: session,
    );
  }

  Future<Map<String, dynamic>> createAddress({
    required CustomerSession session,
    required Map<String, dynamic> address,
  }) async {
    final payload = await _request(
      'me/addresses',
      method: 'POST',
      session: session,
      body: {
        'customer_id': session.customerId,
        ...address,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> updateAddress({
    required CustomerSession session,
    required String addressId,
    required Map<String, dynamic> address,
  }) async {
    final payload = await _request(
      'me/addresses/$addressId',
      method: 'PATCH',
      session: session,
      body: {
        'customer_id': session.customerId,
        ...address,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> deleteAddress({
    required CustomerSession session,
    required String addressId,
  }) async {
    await _request(
      'me/addresses/$addressId',
      method: 'DELETE',
      session: session,
      body: {'customer_id': session.customerId},
    );
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String message,
    String? category,
    List<Map<String, dynamic>>? attachments,
    CustomerSession? session,
  }) async {
    final payload = await _request(
      'support/tickets',
      method: 'POST',
      session: session,
      body: {
        'subject': subject,
        'message': message,
        if (category != null) 'category': category,
        if (attachments != null) 'attachments': attachments,
        if (session != null) 'customer_id': session.customerId,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> replySupportTicket({
    required String ticketId,
    required String message,
    List<Map<String, dynamic>>? attachments,
    required CustomerSession session,
  }) async {
    final payload = await _request(
      'support/tickets/$ticketId/messages',
      method: 'POST',
      session: session,
      body: {
        'customer_id': session.customerId,
        'message': message,
        if (attachments != null) 'attachments': attachments,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> closeSupportTicket({
    required String ticketId,
    required CustomerSession session,
  }) async {
    final payload = await _request(
      'support/tickets/$ticketId/close',
      method: 'POST',
      session: session,
      body: {
        'customer_id': session.customerId,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> uploadSupportAttachment({
    required List<int> bytes,
    required String filename,
    required CustomerSession session,
    String? mimeType,
  }) {
    return _uploadBytes(
      path: 'support/uploads',
      field: 'attachment',
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      session: session,
    );
  }

  Future<List<Map<String, dynamic>>> listSupportTickets(
      CustomerSession session) async {
    return _listData(
      'support/tickets',
      query: {'customer_id': session.customerId},
      session: session,
    );
  }

  Future<Map<String, dynamic>> getSupportTicket({
    required String ticketId,
    required CustomerSession session,
  }) async {
    final payload = await _request(
      'support/tickets/$ticketId',
      method: 'GET',
      session: session,
      query: {'customer_id': session.customerId},
    );
    final data = (payload['data'] as Map<String, dynamic>?) ?? {};
    return data;
  }

  Future<List<Map<String, dynamic>>> listServiceCases(
      CustomerSession session) async {
    return _listData(
      'me/service-cases',
      query: {'customer_id': session.customerId},
      session: session,
    );
  }

  Future<Map<String, dynamic>> createServiceCase({
    required String orderId,
    required String title,
    required CustomerSession session,
    String caseType = 'order_issue',
    String? issueCategory,
    String? description,
  }) async {
    final payload = await _request(
      'orders/$orderId/service-cases',
      method: 'POST',
      session: session,
      body: {
        'customer_id': session.customerId,
        'case_type': caseType,
        'title': title,
        if (issueCategory != null && issueCategory.isNotEmpty)
          'issue_category': issueCategory,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> createReview({
    String? productId,
    required int rating,
    String? title,
    String? body,
    CustomerSession? session,
  }) async {
    final payload = await _request(
      'reviews',
      method: 'POST',
      session: session,
      body: {
        if (productId != null && productId.isNotEmpty) 'product_id': productId,
        'rating': rating,
        if (title != null && title.isNotEmpty) 'title': title,
        if (body != null && body.isNotEmpty) 'body': body,
        if (session != null) 'customer_id': session.customerId,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> deleteReview({
    required int reviewId,
    required CustomerSession session,
  }) async {
    await _request(
      'reviews/$reviewId',
      method: 'DELETE',
      session: session,
      body: {'customer_id': session.customerId},
    );
  }

  Future<Map<String, dynamic>> submitTicketFeedback({
    required String ticketId,
    required int rating,
    required String comment,
    CustomerSession? session,
  }) async {
    final payload = await _request(
      'support/tickets/$ticketId/feedback',
      method: 'POST',
      session: session,
      body: {
        'rating': rating,
        'comment': comment,
        if (session != null) 'customer_id': session.customerId,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Map<String, dynamic>>> listMyReviews(
      CustomerSession session) async {
    return _listData(
      'me/reviews',
      query: {'customer_id': session.customerId},
      session: session,
    );
  }

  Future<List<Map<String, dynamic>>> _listData(
    String path, {
    Map<String, dynamic>? query,
    CustomerSession? session,
  }) async {
    final payload = await _request(path, query: query, session: session);
    final data = payload['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(_normalizeMediaUrls)
          .toList();
    }
    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(_normalizeMediaUrls)
          .toList();
    }
    return [];
  }
}
