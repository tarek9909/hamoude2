import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront_template/models/product.dart';
import 'package:storefront_template/providers/app_state.dart';
import 'package:storefront_template/services/storefront_api.dart';

class FakeStorefrontApi extends StorefrontApi {
  FakeStorefrontApi()
      : super(
          baseUrl: 'http://example.test/api/v1/storefront',
          storeSlug: 'skin-cella',
        );

  @override
  Future<Map<String, dynamic>> getConfig() async {
    return {
      'store': {'slug': 'skin-cella', 'name': 'Skin Cella'},
      'app_settings': {
        'features': {
          'catalog': true,
          'admin_catalog_products': true,
          'orders': true,
          'admin_orders_all': true,
          'customers': true,
          'support': true,
          'notifications': true,
        },
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
      'email': 'maya@example.test',
    };
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
        'category': 'Product Advisory',
        'status': 'open',
        'message': 'Can I use this at night?',
      }
    ];
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('customer OTP verification hydrates live customer modules', () async {
    final appState = AppState(api: FakeStorefrontApi());
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

  test('refreshOrder hydrates live timeline steps', () async {
    final appState = AppState(api: FakeStorefrontApi());
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
}
