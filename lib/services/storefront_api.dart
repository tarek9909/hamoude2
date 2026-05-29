import 'dart:convert';

import 'package:http/http.dart' as http;

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
}

class StorefrontApiException implements Exception {
  final String message;
  final int? statusCode;

  const StorefrontApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class StorefrontBranch {
  final int id;
  final String name;
  final String? address;

  const StorefrontBranch({
    required this.id,
    required this.name,
    this.address,
  });

  factory StorefrontBranch.fromJson(Map<String, dynamic> json) {
    return StorefrontBranch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Store Branch',
      address: json['address_line_1']?.toString(),
    );
  }
}

class CustomerSession {
  final int customerId;
  final String customerToken;

  const CustomerSession({
    required this.customerId,
    required this.customerToken,
  });
}

class StorefrontApi {
  static const defaultStoreSlug = String.fromEnvironment(
    'STORE_SLUG',
    defaultValue: 'asd',
  );

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
                  defaultValue: 'http://192.168.10.210:4000/api/v1/storefront',
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
    };

    for (final key in mediaKeys) {
      final value = normalized[key];
      if (value is String) {
        normalized[key] = resolveMediaUrl(value);
      }
    }

    for (final entry in normalized.entries.toList()) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        normalized[entry.key] = _normalizeMediaUrls(value);
      } else if (value is List) {
        normalized[entry.key] = value.map((item) {
          return item is Map<String, dynamic>
              ? _normalizeMediaUrls(item)
              : item;
        }).toList();
      }
    }

    return normalized;
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    CustomerSession? session,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (session != null) 'x-customer-token': session.customerToken,
    };

    final response = await _client
        .send(
          http.Request(method, _uri(path, query))
            ..headers.addAll(headers)
            ..body = body == null ? '' : json.encode(body),
        )
        .timeout(const Duration(seconds: 8));

    final text = await response.stream.bytesToString();
    final payload = text.isEmpty
        ? <String, dynamic>{}
        : json.decode(text) as Map<String, dynamic>;

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] == false) {
      throw StorefrontApiException(
        payload['message']?.toString() ?? 'Storefront API request failed.',
        statusCode: response.statusCode,
      );
    }

    return payload;
  }

  Future<Map<String, dynamic>> getConfig() async {
    final payload = await _request('config');
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
    final payload = await _request(
      'products',
      query: {
        'per_page': 100,
        if (branchId != null) 'branch_id': branchId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
      },
    );
    final data = payload['data'];
    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(_normalizeMediaUrls)
        .map(Product.fromJson)
        .where((product) => product.id.isNotEmpty)
        .toList();
  }

  Future<Product?> getProduct(String productId, {int? branchId}) async {
    final payload = await _request(
      'products/$productId',
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
      query: {if (branchId != null) 'branch_id': branchId},
    );
  }

  Future<Map<String, dynamic>> quoteCart({
    required int branchId,
    required List<CartItem> items,
    String orderType = 'delivery',
    int? deliveryZoneId,
  }) async {
    final payload = await _request(
      'cart/quote',
      method: 'POST',
      body: {
        'branch_id': branchId,
        'order_type': orderType,
        if (deliveryZoneId != null) 'delivery_zone_id': deliveryZoneId,
        'items': items
            .map((item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
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
  }) async {
    final session = customerId != null && customerToken != null
        ? CustomerSession(customerId: customerId, customerToken: customerToken)
        : null;
    final payload = await _request(
      'checkout',
      method: 'POST',
      session: session,
      body: {
        'branch_id': branchId,
        'order_type': orderType,
        'payment_method': 'card',
        'idempotency_key':
            '$storeSlug-${DateTime.now().millisecondsSinceEpoch}',
        if (customerId != null) 'customer_id': customerId,
        if (deliveryAddressId != null) 'delivery_address_id': deliveryAddressId,
        if (deliveryZoneId != null) 'delivery_zone_id': deliveryZoneId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items
            .map((item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> requestOtp(String identifier) async {
    final payload = await _request(
      'auth/request-otp',
      method: 'POST',
      body: {'identifier': identifier},
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
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
    final customer = (data['customer'] as Map<String, dynamic>?) ?? {};
    return CustomerSession(
      customerId: (customer['id'] as num?)?.toInt() ?? 0,
      customerToken: data['customer_token']?.toString() ?? '',
    );
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
        if (session != null) 'customer_id': session.customerId,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> replySupportTicket({
    required String ticketId,
    required String message,
    required CustomerSession session,
  }) async {
    final payload = await _request(
      'support/tickets/$ticketId/messages',
      method: 'POST',
      session: session,
      body: {
        'customer_id': session.customerId,
        'message': message,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Map<String, dynamic>>> listSupportTickets(
      CustomerSession session) async {
    return _listData(
      'support/tickets',
      query: {'customer_id': session.customerId},
      session: session,
    );
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
    required String productId,
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
        'product_id': productId,
        'rating': rating,
        if (title != null && title.isNotEmpty) 'title': title,
        if (body != null && body.isNotEmpty) 'body': body,
        if (session != null) 'customer_id': session.customerId,
      },
    );
    return (payload['data'] as Map<String, dynamic>?) ?? {};
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
