import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../services/storefront_api.dart';

class TicketMessage {
  final String sender; // 'customer' or 'staff'
  final String content;
  final DateTime timestamp;

  TicketMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
  });
}

class SupportTicket {
  final String id;
  final String category;
  final String title;
  final String description;
  final String status; // 'Open', 'In Progress', 'Resolved'
  final DateTime createdAt;
  final List<TicketMessage> messages;

  SupportTicket({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.messages,
  });
}

class AppOrder {
  final String id;
  final List<CartItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final String deliveryType; // 'Delivery' or 'Pickup'
  final String
      status; // 'Pending', 'Confirmed', 'Preparing', 'Ready', 'Dispatched', 'Delivered'
  final DateTime createdAt;
  final String address;

  AppOrder({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.deliveryType,
    required this.status,
    required this.createdAt,
    required this.address,
  });
}

class CustomerAddress {
  final String id;
  final String label;
  final String recipientName;
  final String recipientPhone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  const CustomerAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine1,
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = '',
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: (json['id'] ?? json['address_id'] ?? '').toString(),
      label: (json['label'] ?? 'Address').toString(),
      recipientName: (json['recipient_name'] ?? json['name'] ?? '').toString(),
      recipientPhone:
          (json['recipient_phone'] ?? json['phone'] ?? '').toString(),
      addressLine1: (json['address_line_1'] ?? json['line1'] ?? '').toString(),
      addressLine2: (json['address_line_2'] ?? json['line2'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      postalCode: (json['postal_code'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'label': label,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'address_line_1': addressLine1,
      if (addressLine2.isNotEmpty) 'address_line_2': addressLine2,
      if (city.isNotEmpty) 'city': city,
      if (state.isNotEmpty) 'state': state,
      if (postalCode.isNotEmpty) 'postal_code': postalCode,
      if (country.isNotEmpty) 'country': country,
    };
  }

  String get displayLabel {
    final parts = [
      if (label.isNotEmpty) label,
      addressLine1,
      addressLine2,
      city,
      state,
      country,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.join(', ');
  }
}

class OrderTimelineStep {
  final String status;
  final String title;
  final String description;
  final DateTime? timestamp;

  const OrderTimelineStep({
    required this.status,
    required this.title,
    required this.description,
    this.timestamp,
  });

  factory OrderTimelineStep.fromJson(Map<String, dynamic> json) {
    final status = (json['status'] ?? json['event_type'] ?? '').toString();
    return OrderTimelineStep(
      status: _titleCase(status.isEmpty ? 'pending' : status),
      title: (json['title'] ?? json['label'] ?? _titleCase(status)).toString(),
      description: (json['description'] ?? json['message'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class AppState extends ChangeNotifier {
  final StorefrontApi api;
  final bool allowMockCheckoutFallback;

  AppState({
    StorefrontApi? api,
    this.allowMockCheckoutFallback = const bool.fromEnvironment(
      'ALLOW_MOCK_CHECKOUT_FALLBACK',
      defaultValue: false,
    ),
  }) : api = api ?? StorefrontApi() {
    _restoreCustomerSession();
    _fetchBackendConfig();
  }

  // Loading States
  bool _isLoadingConfig = false;
  bool get isLoadingConfig => _isLoadingConfig;

  bool _isLiveBackendConnected = false;
  bool get isLiveBackendConnected => _isLiveBackendConnected;

  StoreBranding _branding = const StoreBranding(
    name: StorefrontApi.defaultStoreSlug,
    slug: StorefrontApi.defaultStoreSlug,
  );
  StoreBranding get branding => _branding;
  String get appName => _branding.name;
  String? get logoUrl => _branding.logoUrl;

  final Map<String, bool> _featureFlags = {};
  bool isFeatureEnabled(String featureKey) => _featureFlags[featureKey] ?? true;
  bool get catalogEnabled =>
      isFeatureEnabled('admin_catalog_products') && isFeatureEnabled('catalog');
  bool get checkoutEnabled =>
      catalogEnabled &&
      isFeatureEnabled('orders') &&
      isFeatureEnabled('admin_orders_all');
  bool get profileEnabled =>
      isFeatureEnabled('customers') || isFeatureEnabled('admin_customers');
  bool get supportEnabled =>
      isFeatureEnabled('support') || isFeatureEnabled('admin_support');
  bool get reviewsEnabled =>
      isFeatureEnabled('reviews') || isFeatureEnabled('admin_reviews');
  bool get marketingContentEnabled =>
      isFeatureEnabled('admin_marketing_content') ||
      isFeatureEnabled('marketing_content');
  bool get promotionsEnabled =>
      isFeatureEnabled('admin_marketing_promotions') ||
      isFeatureEnabled('promotions');
  bool get bundlesEnabled =>
      isFeatureEnabled('admin_marketing_bundles') ||
      isFeatureEnabled('bundles');
  bool get deliveryEnabled =>
      isFeatureEnabled('admin_fulfillment_zones') ||
      isFeatureEnabled('delivery_zones');

  // Shared Tab Navigation Index
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void goToShopTab() => setTabIndex(0);

  bool goToCartTab() {
    if (!checkoutEnabled) {
      return false;
    }
    setTabIndex(1);
    return true;
  }

  // Profile Information
  String profileName = "Store Customer";
  String profileEmail = "customer@example.com";
  CustomerSession? _customerSession;
  CustomerSession? get customerSession => _customerSession;
  bool get isCustomerSignedIn => _customerSession != null;

  bool _isLoadingCustomerData = false;
  bool get isLoadingCustomerData => _isLoadingCustomerData;

  bool _isCheckingOut = false;
  bool get isCheckingOut => _isCheckingOut;

  // Selected Branch
  String _selectedBranch = "Main Branch";
  String get selectedBranch => _selectedBranch;

  final List<StorefrontBranch> _branchRecords = [];
  List<StorefrontBranch> get branchRecords => List.unmodifiable(_branchRecords);

  final List<String> _branches = [
    "Main Branch",
  ];
  List<String> get branches => List.unmodifiable(_branches);

  final List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> get banners => List.unmodifiable(_banners);

  final List<Map<String, dynamic>> _stories = [];
  List<Map<String, dynamic>> get stories => List.unmodifiable(_stories);

  final List<String> _categories = [];
  List<String> get categories => List.unmodifiable(
      _categories.isEmpty ? const ['All'] : _categories);

  final List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> get brands => List.unmodifiable(_brands);

  final List<Map<String, dynamic>> _promotions = [
    {
      'name': 'The Cellular Renewal Complex',
      'image_url': 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?q=80&w=400&auto=format&fit=crop',
      'discount_label': '-20% OFF',
      'price': '43.20',
      'original_price': '54.00',
      'description': 'Our crowning formula with Swiss Alpine Rose stem cells and multi-peptides to instantly restore and plump.',
    },
    {
      'name': 'Alpine Purifying Gel',
      'image_url': 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?q=80&w=400&auto=format&fit=crop',
      'discount_label': '-25% OFF',
      'price': '24.00',
      'original_price': '32.00',
      'description': 'A delicate, low-foaming facial wash infused with natural wintergreen salicylic acid.',
    },
    {
      'name': 'Lipid Recovery Cream',
      'image_url': 'https://images.unsplash.com/photo-1601049541289-9b1b7bbbfe19?q=80&w=400&auto=format&fit=crop',
      'discount_label': '-15% OFF',
      'price': '40.85',
      'original_price': '48.00',
      'description': 'An intensely rich barrier replenishment moisturizer with deep sugarcane ceramides.',
    },
  ];
  List<Map<String, dynamic>> get promotions => List.unmodifiable(_promotions);

  final List<Map<String, dynamic>> _bundles = [];
  List<Map<String, dynamic>> get bundles => List.unmodifiable(_bundles);

  final List<Map<String, dynamic>> _deliveryZones = [];
  List<Map<String, dynamic>> get deliveryZones =>
      List.unmodifiable(_deliveryZones);

  final List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> get reviews => List.unmodifiable(_reviews);

  // Saved Addresses
  final List<String> _savedAddresses = [];
  List<String> get savedAddresses => List.unmodifiable(_savedAddresses);

  final List<CustomerAddress> _customerAddresses = [];
  List<CustomerAddress> get customerAddresses =>
      List.unmodifiable(_customerAddresses);

  // Simulated Notifications
  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);

  // Active Category & Skin Concerns
  String _selectedCategory = "All";
  String get selectedCategory => _selectedCategory;

  String _selectedConcern = "All";
  String get selectedConcern => _selectedConcern;

  // Search Query
  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  // Products
  List<Product> _products = [];
  List<Product> get products => _products;

  // Cart
  final List<CartItem> _cart = [];
  List<CartItem> get cart => _cart;

  // Orders
  final List<AppOrder> _orders = [];
  List<AppOrder> get orders => _orders;

  final Map<String, List<OrderTimelineStep>> _orderTimelines = {};
  List<OrderTimelineStep> timelineForOrder(String orderId) =>
      List.unmodifiable(_orderTimelines[orderId] ?? const []);

  // Support Tickets
  final List<SupportTicket> _tickets = [];
  List<SupportTicket> get tickets => _tickets;

  void setBranch(String branch) {
    _selectedBranch = branch;
    notifyListeners();
    _loadCustomerModulesForSelectedBranch();
  }

  int get selectedBranchId {
    if (_branchRecords.isEmpty) {
      return 1;
    }

    return _branchRecords
        .firstWhere(
          (branch) => branch.name == _selectedBranch,
          orElse: () => _branchRecords.first,
        )
        .id;
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setConcern(String concern) {
    _selectedConcern = concern;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Filtered Products
  List<Product> get filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == "All" || product.category == _selectedCategory;

      final matchesConcern = _selectedConcern == "All" ||
          product.skinTypes.any((concern) =>
              concern.toLowerCase() == _selectedConcern.toLowerCase()) ||
          product.description
              .toLowerCase()
              .contains(_selectedConcern.toLowerCase());

      return matchesSearch && matchesCategory && matchesConcern;
    }).toList();
  }

  // Cart Management
  void addToCart(Product product) {
    final existingIndex =
        _cart.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity++;
    } else {
      _cart.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    _cart.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  void updateQuantity(Product product, int quantity) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      if (quantity <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  double get cartSubtotal =>
      _cart.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get cartDeliveryFee => cartSubtotal > 75.0 ? 0.0 : 10.0;
  double get cartDiscount => cartSubtotal > 100.0 ? cartSubtotal * 0.15 : 0.0;
  double get cartTotal => cartSubtotal + cartDeliveryFee - cartDiscount;

  // Checkout
  Future<AppOrder?> checkout(String deliveryType, String address) async {
    if (_cart.isEmpty) return null;

    _isCheckingOut = true;
    notifyListeners();

    final cartSnapshot = List<CartItem>.from(_cart);

    try {
      final result = await api.checkout(
        branchId: selectedBranchId,
        items: cartSnapshot,
        orderType:
            deliveryType.toLowerCase() == "delivery" ? "delivery" : "pickup",
        customerId: _customerSession?.customerId,
        customerToken: _customerSession?.customerToken,
        deliveryAddressId: deliveryType.toLowerCase() == "delivery"
            ? _addressIdForLabel(address)
            : null,
        deliveryZoneId: deliveryType.toLowerCase() == "delivery" &&
                _deliveryZones.isNotEmpty
            ? (_deliveryZones.first['id'] as num?)?.toInt()
            : null,
        notes: address,
      );
      final pricing = result['pricing'] as Map<String, dynamic>?;
      final liveOrder = AppOrder(
        id: result['order_number']?.toString() ??
            result['order_id']?.toString() ??
            'SC-${DateTime.now().millisecondsSinceEpoch}',
        items: cartSnapshot,
        subtotal: _number(pricing?['subtotal'], cartSubtotal),
        deliveryFee:
            _number(pricing?['delivery_fee'], cartDeliveryFee),
        discount: _number(pricing?['discount_amount'], cartDiscount),
        total: _number(pricing?['total'], cartTotal),
        deliveryType: deliveryType,
        status: "Pending",
        createdAt: DateTime.now(),
        address: address,
      );
      _orders.insert(0, liveOrder);
      _cart.clear();
      notifyListeners();
      return liveOrder;
    } catch (e) {
      debugPrint("Storefront checkout failed: $e");
      rethrow;
    } finally {
      _isCheckingOut = false;
      notifyListeners();
    }
  }

  // Support System
  Future<void> createTicket(
      String title, String category, String description) async {
    try {
      final ticketData = await api.createSupportTicket(
        subject: title,
        category: category,
        message: description,
        session: _customerSession,
      );
      if (_customerSession != null) {
        await loadCustomerData();
      } else {
        if (ticketData.isNotEmpty) {
          final ticket = _ticketFromPayload(ticketData);
          _tickets.insert(0, ticket);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Storefront support ticket failed: $e");
      rethrow;
    }
  }

  Future<void> sendMessageToTicket(String ticketId, String content) async {
    final session = _customerSession;
    if (session == null) {
      throw const StorefrontApiException(
          "Must be signed in to send a support ticket message.");
    }

    try {
      await api.replySupportTicket(
        ticketId: ticketId,
        message: content,
        session: session,
      );
      await loadCustomerData();
    } catch (e) {
      debugPrint("Storefront support reply failed: $e");
      rethrow;
    }
  }

  // Mark notification read
  Future<void> markNotificationRead(String id) async {
    final index = _notifications.indexWhere((n) => n['id'] == id);
    if (index >= 0) {
      _notifications[index]['isRead'] = true;
      notifyListeners();
    }

    if (_customerSession != null && !id.startsWith('mock-')) {
      try {
        await api.markNotificationRead(
          notificationId: id,
          session: _customerSession!,
        );
      } catch (e) {
        debugPrint("Storefront notification read kept local: $e");
      }
    }
  }

  // Try fetching config from actual backend
  Future<void> _fetchBackendConfig() async {
    _isLoadingConfig = true;
    notifyListeners();

    try {
      final config = await api.getConfig();
      _branding = StoreBranding.fromConfig(config, fallbackSlug: api.storeSlug);
      _featureFlags
        ..clear()
        ..addAll(_parseFeatureFlags(config));
      final liveBranches = (config['branches'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(StorefrontBranch.fromJson)
              .where((branch) => branch.id > 0)
              .toList() ??
          [];
      if (liveBranches.isNotEmpty) {
        _branchRecords
          ..clear()
          ..addAll(liveBranches);
        _branches
          ..clear()
          ..addAll(liveBranches.map((branch) => branch.name));
        _selectedBranch = _branches.first;
      }
      await _loadCustomerModulesForSelectedBranch(notify: false);
      _isLiveBackendConnected = true;
      debugPrint(
          "Connected to dashboard backend storefront config for ${api.storeSlug}.");
    } catch (e) {
      _isLiveBackendConnected = false;
      debugPrint("Running in beautiful standalone mock mode: $e");
    } finally {
      _isLoadingConfig = false;
      notifyListeners();
    }
  }

  Future<void> _loadProductsForSelectedBranch({bool notify = true}) async {
    if (!_isLiveBackendConnected && notify) {
      return;
    }

    try {
      final liveProducts = await api.listProducts(branchId: selectedBranchId);
      if (liveProducts.isNotEmpty) {
        _products = liveProducts;
        if (notify) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Storefront catalog kept in local fallback mode: $e");
    }
  }

  Future<void> _loadCustomerModulesForSelectedBranch(
      {bool notify = true}) async {
    await Future.wait([
      if (catalogEnabled) _loadProductsForSelectedBranch(notify: false),
      if (catalogEnabled) _loadCategories(),
      if (catalogEnabled) _loadBrands(),
      if (marketingContentEnabled) _loadContent(),
      if (promotionsEnabled) _loadPromotions(),
      if (bundlesEnabled) _loadBundles(),
      if (deliveryEnabled) _loadDeliveryZones(),
      if (reviewsEnabled) _loadReviews(),
    ]);

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _loadContent() async {
    try {
      final content = await api.getContent(branchId: selectedBranchId);
      _banners
        ..clear()
        ..addAll(
            (content['banners'] as List?)?.whereType<Map<String, dynamic>>() ??
                []);
      _stories
        ..clear()
        ..addAll(
            (content['stories'] as List?)?.whereType<Map<String, dynamic>>() ??
                []);
    } catch (e) {
      debugPrint("Storefront content kept in local fallback mode: $e");
    }
  }

  Future<void> _loadCategories() async {
    try {
      final liveCategories =
          await api.listCategories(branchId: selectedBranchId);
      _categories
        ..clear()
        ..add('All')
        ..addAll(liveCategories
            .map((category) => category['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty));
    } catch (e) {
      debugPrint("Storefront categories kept in local fallback mode: $e");
    }
  }

  Future<void> _loadBrands() async {
    try {
      _brands
        ..clear()
        ..addAll(await api.listBrands(branchId: selectedBranchId));
    } catch (e) {
      debugPrint("Storefront brands kept in local fallback mode: $e");
    }
  }

  Future<void> _loadPromotions() async {
    try {
      final livePromos = await api.listPromotions(branchId: selectedBranchId);
      if (livePromos.isNotEmpty) {
        _promotions
          ..clear()
          ..addAll(livePromos);
      }
    } catch (e) {
      debugPrint("Storefront promotions kept in local fallback mode: $e");
    }
  }

  Future<void> _loadBundles() async {
    try {
      _bundles
        ..clear()
        ..addAll(await api.listBundles(branchId: selectedBranchId));
    } catch (e) {
      debugPrint("Storefront bundles kept in local fallback mode: $e");
    }
  }

  Future<void> _loadDeliveryZones() async {
    try {
      _deliveryZones
        ..clear()
        ..addAll(await api.listDeliveryZones(branchId: selectedBranchId));
    } catch (e) {
      debugPrint("Storefront delivery zones kept in local fallback mode: $e");
    }
  }

  Future<void> _loadReviews() async {
    try {
      _reviews
        ..clear()
        ..addAll(await api.listReviews(branchId: selectedBranchId));
    } catch (e) {
      debugPrint("Storefront reviews kept in local fallback mode: $e");
    }
  }

  Future<Map<String, dynamic>> requestCustomerOtp(String identifier) {
    return api.requestOtp(identifier);
  }

  Future<void> verifyCustomerOtp({
    required String identifier,
    required String challenge,
    required String code,
  }) async {
    final session = await api.verifyOtp(
      identifier: identifier,
      challenge: challenge,
      code: code,
      fullName: profileName,
    );
    if (session.customerId <= 0 || session.customerToken.isEmpty) {
      throw const StorefrontApiException(
          "Customer authentication did not return a valid session.");
    }
    _customerSession = session;
    profileEmail = identifier.contains("@") ? identifier : profileEmail;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storeScopedKey('customer_id'), session.customerId);
    await prefs.setString(
        _storeScopedKey('customer_token'), session.customerToken);
    await prefs.setString(_storeScopedKey('customer_identifier'), identifier);
    notifyListeners();
    await loadCustomerData();
  }

  Future<void> signOutCustomer() async {
    _customerSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeScopedKey('customer_id'));
    await prefs.remove(_storeScopedKey('customer_token'));
    await prefs.remove(_storeScopedKey('customer_identifier'));
    profileEmail = "customer@example.com";
    notifyListeners();
  }

  Future<void> loadCustomerData() async {
    final session = _customerSession;
    if (session == null) {
      return;
    }

    _isLoadingCustomerData = true;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        api.getProfile(session),
        api.listAddresses(session),
        api.listOrders(session),
        api.listNotifications(session),
        api.listSupportTickets(session),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      final addresses = results[1] as List<Map<String, dynamic>>;
      final orders = results[2] as List<Map<String, dynamic>>;
      final liveNotifications = results[3] as List<Map<String, dynamic>>;
      final tickets = results[4] as List<Map<String, dynamic>>;

      final name = profile['full_name'] ??
          profile['name'] ??
          profile['customer_name'] ??
          profile['email'];
      if (name != null && name.toString().trim().isNotEmpty) {
        profileName = name.toString();
      }
      final email = profile['email'] ?? profile['identifier'];
      if (email != null && email.toString().trim().isNotEmpty) {
        profileEmail = email.toString();
      }

      final mappedAddresses = addresses
          .map(CustomerAddress.fromJson)
          .where((address) => address.addressLine1.trim().isNotEmpty)
          .toList();
      if (mappedAddresses.isNotEmpty) {
        _customerAddresses
          ..clear()
          ..addAll(mappedAddresses);
        _savedAddresses
          ..clear()
          ..addAll(mappedAddresses.map((address) => address.displayLabel));
      }

      final legacyAddressLabels = addresses
          .map((address) => CustomerAddress.fromJson(address).displayLabel)
          .where((address) => address.trim().isNotEmpty)
          .toList();
      if (mappedAddresses.isEmpty && legacyAddressLabels.isNotEmpty) {
        _savedAddresses
          ..clear()
          ..addAll(legacyAddressLabels);
      }

      if (orders.isNotEmpty) {
        _orders
          ..clear()
          ..addAll(orders.map(_orderFromPayload));
      }

      if (liveNotifications.isNotEmpty) {
        _notifications
          ..clear()
          ..addAll(liveNotifications.map(_notificationFromPayload));
      }

      if (tickets.isNotEmpty) {
        _tickets
          ..clear()
          ..addAll(tickets.map(_ticketFromPayload));
      }
    } catch (e) {
      debugPrint("Storefront customer data kept in local fallback mode: $e");
    } finally {
      _isLoadingCustomerData = false;
      notifyListeners();
    }
  }

  Future<void> refreshOrder(String orderId) async {
    final session = _customerSession;
    if (session == null) {
      return;
    }

    try {
      final responses = await Future.wait<dynamic>([
        api.getOrder(orderId: orderId, session: session),
        api.getOrderTimeline(orderId: orderId, session: session),
      ]);
      final payload = responses[0] as Map<String, dynamic>;
      final timeline = responses[1] as List<Map<String, dynamic>>;
      final liveOrder = _orderFromPayload(payload);
      final index = _orders.indexWhere((order) => order.id == orderId);
      if (index >= 0) {
        _orders[index] = liveOrder;
      } else {
        _orders.insert(0, liveOrder);
      }
      _orderTimelines[orderId] =
          timeline.map(OrderTimelineStep.fromJson).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Storefront order detail kept local: $e");
    }
  }

  Future<void> saveCustomerAddress(CustomerAddress address) async {
    final session = _customerSession;
    if (session == null) {
      _upsertLocalAddress(address);
      return;
    }

    final saved = address.id.isEmpty
        ? await api.createAddress(
            session: session, address: address.toPayload())
        : await api.updateAddress(
            session: session,
            addressId: address.id,
            address: address.toPayload(),
          );
    _upsertLocalAddress(CustomerAddress.fromJson(saved));
    notifyListeners();
  }

  Future<void> deleteCustomerAddress(CustomerAddress address) async {
    final session = _customerSession;
    if (session != null && address.id.isNotEmpty) {
      await api.deleteAddress(session: session, addressId: address.id);
    }
    _customerAddresses.removeWhere((entry) =>
        entry.id.isNotEmpty && entry.id == address.id ||
        entry.displayLabel == address.displayLabel);
    _savedAddresses
      ..clear()
      ..addAll(_customerAddresses.map((entry) => entry.displayLabel));
    if (_savedAddresses.isEmpty) {
      _savedAddresses.add("100 Market Street, Suite 12");
    }
    notifyListeners();
  }

  void _upsertLocalAddress(CustomerAddress address) {
    final normalized = address.id.isEmpty
        ? CustomerAddress(
            id: 'local-${DateTime.now().millisecondsSinceEpoch}',
            label: address.label,
            recipientName: address.recipientName,
            recipientPhone: address.recipientPhone,
            addressLine1: address.addressLine1,
            addressLine2: address.addressLine2,
            city: address.city,
            state: address.state,
            postalCode: address.postalCode,
            country: address.country,
          )
        : address;
    final index = _customerAddresses.indexWhere((entry) =>
        entry.id.isNotEmpty && entry.id == normalized.id ||
        entry.displayLabel == normalized.displayLabel);
    if (index >= 0) {
      _customerAddresses[index] = normalized;
    } else {
      _customerAddresses.add(normalized);
    }
    _savedAddresses
      ..clear()
      ..addAll(_customerAddresses.map((entry) => entry.displayLabel));
  }

  int? _addressIdForLabel(String label) {
    final match = _customerAddresses.where((address) {
      return address.displayLabel == label && int.tryParse(address.id) != null;
    }).toList();
    return match.isEmpty ? null : int.tryParse(match.first.id);
  }

  Future<void> _restoreCustomerSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getInt(_storeScopedKey('customer_id'));
      final customerToken = prefs.getString(_storeScopedKey('customer_token'));
      final identifier =
          prefs.getString(_storeScopedKey('customer_identifier'));
      if (customerId != null &&
          customerId > 0 &&
          customerToken != null &&
          customerToken.isNotEmpty) {
        _customerSession = CustomerSession(
          customerId: customerId,
          customerToken: customerToken,
        );
        if (identifier != null && identifier.contains("@")) {
          profileEmail = identifier;
        }
        notifyListeners();
        await loadCustomerData();
      }
    } catch (e) {
      debugPrint("Storefront customer session restore skipped: $e");
    }
  }



  AppOrder _orderFromPayload(Map<String, dynamic> json) {
    final rawItems =
        (json['items'] as List?)?.whereType<Map<String, dynamic>>();
    final items = rawItems?.map((item) {
          final productId =
              (item['product_id'] ?? item['catalog_product_id'] ?? item['id'])
                  ?.toString();
          final product = _products.firstWhere(
            (entry) => entry.id == productId,
            orElse: () => Product(
              id: productId ?? '',
              name: (item['item_name_snapshot'] ??
                      item['product_name'] ??
                      item['name'] ??
                      'Product')
                  .toString(),
              description: '',
              price: _number(item['unit_price'], 0),
              imageUrl: item['image_url']?.toString() ?? '',
              category: 'General',
              stockQuantity: 1,
              rating: 4.5,
              reviewsCount: 0,
              skinTypes: const ['All Skintypes'],
              ingredients: '',
              volume: '',
              brand: '',
            ),
          );
          return CartItem(
            product: product,
            quantity: _number(item['quantity'], 1).toInt(),
          );
        }).toList() ??
        [];

    final pricing = (json['pricing'] as Map<String, dynamic>?) ?? json;
    return AppOrder(
      id: (json['order_number'] ??
              json['order_code'] ??
              json['id'] ??
              json['order_id'] ??
              'Order')
          .toString(),
      items: items,
      subtotal: _number(pricing['subtotal'], 0),
      deliveryFee: _number(pricing['delivery_fee'], 0),
      discount: _number(pricing['discount_amount'] ?? pricing['discount'], 0),
      total: _number(pricing['total'] ?? pricing['grand_total'], 0),
      deliveryType: _titleCase(json['order_type']?.toString() ?? 'Delivery'),
      status: _titleCase(json['status']?.toString() ?? 'Pending'),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      address: (json['address'] ??
              json['delivery_address'] ??
              json['delivery_address_snapshot'] ??
              selectedBranch)
          .toString(),
    );
  }

  SupportTicket _ticketFromPayload(Map<String, dynamic> json) {
    final rawMessages =
        (json['messages'] as List?)?.whereType<Map<String, dynamic>>();
    final messages = rawMessages
            ?.map((message) => TicketMessage(
                  sender:
                      (message['sender_type'] ?? message['sender'] ?? 'staff')
                          .toString(),
                  content: (message['message'] ?? message['content'] ?? '')
                      .toString(),
                  timestamp: DateTime.tryParse(
                          message['created_at']?.toString() ?? '') ??
                      DateTime.now(),
                ))
            .where((message) => message.content.isNotEmpty)
            .toList() ??
        [];

    return SupportTicket(
      id: (json['id'] ?? json['ticket_id'] ?? '').toString(),
      category:
          (json['category'] ?? json['issue_category'] ?? 'Support').toString(),
      title: (json['subject'] ?? json['title'] ?? 'Support request').toString(),
      description: (json['description'] ?? json['message'] ?? '').toString(),
      status: _titleCase(json['status']?.toString() ?? 'Open'),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      messages: messages.isEmpty
          ? [
              TicketMessage(
                sender: 'customer',
                content:
                    (json['description'] ?? json['message'] ?? '').toString(),
                timestamp:
                    DateTime.tryParse(json['created_at']?.toString() ?? '') ??
                        DateTime.now(),
              )
            ]
          : messages,
    );
  }

  Map<String, dynamic> _notificationFromPayload(Map<String, dynamic> json) {
    final readAt = json['read_at'];
    final isReadValue = json['is_read'];
    return {
      'id': (json['id'] ?? json['notification_id'] ?? '').toString(),
      'title': (json['title'] ?? 'Notification').toString(),
      'message': (json['message'] ?? json['body'] ?? '').toString(),
      'time': _relativeTime(json['created_at']?.toString()),
      'isRead': readAt != null ||
          (isReadValue is bool
              ? isReadValue
              : ['true', '1', 'yes']
                  .contains(isReadValue?.toString().toLowerCase().trim())),
    };
  }

  String _storeScopedKey(String key) => '${api.storeSlug}_$key';
}

Map<String, bool> _parseFeatureFlags(Map<String, dynamic> config) {
  final appSettings = (config['app_settings'] as Map<String, dynamic>?) ?? {};
  final rawFeatures = appSettings['features'] ??
      appSettings['feature_flags'] ??
      config['feature_access'] ??
      config['features'];
  final flags = <String, bool>{};

  if (rawFeatures is Map) {
    rawFeatures.forEach((key, value) {
      flags[key.toString()] = _truthyFeatureFlag(value);
    });
  }

  if (rawFeatures is List) {
    for (final item in rawFeatures) {
      if (item is String) {
        flags[item] = true;
      } else if (item is Map) {
        final key = item['feature_key'] ?? item['key'] ?? item['name'];
        if (key != null) {
          flags[key.toString()] = _truthyFeatureFlag(
            item['store_is_active'] ??
                item['is_active'] ??
                item['enabled'] ??
                item['value'] ??
                true,
          );
        }
      }
    }
  }

  return flags;
}

bool _truthyFeatureFlag(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = value?.toString().toLowerCase().trim();
  return !['false', '0', 'disabled', 'off', 'no'].contains(normalized);
}


double _number(dynamic value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String _titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

String _relativeTime(String? value) {
  final timestamp = DateTime.tryParse(value ?? '');
  if (timestamp == null) {
    return 'Just now';
  }
  final diff = DateTime.now().difference(timestamp);
  if (diff.inDays > 0) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  if (diff.inHours > 0) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  if (diff.inMinutes > 0) {
    return '${diff.inMinutes} min ago';
  }
  return 'Just now';
}
