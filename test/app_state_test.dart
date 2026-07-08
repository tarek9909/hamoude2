import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront_template/models/product.dart';
import 'package:storefront_template/providers/app_state.dart';
import 'package:storefront_template/services/storefront_api.dart';

class FakeStorefrontApi extends StorefrontApi {
  String? lastCreatedTicketCategory;
  String? lastRepliedTicketId;
  String? lastRepliedMessage;
  String? lastUpdatedProfilePassword;
  String? lastRegisteredName;
  String? lastRegisteredPhone;
  String? lastRegisteredDob;
  String? lastRegisteredGender;
  String? lastRegisteredPassword;
  String? lastLoginIdentifier;
  String? lastLoginPassword;
  String? lastPasswordResetIdentifier;
  CustomerSession? lastLoggedOutSession;
  List<CartItem>? lastCheckoutItems;
  String? lastCheckoutOrderType;

  FakeStorefrontApi()
      : super(
          baseUrl: 'http://example.test/api/v1/storefront',
          storeSlug: 'skin-cella',
        );

  @override
  Future<Map<String, dynamic>> getConfig() async {
    return {
      'store': {'slug': 'skin-cella', 'name': 'Skin Cella'},
      'theme_settings': {
        'app_name': 'Skin Cella',
        'primary_color': '#006600',
        'secondary_color': '#335533',
        'accent_color': '#D9ECD2',
        'text_color': '#102010',
        'background_color': '#FAFFF8',
      },
      'app_settings': {
        'features': {
          'catalog': true,
          'admin_catalog_products': true,
          'admin_catalog_brands': true,
          'admin_catalog_categories': true,
          'admin_catalog_wholesale': true,
          'orders': true,
          'admin_orders_all': true,
          'customers': true,
          'admin_customers': true,
          'support': true,
          'admin_support': true,
          'notifications': true,
          'admin_notifications': true,
          'admin_reviews': true,
          'admin_marketing_content': true,
          'admin_marketing_promotions': true,
          'admin_marketing_bundles': true,
          'admin_fulfillment': true,
        },
      },
      'wholesale_settings': {
        'is_enabled': 1,
        'minimum_order_amount': 250.0,
      },
      'branches': [
        {'id': 10, 'name': 'Main Branch'},
      ],
    };
  }

  @override
  Future<CustomerSession> verifyOtp({
    required String identifier,
    required String challenge,
    required String code,
    String? fullName,
  }) async {
    return const CustomerSession(customerId: 7, customerToken: 'token-7');
  }

  @override
  Future<List<Product>> listProducts({
    int? branchId,
    String? search,
    String? categoryId,
  }) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listCategories({int? branchId}) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listBrands({int? branchId}) async {
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getContent({int? branchId}) async {
    return const {};
  }

  @override
  Future<List<Map<String, dynamic>>> listPromotions({int? branchId}) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listBundles({int? branchId}) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listDeliveryZones({int? branchId}) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listReviews({
    int? branchId,
    String? productId,
  }) async {
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getProfile(CustomerSession session) async {
    return {
      'full_name': 'Maya Customer',
      'phone': '+96170000000',
    };
  }

  @override
  Future<CustomerSession> registerWithPhonePassword({
    required String name,
    required String phone,
    required String dob,
    required String gender,
    required String password,
  }) async {
    lastRegisteredName = name;
    lastRegisteredPhone = phone;
    lastRegisteredDob = dob;
    lastRegisteredGender = gender;
    lastRegisteredPassword = password;
    return const CustomerSession(customerId: 7, customerToken: 'token-7');
  }

  @override
  Future<CustomerSession> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    lastLoginIdentifier = identifier;
    lastLoginPassword = password;
    return const CustomerSession(customerId: 7, customerToken: 'token-7');
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required CustomerSession session,
    required String name,
    required String email,
    required String phone,
    required String dob,
    required String gender,
    String? password,
  }) async {
    lastUpdatedProfilePassword = password;
    return {
      'id': session.customerId,
      'full_name': name,
      'email': email,
      'phone': phone,
      'date_of_birth': dob,
      'gender': gender,
    };
  }

  @override
  Future<void> logout(CustomerSession session) async {
    lastLoggedOutSession = session;
  }

  @override
  Future<List<Map<String, dynamic>>> listAddresses(
      CustomerSession session) async {
    return [
      {
        'id': 44,
        'label': 'Home',
        'recipient_name': 'Maya Customer',
        'recipient_phone': '+96170000000',
        'address_line_1': 'Hamra Street',
        'city': 'Beirut',
        'country': 'Lebanon',
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listOrders(CustomerSession session) async {
    return [
      {
        'id': 901,
        'order_number': 'SC-901',
        'status': 'preparing',
        'order_type': 'delivery',
        'total': '42.50',
        'items': [
          {
            'product_id': 1,
            'quantity': 1,
            'unit_price': '42.50',
          }
        ],
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listNotifications(
      CustomerSession session) async {
    return [
      {
        'id': 3,
        'title': 'Order update',
        'message': 'Your order is preparing.',
        'is_read': false,
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listSupportTickets(
      CustomerSession session) async {
    return [
      {
        'id': 88,
        'subject': 'Routine question',
        'category': 'product',
        'status': 'open',
        'message': 'Can I use this at night?',
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String message,
    String? category,
    List<Map<String, dynamic>>? attachments,
    CustomerSession? session,
  }) async {
    lastCreatedTicketCategory = category;
    return {
      'id': 99,
      'subject': subject,
      'category': category,
      'status': 'open',
      'message': message,
    };
  }

  @override
  Future<Map<String, dynamic>> replySupportTicket({
    required String ticketId,
    required String message,
    List<Map<String, dynamic>>? attachments,
    required CustomerSession session,
  }) async {
    lastRepliedTicketId = ticketId;
    lastRepliedMessage = message;
    return {
      'id': 101,
      'sender_type': 'customer',
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> uploadSupportAttachment({
    required String filePath,
    required String filename,
    required CustomerSession session,
  }) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> getSupportTicket({
    required String ticketId,
    required CustomerSession session,
  }) async {
    return {
      'id': ticketId,
      'subject': 'Routine question',
      'category': 'product',
      'status': 'open',
      'message': 'Can I use this at night?',
      'messages': [
        {
          'sender_type': 'customer',
          'message': 'Can I use this at night?',
          'created_at': '2026-05-30T12:00:00Z',
        },
        {
          'sender_type': 'admin',
          'message': 'Yes, you can use it at night.',
          'created_at': '2026-05-30T12:05:00Z',
        }
      ]
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listMyReviews(
      CustomerSession session) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> getOrder({
    required String orderId,
    required CustomerSession session,
  }) async {
    return {
      'id': 901,
      'order_number': orderId,
      'status': 'dispatched',
      'order_type': 'delivery',
      'grand_total': '42.50',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getOrderTimeline({
    required String orderId,
    required CustomerSession session,
  }) async {
    return [
      {
        'status': 'pending',
        'title': 'Order Placed',
        'description': 'Received by the store.',
      },
      {
        'status': 'dispatched',
        'title': 'Dispatched',
        'description': 'Courier is on the way.',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> createAddress({
    required CustomerSession session,
    required Map<String, dynamic> address,
  }) async {
    return {
      'id': 55,
      ...address,
    };
  }

  @override
  Future<void> deleteAddress({
    required CustomerSession session,
    required String addressId,
  }) async {}

  @override
  Future<Map<String, dynamic>> requestWholesaleAccess(String password) async {
    return {
      'wholesale_token': 'wholesale-token-fake',
      'minimum_order_amount': 250.0,
    };
  }

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String identifier) async {
    lastPasswordResetIdentifier = identifier;
    return {'submitted': true};
  }

  @override
  Future<List<Product>> listWholesaleProducts({
    required String wholesaleToken,
    int? branchId,
    String? search,
    String? categoryId,
  }) async {
    return const [];
  }

  @override
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
  }) async {
    lastCheckoutItems = List<CartItem>.from(items);
    lastCheckoutOrderType = orderType;
    return {
      'order_id': 'WHOLESALE-901',
      'order_number': 'WHOLESALE-901',
      'pricing': {
        'subtotal': 300.0,
        'delivery_fee': 0.0,
        'discount_amount': 0.0,
        'total': 300.0,
      }
    };
  }

  @override
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
  }) async {
    lastCheckoutItems = List<CartItem>.from(items);
    lastCheckoutOrderType = orderType;
    return {
      'order_id': 'CHECKOUT-901',
      'order_number': 'CHECKOUT-901',
      'pricing': {
        'subtotal': items.fold<double>(0, (sum, item) => sum + item.totalPrice),
        'delivery_fee': 0.0,
        'discount_amount': 0.0,
        'total': items.fold<double>(0, (sum, item) => sum + item.totalPrice),
      }
    };
  }
}

class FeatureAccessPriorityFakeStorefrontApi extends FakeStorefrontApi {
  @override
  Future<Map<String, dynamic>> getConfig() async {
    final config = await super.getConfig();
    config['app_settings'] = {
      'features': {
        'admin_catalog_products': true,
        'admin_catalog_brands': true,
        'admin_catalog_categories': true,
      },
    };
    config['feature_access'] = [
      {
        'feature_key': 'admin_catalog_products',
        'feature_is_active': 1,
        'store_is_active': 1,
        'can_view': 1,
      },
      {
        'feature_key': 'admin_catalog_brands',
        'feature_is_active': 1,
        'store_is_active': 0,
        'can_view': 0,
      },
    ];
    return config;
  }
}

class IndependentCatalogFeaturesFakeStorefrontApi extends FakeStorefrontApi {
  bool productsRequested = false;

  @override
  Future<Map<String, dynamic>> getConfig() async {
    final config = await super.getConfig();
    config['app_settings'] = {
      'features': {
        'admin_catalog_products': false,
        'admin_catalog_brands': true,
        'admin_catalog_categories': true,
        'admin_marketing_content': false,
        'admin_marketing_promotions': false,
        'admin_marketing_bundles': false,
      },
    };
    config['feature_access'] = [
      {
        'feature_key': 'admin_catalog_products',
        'feature_is_active': 1,
        'store_is_active': 0,
        'can_view': 0,
      },
      {
        'feature_key': 'admin_catalog_brands',
        'feature_is_active': 1,
        'store_is_active': 1,
        'can_view': 1,
      },
      {
        'feature_key': 'admin_catalog_categories',
        'feature_is_active': 1,
        'store_is_active': 1,
        'can_view': 1,
      },
    ];
    return config;
  }

  @override
  Future<List<Product>> listProducts({
    int? branchId,
    String? search,
    String? categoryId,
  }) async {
    productsRequested = true;
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listCategories({int? branchId}) async {
    return [
      {
        'id': 101,
        'name': 'Serums',
        'description': 'Live serum category',
        'image_url': '/uploads/categories/serums.webp',
        'product_count': 4,
      },
      {
        'id': 102,
        'name': 'Empty Category',
        'image_url': '/uploads/categories/empty.webp',
        'product_count': 0,
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listBrands({int? branchId}) async {
    return [
      {
        'id': 201,
        'name': 'Live Brand',
        'logo_url': '/uploads/brands/live.webp',
        'product_count': 2,
      },
      {
        'id': 202,
        'name': 'Empty Brand',
        'logo_url': '/uploads/brands/empty.webp',
        'product_count': 0,
      }
    ];
  }
}

class ToggleFeatureAccessFakeStorefrontApi
    extends IndependentCatalogFeaturesFakeStorefrontApi {
  bool enabled = true;

  @override
  Future<Map<String, dynamic>> getConfig() async {
    final config = await super.getConfig();
    config['feature_access'] = [
      {
        'feature_key': 'admin_catalog_products',
        'feature_is_active': 1,
        'store_is_active': 0,
        'can_view': 0,
      },
      {
        'feature_key': 'admin_catalog_brands',
        'feature_is_active': 1,
        'store_is_active': enabled ? 1 : 0,
        'can_view': enabled ? 1 : 0,
      },
      {
        'feature_key': 'admin_catalog_categories',
        'feature_is_active': 1,
        'store_is_active': enabled ? 1 : 0,
        'can_view': enabled ? 1 : 0,
      },
      {
        'feature_key': 'admin_marketing_content',
        'feature_is_active': 1,
        'store_is_active': enabled ? 1 : 0,
        'can_view': enabled ? 1 : 0,
      },
    ];
    return config;
  }

  @override
  Future<Map<String, dynamic>> getContent({int? branchId}) async {
    return {
      'banners': [
        {'id': 1, 'title': 'Live Banner', 'image_url': '/uploads/banner.webp'}
      ],
      'stories': [
        {
          'id': 2,
          'title': 'Live Story',
          'items': [
            {'media_url': '/uploads/story.webp', 'caption': 'Live'}
          ],
        }
      ],
    };
  }
}

class OfflineAuthFakeStorefrontApi extends FakeStorefrontApi {
  @override
  Future<Map<String, dynamic>> getConfig() async {
    throw const StorefrontApiException('Backend offline');
  }
}

class FailingReloadFakeStorefrontApi extends FakeStorefrontApi {
  bool shouldFailLists = false;

  @override
  Future<List<Map<String, dynamic>>> listCategories({int? branchId}) async {
    if (shouldFailLists) {
      throw const StorefrontApiException('Categories failed');
    }
    return [
      {
        'id': 301,
        'name': 'Live Category',
        'image_url': '/uploads/categories/live.webp',
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listBrands({int? branchId}) async {
    if (shouldFailLists) {
      throw const StorefrontApiException('Brands failed');
    }
    return [
      {'id': 401, 'name': 'Live Brand'}
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listPromotions({int? branchId}) async {
    if (shouldFailLists) {
      throw const StorefrontApiException('Promotions failed');
    }
    return [
      {'id': 501, 'title': 'Live Promotion'}
    ];
  }
}

const _stockedProduct = Product(
  id: '101',
  name: 'Barrier Cream',
  description: 'Barrier support cream.',
  shortDescription: 'Barrier support',
  price: 18.0,
  retailPrice: 24.0,
  wholesalePrice: 18.0,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('customer OTP verification hydrates live customer modules', () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);
    await appState.refreshStorefrontData();
    await appState.verifyCustomerOtp(
      identifier: 'maya@example.test',
      challenge: 'challenge',
      code: '123456',
    );

    expect(appState.isCustomerSignedIn, isTrue);
    expect(appState.profileName, 'Maya Customer');
    expect(appState.customerAddresses.single.id, '44');
    expect(appState.savedAddresses.single, contains('Hamra Street'));
    expect(appState.orders.single.id, 'SC-901');
    expect(appState.notifications.single['title'], 'Order update');
    expect(appState.tickets.single.title, 'Routine question');
  });

  test('registration creates backend account with phone profile details',
      () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);
    await appState.refreshStorefrontData();

    await appState.registerWithPassword(
      name: 'Maya Customer',
      phone: '+96170000000',
      dob: '1996-01-02',
      gender: 'female',
      password: 'super-secure-password',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(fakeApi.lastRegisteredName, 'Maya Customer');
    expect(fakeApi.lastRegisteredPhone, '+96170000000');
    expect(fakeApi.lastRegisteredDob, '1996-01-02');
    expect(fakeApi.lastRegisteredGender, 'female');
    expect(fakeApi.lastRegisteredPassword, 'super-secure-password');
    expect(prefs.getString('skin-cella_customer_identifier'), '+96170000000');
    expect(prefs.getString('skin-cella_customer_email'), isNull);
  });

  test('password login uses phone as identifier', () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);
    await appState.refreshStorefrontData();

    await appState.loginWithPassword(
      identifier: '+96170000000',
      password: 'super-secure-password',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(fakeApi.lastLoginIdentifier, '+96170000000');
    expect(fakeApi.lastLoginPassword, 'super-secure-password');
    expect(prefs.getString('skin-cella_customer_identifier'), '+96170000000');
  });

  test('sign out clears persisted customer credentials and scoped data',
      () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);
    await appState.refreshStorefrontData();
    await appState.verifyCustomerOtp(
      identifier: 'maya@example.test',
      challenge: 'challenge',
      code: '123456',
    );

    await appState.registerWithPassword(
      name: 'Maya Customer',
      email: 'maya@example.test',
      phone: '+96170000000',
      dob: '1996-01-02',
      gender: 'female',
      password: 'super-secure-password',
      backendSession: appState.customerSession,
    );

    await appState.signOutCustomer();

    final prefs = await SharedPreferences.getInstance();
    expect(fakeApi.lastLoggedOutSession?.customerId, 7);
    expect(appState.isCustomerSignedIn, isFalse);
    expect(prefs.getString('skin-cella_customer_token'), isNull);
    expect(prefs.getString('skin-cella_customer_identifier'), isNull);
    expect(prefs.getString('skin-cella_customer_email'), isNull);
    expect(prefs.getString('skin-cella_customer_password'), isNull);
    expect(appState.customerAddresses, isEmpty);
    expect(appState.cart, isEmpty);
    expect(appState.wishlist, isEmpty);
  });

  test('feature access rows override legacy app settings flags', () async {
    final appState = AppState(api: FeatureAccessPriorityFakeStorefrontApi());

    await appState.refreshStorefrontData();

    expect(appState.productsEnabled, isTrue);
    expect(appState.brandsEnabled, isFalse);
    expect(appState.categoriesEnabled, isFalse);
  });

  test('backend branding is cached and available before live refresh',
      () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);
    await appState.refreshStorefrontData();

    final cached = await AppState.loadCachedBranding('skin-cella');
    expect(cached?.primaryColor, '#006600');
    expect(cached?.backgroundColor, '#FAFFF8');

    final bootState = AppState(api: fakeApi, initialBranding: cached);
    expect(bootState.branding.primaryColor, '#006600');
    expect(bootState.branding.backgroundColor, '#FAFFF8');
  });

  test('category records preserve backend images and category names', () async {
    final appState =
        AppState(api: IndependentCatalogFeaturesFakeStorefrontApi());

    await appState.refreshStorefrontData();

    expect(appState.categories, ['All', 'Serums']);
    expect(appState.categoryRecords.single['id'], 101);
    expect(appState.categoryRecords.single['image_url'],
        '/uploads/categories/serums.webp');
    expect(appState.categoryRecords.map((entry) => entry['name']),
        isNot(contains('Empty Category')));
  });

  test('brands and categories load independently from product permission',
      () async {
    final fakeApi = IndependentCatalogFeaturesFakeStorefrontApi();
    final appState = AppState(api: fakeApi);

    await appState.refreshStorefrontData();

    expect(appState.productsEnabled, isFalse);
    expect(fakeApi.productsRequested, isFalse);
    expect(appState.categoriesEnabled, isTrue);
    expect(appState.categoryRecords.single['name'], 'Serums');
    expect(appState.brandsEnabled, isTrue);
    expect(appState.brands.single['name'], 'Live Brand');
    expect(appState.brands.map((entry) => entry['name']),
        isNot(contains('Empty Brand')));
  });

  test('disabled brand category and content permissions clear live data',
      () async {
    final fakeApi = ToggleFeatureAccessFakeStorefrontApi();
    final appState = AppState(api: fakeApi);

    await appState.refreshStorefrontData();
    expect(appState.categoryRecords, isNotEmpty);
    expect(appState.brands, isNotEmpty);
    expect(appState.banners, isNotEmpty);
    expect(appState.stories, isNotEmpty);

    fakeApi.enabled = false;
    await appState.refreshStorefrontData();

    expect(appState.categoriesEnabled, isFalse);
    expect(appState.categoryRecords, isEmpty);
    expect(appState.categories, ['All']);
    expect(appState.brandsEnabled, isFalse);
    expect(appState.brands, isEmpty);
    expect(appState.contentEnabled, isFalse);
    expect(appState.banners, isEmpty);
    expect(appState.stories, isEmpty);
  });

  test('backend offline auth does not create mock customer sessions', () async {
    final appState = AppState(api: OfflineAuthFakeStorefrontApi());
    await appState.refreshStorefrontData();

    await expectLater(
      appState.requestCustomerOtp('maya@example.test'),
      throwsA(isA<StorefrontApiException>()),
    );
    await expectLater(
      appState.verifyCustomerOtp(
        identifier: 'maya@example.test',
        challenge: 'challenge',
        code: '123456',
      ),
      throwsA(isA<StorefrontApiException>()),
    );
    await expectLater(
      appState.registerWithPassword(
        name: 'Maya Customer',
        phone: '+96170000000',
        dob: '1996-01-02',
        gender: 'female',
        password: 'super-secure-password',
      ),
      throwsA(isA<StorefrontApiException>()),
    );
    await expectLater(
      appState.loginWithPassword(
        identifier: '+96170000000',
        password: 'super-secure-password',
      ),
      throwsA(isA<StorefrontApiException>()),
    );
    expect(appState.isCustomerSignedIn, isFalse);
  });

  test('failed module reloads clear stale live storefront data', () async {
    final fakeApi = FailingReloadFakeStorefrontApi();
    final appState = AppState(api: fakeApi);

    await appState.refreshStorefrontData();
    expect(appState.categoryRecords, isNotEmpty);
    expect(appState.brands, isNotEmpty);
    expect(appState.promotions, isNotEmpty);

    fakeApi.shouldFailLists = true;
    await appState.refreshStorefrontData();

    expect(appState.categoryRecords, isEmpty);
    expect(appState.categories, ['All']);
    expect(appState.brands, isEmpty);
    expect(appState.promotions, isEmpty);
  });

  test('refreshOrder hydrates live timeline steps', () async {
    final appState = AppState(api: FakeStorefrontApi());
    await appState.refreshStorefrontData();
    await appState.verifyCustomerOtp(
      identifier: 'maya@example.test',
      challenge: 'challenge',
      code: '123456',
    );

    await appState.refreshOrder('SC-901');

    expect(appState.orders.single.status, 'Dispatched');
    expect(appState.timelineForOrder('SC-901'), hasLength(2));
    expect(appState.timelineForOrder('SC-901').last.title, 'Dispatched');
  });

  test('customer addresses can be created and removed through app state',
      () async {
    final appState = AppState(api: FakeStorefrontApi());
    await appState.refreshStorefrontData();
    await appState.verifyCustomerOtp(
      identifier: 'maya@example.test',
      challenge: 'challenge',
      code: '123456',
    );

    await appState.saveCustomerAddress(
      const CustomerAddress(
        id: '',
        label: 'Office',
        recipientName: 'Maya Customer',
        recipientPhone: '+96171111111',
        addressLine1: 'Digital District',
        city: 'Beirut',
        country: 'Lebanon',
      ),
    );

    expect(appState.customerAddresses.map((address) => address.id),
        contains('55'));
    expect(appState.savedAddresses, anyElement(contains('Digital District')));

    final created =
        appState.customerAddresses.firstWhere((address) => address.id == '55');
    await appState.deleteCustomerAddress(created);

    expect(appState.customerAddresses.map((address) => address.id),
        isNot(contains('55')));
  });

  test('support ticket category mapping maps correctly to backend and back',
      () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);
    await appState.refreshStorefrontData();
    await appState.verifyCustomerOtp(
      identifier: 'maya@example.test',
      challenge: 'challenge',
      code: '123456',
    );

    // Verify loading tickets maps category correctly from backend ('product' -> 'Product Advisory')
    expect(appState.tickets.single.category, 'Product Advisory');

    // Verify creating ticket maps category correctly to backend ('Fulfillment Case' -> 'delivery')
    await appState.createTicket(
        'Support Subject', 'Fulfillment Case', 'Message Body');
    expect(fakeApi.lastCreatedTicketCategory, 'delivery');
  });

  test('support ticket chat thread messages can be loaded and sent', () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);
    await appState.refreshStorefrontData();
    await appState.verifyCustomerOtp(
      identifier: 'maya@example.test',
      challenge: 'challenge',
      code: '123456',
    );

    // Initial check (from listSupportTickets list payload, no messages list was provided except general description)
    expect(appState.tickets.single.messages.length, 1);

    // Refresh details for single ticket ID 88 (simulating chat screen loading and polling)
    await appState.refreshTicketDetails('88');
    expect(appState.tickets.single.messages.length, 2);
    expect(appState.tickets.single.messages.first.content,
        'Can I use this at night?');
    expect(appState.tickets.single.messages.last.content,
        'Yes, you can use it at night.');
    expect(appState.tickets.single.messages.last.sender, 'admin');

    // Send a message inside the thread
    await appState.sendMessageToTicket('88', 'Thank you advisor!');
    expect(fakeApi.lastRepliedTicketId, '88');
    expect(fakeApi.lastRepliedMessage, 'Thank you advisor!');
  });

  test('wholesale mode toggles correctly and retains minimum order settings',
      () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);

    expect(appState.isWholesaleMode, isFalse);
    expect(appState.wholesaleMinOrderAmount, 0.0);

    await appState.requestWholesaleAccess('valid-passcode');

    expect(appState.isWholesaleMode, isTrue);
    expect(appState.wholesaleToken, 'wholesale-token-fake');
    expect(appState.wholesaleMinOrderAmount, 250.0);

    appState.leaveWholesaleMode();

    expect(appState.isWholesaleMode, isFalse);
    expect(appState.wholesaleToken, isNull);
    expect(appState.wholesaleMinOrderAmount, 0.0);
  });

  test('cart mutations refuse quantities above product stock', () async {
    final appState = AppState(api: FakeStorefrontApi());

    expect(appState.addToCart(_stockedProduct), isTrue);
    expect(appState.addToCart(_stockedProduct), isTrue);
    expect(appState.addToCart(_stockedProduct), isFalse);
    expect(appState.cart.single.quantity, 2);
    expect(appState.updateQuantity(_stockedProduct, 3), isFalse);
    expect(appState.cart.single.quantity, 2);
  });

  test('variant cart lines are distinct and enforce variant stock', () async {
    final appState = AppState(api: FakeStorefrontApi());
    const redVariant = ProductVariant(
      id: 'variant-red',
      name: 'Red',
      displayName: 'Red',
      price: 20.0,
      stockQuantity: 1,
    );
    const blueVariant = ProductVariant(
      id: 'variant-blue',
      name: 'Blue',
      displayName: 'Blue',
      price: 21.0,
      stockQuantity: 2,
    );
    const variantProduct = Product(
      id: 'variant-product',
      name: 'Variant Serum',
      description: 'Variant serum.',
      shortDescription: 'Variant serum',
      price: 18.0,
      imageUrl: '/uploads/products/variant.webp',
      category: 'Serums',
      stockQuantity: 3,
      rating: 4.8,
      reviewsCount: 9,
      skinTypes: ['All'],
      ingredients: 'Peptides',
      volume: '30ml',
      brand: 'Skin Cella',
      variants: [redVariant, blueVariant],
    );

    expect(appState.addToCart(variantProduct), isFalse);
    expect(appState.addToCart(variantProduct, variant: redVariant), isTrue);
    expect(appState.addToCart(variantProduct, variant: redVariant), isFalse);
    expect(appState.addToCart(variantProduct, variant: blueVariant), isTrue);
    expect(appState.addToCart(variantProduct, variant: blueVariant), isTrue);
    expect(appState.addToCart(variantProduct, variant: blueVariant), isFalse);

    expect(appState.cart, hasLength(2));
    expect(
        appState.cart.map((item) => item.cartKey),
        containsAll([
          'variant-product::variant-red',
          'variant-product::variant-blue',
        ]));
  });

  test('variant checkout lines keep selected variant id', () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);
    await appState.refreshStorefrontData();
    const variant = ProductVariant(
      id: 'variant-red-xl',
      name: 'Red XL',
      displayName: 'Red / XL',
      price: 21.0,
      stockQuantity: 4,
      attributes: [
        ProductAttribute(
          code: 'color',
          label: 'Color',
          value: 'red',
          displayValue: 'Red',
        ),
        ProductAttribute(
          code: 'size',
          label: 'Size',
          value: 'xl',
          displayValue: 'XL',
        ),
      ],
    );

    expect(appState.addToCart(_stockedProduct, variant: variant), isTrue);
    await appState.checkout('Pickup', 'Main Branch');

    expect(fakeApi.lastCheckoutItems, isNotNull);
    expect(fakeApi.lastCheckoutItems!.single.variant?.id, 'variant-red-xl');
    expect(fakeApi.lastCheckoutOrderType, 'pickup');
  });

  test('guest cart persists variant items in store-scoped storage and restores',
      () async {
    const variant = ProductVariant(
      id: 'variant-30ml',
      name: '30ml',
      displayName: '30ml',
      price: 19.0,
      stockQuantity: 2,
    );
    final firstState = AppState(api: FakeStorefrontApi());

    expect(firstState.addToCart(_stockedProduct, variant: variant), isTrue);
    await Future<void>.delayed(Duration.zero);

    final secondState = AppState(api: FakeStorefrontApi());
    await Future<void>.delayed(Duration.zero);

    expect(secondState.cart, hasLength(1));
    expect(secondState.cart.single.product.id, _stockedProduct.id);
    expect(secondState.cart.single.variant?.id, 'variant-30ml');
    expect(secondState.cart.single.quantity, 1);
  });

  test('guest cart persists in store-scoped storage and restores later',
      () async {
    final firstState = AppState(api: FakeStorefrontApi());

    expect(firstState.addToCart(_stockedProduct), isTrue);
    await Future<void>.delayed(Duration.zero);

    final secondState = AppState(api: FakeStorefrontApi());
    await Future<void>.delayed(Duration.zero);

    expect(secondState.cart, hasLength(1));
    expect(secondState.cart.single.product.id, _stockedProduct.id);
    expect(secondState.cart.single.quantity, 1);
  });

  test('password reset request uses admin approval endpoint', () async {
    final fakeApi = FakeStorefrontApi();
    final appState = AppState(api: fakeApi);
    await appState.refreshStorefrontData();

    await appState.requestPasswordReset('+96170000000');

    expect(fakeApi.lastPasswordResetIdentifier, '+96170000000');
  });

  test('product model preserves retail and wholesale prices', () {
    final product = Product.fromJson({
      'id': 88,
      'name': 'Wholesale Serum',
      'base_price': '22.50',
      'retail_price': '30.00',
      'wholesale_price': '22.50',
      'available_qty': 5,
    });

    expect(product.price, 22.5);
    expect(product.retailPrice, 30.0);
    expect(product.wholesalePrice, 22.5);
  });
}
