import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../services/storefront_api.dart';

String normalizeFullName(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length < 2 || normalized.length > 150) {
    throw ArgumentError('Enter a name between 2 and 150 characters.');
  }
  if (!RegExp(r"^[^0-9_!@#\$%^&*()+=\[\]{};:\\|,.<>/?`~]+$")
      .hasMatch(normalized)) {
    throw ArgumentError('Enter a valid name.');
  }
  return normalized;
}

String normalizePhoneNumber(String value) {
  var normalized = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (normalized.startsWith('00')) {
    normalized = '+${normalized.substring(2)}';
  }
  if (!normalized.startsWith('+')) {
    if (normalized.startsWith('961')) {
      normalized = '+$normalized';
    } else if (normalized.startsWith('0')) {
      normalized = '+961${normalized.substring(1)}';
    } else if (RegExp(r'^[378]\d{6,7}$').hasMatch(normalized)) {
      normalized = '+961$normalized';
    } else {
      normalized = '+$normalized';
    }
  }
  if (!RegExp(r'^\+\d{7,15}$').hasMatch(normalized)) {
    throw ArgumentError('Enter a valid phone number.');
  }
  return normalized;
}

class TicketMessage {
  final String sender; // 'customer' or 'staff'
  final String content;
  final DateTime timestamp;
  final List<Map<String, dynamic>> attachments;

  TicketMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
    this.attachments = const [],
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
    final status =
        (json['status'] ?? json['event_type'] ?? json['new_status'] ?? '')
            .toString();
    final description =
        (json['description'] ?? json['message'] ?? json['note'] ?? '')
            .toString();
    return OrderTimelineStep(
      status: _titleCase(status.isEmpty ? 'pending' : status),
      title: (json['title'] ?? json['label'] ?? _titleCase(status)).toString(),
      description: description,
      timestamp: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class AppState extends ChangeNotifier {
  final StorefrontApi api;
  final bool allowMockCheckoutFallback;

  AppState({
    StorefrontApi? api,
    StoreBranding? initialBranding,
    Map<String, dynamic>? initialConfig,
    this.allowMockCheckoutFallback = const bool.fromEnvironment(
      'ALLOW_MOCK_CHECKOUT_FALLBACK',
      defaultValue: false,
    ),
  }) : api = api ?? StorefrontApi() {
    if (initialBranding != null) {
      _branding = initialBranding;
    }
    _restoreCustomerSession();
    _fetchBackendConfig(initialConfig: initialConfig);
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
  double _deliveryCharge = 0.0;
  double get deliveryCharge => _deliveryCharge;

  final Map<String, bool> _featureFlags = {};
  bool _hasLiveFeatureConfig = false;
  bool isFeatureEnabled(String featureKey) =>
      _featureFlags[featureKey] ?? !_hasLiveFeatureConfig;
  bool get productsEnabled => isFeatureEnabled('admin_catalog_products');
  bool get brandsEnabled => isFeatureEnabled('admin_catalog_brands');
  bool get categoriesEnabled => isFeatureEnabled('admin_catalog_categories');
  bool get catalogEnabled => productsEnabled;
  bool get ordersEnabled => isFeatureEnabled('admin_orders_all');
  bool get checkoutEnabled => productsEnabled && ordersEnabled;
  bool get customersEnabled => isFeatureEnabled('admin_customers');
  // The account tab must remain reachable for guests even if optional customer
  // administration is disabled in the back office.
  bool get profileEnabled => true;
  bool get supportEnabled => isFeatureEnabled('admin_support');
  bool get reviewsEnabled => isFeatureEnabled('admin_reviews');
  bool get marketingContentEnabled =>
      isFeatureEnabled('admin_marketing_content');
  bool get contentEnabled => marketingContentEnabled;
  bool get promotionsEnabled => isFeatureEnabled('admin_marketing_promotions');
  bool get bundlesEnabled => isFeatureEnabled('admin_marketing_bundles');
  bool get deliveryEnabled => isFeatureEnabled('admin_fulfillment');
  bool get notificationsEnabled => isFeatureEnabled('admin_notifications');

  // Shared Tab Navigation Index
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  bool isTabEnabled(int index) {
    switch (index) {
      case 0:
        return true;
      case 1:
        return productsEnabled;
      case 2:
        return checkoutEnabled;
      case 3:
        return ordersEnabled;
      case 4:
        return true;
      default:
        return false;
    }
  }

  int get firstEnabledTabIndex {
    for (final index in const [0, 1, 2, 3, 4]) {
      if (isTabEnabled(index)) {
        return index;
      }
    }
    return 0;
  }

  void ensureCurrentTabIsEnabled() {
    if (!isTabEnabled(_currentTabIndex)) {
      _currentTabIndex = firstEnabledTabIndex;
    }
  }

  void setTabIndex(int index) {
    _currentTabIndex = isTabEnabled(index) ? index : firstEnabledTabIndex;
    notifyListeners();
  }

  void goToShopTab() => setTabIndex(0);

  bool goToCartTab() {
    if (!checkoutEnabled) {
      return false;
    }
    setTabIndex(2);
    return true;
  }

  // Profile Information
  String profileName = "";
  @Deprecated('Email is not used in the customer storefront.')
  String profileEmail = "";
  String profilePhone = "";
  String profileSkinConcern = "All";
  String profileDob = ""; // Legacy data; never displayed or submitted.
  String profileGender = ""; // Legacy data; never displayed or submitted.
  String? profileImageUrl;
  String? _accountPassword;
  String? get accountPassword => _accountPassword;

  final List<Map<String, dynamic>> _myReviews = [];
  List<Map<String, dynamic>> get myReviews => List.unmodifiable(_myReviews);

  CustomerSession? _customerSession;
  CustomerSession? get customerSession => _customerSession;
  bool get isCustomerSignedIn => _customerSession != null;

  bool _isWholesaleMode = false;
  bool get isWholesaleMode => _isWholesaleMode;

  String? _wholesaleToken;
  String? get wholesaleToken => _wholesaleToken;

  double _wholesaleMinOrderAmount = 0.0;
  double get wholesaleMinOrderAmount => _wholesaleMinOrderAmount;

  bool _wholesaleSettingsEnabled = false;
  bool get wholesaleEnabled =>
      _wholesaleSettingsEnabled && isFeatureEnabled('admin_catalog_wholesale');

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
  List<String> get categories =>
      List.unmodifiable(_categories.isEmpty ? const ['All'] : _categories);

  final List<Map<String, dynamic>> _categoryRecords = [];
  List<Map<String, dynamic>> get categoryRecords =>
      List.unmodifiable(_categoryRecords);

  final List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> get brands => List.unmodifiable(_brands);

  final List<Map<String, dynamic>> _promotions = [];
  List<Map<String, dynamic>> get promotions => List.unmodifiable(_promotions);

  /// Returns promotion info for a product if it's linked to any active promotion.
  /// Returns null if no promotion applies.
  /// Result: {'discountedPrice': double, 'discountLabel': String}
  Map<String, dynamic>? getPromotionForProduct(Product product) {
    if (!promotionsEnabled || _promotions.isEmpty) return null;

    for (final promo in _promotions) {
      final title =
          promo['name']?.toString() ?? promo['title']?.toString() ?? '';
      final discountType = promo['discount_type']?.toString() ?? 'percentage';
      final discountVal = (promo['discount_value'] as num?)?.toDouble() ?? 20.0;
      final discountLabel = promo['discount_label']?.toString() ??
          promo['badge']?.toString() ??
          (discountType == 'percentage'
              ? '-${discountVal.toStringAsFixed(0)}% OFF'
              : 'SPECIAL OFFER');

      final rawItems = promo['product_links'] as List? ?? [];
      bool matched = false;

      if (rawItems.isNotEmpty) {
        for (final link in rawItems) {
          final prodId = link['product_id']?.toString();
          if (Product.compareIds(product.id, prodId)) {
            matched = true;
            break;
          }
        }
      }

      // Fallback: match by name
      if (!matched && rawItems.isEmpty) {
        if (title.isNotEmpty &&
            product.name.toLowerCase() == title.toLowerCase()) {
          matched = true;
        }
      }

      if (matched) {
        double discPrice = product.price;
        final promoPriceStr = promo['price']?.toString();

        // If promotion has a single explicit price, use it
        if (promoPriceStr != null && double.tryParse(promoPriceStr) != null) {
          // Only use explicit promo price if this promo targets a single product
          final linkCount = rawItems.isNotEmpty ? rawItems.length : 1;
          if (linkCount == 1) {
            discPrice = double.parse(promoPriceStr);
          } else {
            if (discountType == 'percentage') {
              discPrice = product.price * (1 - discountVal / 100);
            } else {
              discPrice =
                  (product.price - discountVal).clamp(0.0, double.infinity);
            }
          }
        } else {
          if (discountType == 'percentage') {
            discPrice = product.price * (1 - discountVal / 100);
          } else {
            discPrice =
                (product.price - discountVal).clamp(0.0, double.infinity);
          }
        }

        return {
          'discountedPrice': discPrice,
          'discountLabel': discountLabel,
        };
      }
    }
    return null;
  }

  final List<Map<String, dynamic>> _bundles = [];
  List<Map<String, dynamic>> get bundles => List.unmodifiable(_bundles);

  final List<Map<String, dynamic>> _deliveryZones = [];
  List<Map<String, dynamic>> get deliveryZones =>
      List.unmodifiable(_deliveryZones);

  final List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> get reviews => List.unmodifiable(_reviews);

  final List<Map<String, dynamic>> _storeReviews = [];
  List<Map<String, dynamic>> get storeReviews =>
      List.unmodifiable(_storeReviews);

  List<Map<String, dynamic>> reviewsForProduct(String productId) {
    return _reviews.where((review) {
      final reviewProductId = review['product_id']?.toString();
      return reviewProductId != null &&
          Product.compareIds(reviewProductId, productId);
    }).toList(growable: false);
  }

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

  // Wishlist
  final List<Product> _wishlist = [];
  List<Product> get wishlist => _wishlist;

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
    if (query.isNotEmpty) {
      _currentTabIndex = 1; // Auto switch to Search Screen tab
    }
    notifyListeners();
  }

  // Filtered Products for Search
  List<Product> get filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == "All" ||
          product.category.toLowerCase() == _selectedCategory.toLowerCase();

      final matchesConcern = _selectedConcern == "All" ||
          product.skinTypes.any((concern) =>
              concern.toLowerCase() == _selectedConcern.toLowerCase()) ||
          product.description
              .toLowerCase()
              .contains(_selectedConcern.toLowerCase());

      return matchesSearch && matchesCategory && matchesConcern;
    }).toList();
  }

  // Filtered Products for general Catalog Browsing (independent of search query)
  List<Product> get catalogProducts {
    return _products.where((product) {
      final matchesCategory = _selectedCategory == "All" ||
          product.category.toLowerCase() == _selectedCategory.toLowerCase();

      final matchesConcern = _selectedConcern == "All" ||
          product.skinTypes.any((concern) =>
              concern.toLowerCase() == _selectedConcern.toLowerCase()) ||
          product.description
              .toLowerCase()
              .contains(_selectedConcern.toLowerCase());

      return matchesCategory && matchesConcern;
    }).toList();
  }

  // Cart Management
  int cartQuantityFor(Product product, {ProductVariant? variant}) {
    final variantId = variant?.id ?? '';
    final existingIndex = _cart.indexWhere(
      (item) =>
          Product.compareIds(item.product.id, product.id) &&
          item.variantId == variantId,
    );
    return existingIndex >= 0 ? _cart[existingIndex].quantity : 0;
  }

  bool canAddToCart(Product product,
      [int quantity = 1, ProductVariant? variant]) {
    if (product.variants.isNotEmpty && variant == null) {
      return false;
    }
    final stockQuantity = variant?.stockQuantity ?? product.stockQuantity;
    if (stockQuantity <= 0 || quantity <= 0) {
      return false;
    }
    return cartQuantityFor(product, variant: variant) + quantity <=
        stockQuantity;
  }

  bool addToCart(Product product, {int quantity = 1, ProductVariant? variant}) {
    if (!canAddToCart(product, quantity, variant)) {
      return false;
    }
    final variantId = variant?.id ?? '';
    final existingIndex = _cart.indexWhere(
      (item) =>
          Product.compareIds(item.product.id, product.id) &&
          item.variantId == variantId,
    );
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += quantity;
    } else {
      _cart.add(
          CartItem(product: product, variant: variant, quantity: quantity));
    }
    _saveCart();
    notifyListeners();
    return true;
  }

  void removeFromCart(Product product, {ProductVariant? variant}) {
    final variantId = variant?.id ?? '';
    _cart.removeWhere(
      (item) =>
          Product.compareIds(item.product.id, product.id) &&
          item.variantId == variantId,
    );
    _saveCart();
    notifyListeners();
  }

  void removeCartItem(CartItem cartItem) {
    _cart.removeWhere((item) => item.cartKey == cartItem.cartKey);
    _saveCart();
    notifyListeners();
  }

  bool updateQuantity(Product product, int quantity,
      {ProductVariant? variant}) {
    final variantId = variant?.id ?? '';
    final index = _cart.indexWhere(
      (item) =>
          Product.compareIds(item.product.id, product.id) &&
          item.variantId == variantId,
    );
    final stockQuantity = variant?.stockQuantity ?? product.stockQuantity;
    if (index >= 0) {
      if (quantity <= 0) {
        _cart.removeAt(index);
      } else if (quantity > stockQuantity) {
        return false;
      } else {
        _cart[index].quantity = quantity;
      }
      _saveCart();
      notifyListeners();
      return true;
    } else if (quantity > 0) {
      if (product.variants.isNotEmpty && variant == null) {
        return false;
      }
      if (quantity > stockQuantity) {
        return false;
      }
      _cart.add(
          CartItem(product: product, variant: variant, quantity: quantity));
      _saveCart();
      notifyListeners();
      return true;
    }
    return true;
  }

  bool updateCartItemQuantity(CartItem cartItem, int quantity) {
    return updateQuantity(cartItem.product, quantity,
        variant: cartItem.variant);
  }

  void clearCart() {
    _cart.clear();
    _saveCart();
    notifyListeners();
  }

  // ── Cart Persistence ──────────────────────────────────────────────────
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(_cart.map((item) => item.toJson()).toList());
      await prefs.setString(_storeScopedKey('customer_cart'), cartJson);
    } catch (e) {
      debugPrint('Failed to save cart: $e');
    }
  }

  Future<void> _restoreCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_storeScopedKey('customer_cart'));
      if (cartJson != null && cartJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cartJson);
        _cart.clear();
        for (final item in decoded) {
          try {
            _cart.add(CartItem.fromJson(item));
          } catch (_) {
            // Skip malformed cart items
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to restore cart: $e');
    }
  }

  // ── Wishlist Persistence ──────────────────────────────────────────────
  void toggleWishlist(Product product) {
    final index = _wishlist.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _wishlist.removeAt(index);
    } else {
      _wishlist.add(product);
    }
    _saveWishlist();
    notifyListeners();
  }

  bool isInWishlist(Product product) {
    return _wishlist.any((p) => p.id == product.id);
  }

  Future<void> _saveWishlist() async {
    if (_customerSession == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistJson =
          jsonEncode(_wishlist.map((p) => p.toJson()).toList());
      await prefs.setString(_storeScopedKey('customer_wishlist'), wishlistJson);
    } catch (e) {
      debugPrint('Failed to save wishlist: $e');
    }
  }

  Future<void> _restoreWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistJson =
          prefs.getString(_storeScopedKey('customer_wishlist'));
      if (wishlistJson != null && wishlistJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(wishlistJson);
        _wishlist.clear();
        for (final item in decoded) {
          try {
            _wishlist.add(Product.fromJson(item));
          } catch (_) {
            // Skip malformed items
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to restore wishlist: $e');
    }
  }

  double get cartSubtotal =>
      _cart.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get cartDeliveryFee => deliveryEnabled ? _deliveryCharge : 0.0;
  double get cartDiscount => 0.0;
  double get cartTotal => cartSubtotal + cartDeliveryFee - cartDiscount;
  double cartDeliveryFeeFor(String deliveryType) =>
      deliveryType.toLowerCase() == "delivery" ? cartDeliveryFee : 0.0;
  double cartTotalFor(String deliveryType) =>
      cartSubtotal + cartDeliveryFeeFor(deliveryType) - cartDiscount;

  Future<AppOrder?> checkout(String deliveryType, String address,
      {String? pickupTime}) async {
    if (_cart.isEmpty) return null;
    if (!checkoutEnabled) {
      throw Exception('Checkout is unavailable for this store');
    }
    if (deliveryType.toLowerCase() == 'delivery' && !deliveryEnabled) {
      throw Exception('Delivery is unavailable for this store');
    }

    _isCheckingOut = true;
    notifyListeners();

    final cartSnapshot = List<CartItem>.from(_cart);

    try {
      final Map<String, dynamic> result;
      if (_isWholesaleMode && _wholesaleToken != null) {
        result = await api.checkoutWholesale(
          wholesaleToken: _wholesaleToken!,
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
          pickupTime: pickupTime,
        );
      } else {
        result = await api.checkout(
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
          pickupTime: pickupTime,
        );
      }
      final pricing = result['pricing'] as Map<String, dynamic>?;
      final liveOrder = AppOrder(
        id: result['order_number']?.toString() ??
            result['order_id']?.toString() ??
            'SC-${DateTime.now().millisecondsSinceEpoch}',
        items: cartSnapshot,
        subtotal: _number(pricing?['subtotal'], cartSubtotal),
        deliveryFee: _number(pricing?['delivery_fee'], cartDeliveryFee),
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
  Future<void> loadSupportTickets() async {
    final session = _customerSession;
    if (session == null) return;
    if (!supportEnabled) {
      _tickets.clear();
      notifyListeners();
      return;
    }
    try {
      final ticketsData = await api.listSupportTickets(session);
      final newTickets = ticketsData.map(_ticketFromPayload).toList();

      bool hasChanged = newTickets.length != _tickets.length;
      if (!hasChanged) {
        for (int i = 0; i < newTickets.length; i++) {
          if (newTickets[i].id != _tickets[i].id ||
              newTickets[i].status != _tickets[i].status ||
              newTickets[i].messages.length != _tickets[i].messages.length) {
            hasChanged = true;
            break;
          }
        }
      }

      if (hasChanged) {
        _tickets
          ..clear()
          ..addAll(newTickets);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to load support tickets: $e");
    }
  }

  Future<void> createTicket(String title, String category, String description,
      {List<Map<String, dynamic>>? attachments}) async {
    if (!supportEnabled) {
      throw Exception('Customer support is unavailable for this store');
    }
    try {
      String mappedCategory = 'other';
      if (category == 'Product Advisory' || category == 'Product Issue') {
        mappedCategory = 'product';
      } else if (category == 'Fulfillment Case') {
        mappedCategory = 'delivery';
      } else if (category == 'Other') {
        mappedCategory = 'other';
      } else {
        mappedCategory = category.toLowerCase();
      }

      final ticketData = await api.createSupportTicket(
        subject: title,
        category: mappedCategory,
        message: description,
        attachments: attachments,
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

  Future<void> refreshTicketDetails(String ticketId) async {
    final session = _customerSession;
    if (session == null) return;
    if (!supportEnabled) return;
    try {
      final ticketData = await api.getSupportTicket(
        ticketId: ticketId,
        session: session,
      );
      if (ticketData.isNotEmpty) {
        final ticket = _ticketFromPayload(ticketData);
        final index = _tickets.indexWhere((t) => t.id == ticketId);
        if (index >= 0) {
          final oldTicket = _tickets[index];
          // Check if anything actually changed (messages count, status, or last message content)
          final hasChanged =
              oldTicket.messages.length != ticket.messages.length ||
                  oldTicket.status != ticket.status ||
                  (oldTicket.messages.isNotEmpty &&
                      ticket.messages.isNotEmpty &&
                      oldTicket.messages.last.content !=
                          ticket.messages.last.content);

          if (!hasChanged) {
            return;
          }
          _tickets[index] = ticket;
        } else {
          _tickets.add(ticket);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to refresh ticket details: $e");
    }
  }

  Future<void> sendMessageToTicket(String ticketId, String content,
      {List<Map<String, dynamic>>? attachments}) async {
    if (!supportEnabled) {
      throw const StorefrontApiException(
          "Customer support is unavailable for this store.");
    }
    final session = _customerSession;
    if (session == null) {
      throw const StorefrontApiException(
          "Must be signed in to send a support ticket message.");
    }

    try {
      await api.replySupportTicket(
        ticketId: ticketId,
        message: content,
        attachments: attachments,
        session: session,
      );
      await refreshTicketDetails(ticketId);
    } catch (e) {
      debugPrint("Storefront support reply failed: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadSupportAttachment(
      String filePath, String filename) async {
    if (!supportEnabled) {
      throw const StorefrontApiException(
          "Customer support is unavailable for this store.");
    }
    final session = _customerSession;
    if (session == null) {
      throw const StorefrontApiException(
          "Must be signed in to upload support attachments.");
    }
    return api.uploadSupportAttachment(
      filePath: filePath,
      filename: filename,
      session: session,
    );
  }

  Future<void> closeTicket(String ticketId) async {
    if (!supportEnabled) {
      throw const StorefrontApiException(
          "Customer support is unavailable for this store.");
    }
    final session = _customerSession;
    if (session == null) {
      throw const StorefrontApiException(
          "Must be signed in to close a support ticket.");
    }

    try {
      await api.closeSupportTicket(
        ticketId: ticketId,
        session: session,
      );
      await refreshTicketDetails(ticketId);
    } catch (e) {
      debugPrint("Storefront close ticket failed: $e");
      rethrow;
    }
  }

  Future<void> submitStoreReview(int rating, String title, String body) async {
    if (!reviewsEnabled) {
      throw Exception('Reviews are unavailable for this store');
    }
    final session = _customerSession;
    try {
      await api.createReview(
        rating: rating,
        title: title,
        body: body,
        session: session,
      );
      await loadCustomerData();
    } catch (e) {
      debugPrint("Submit store review failed: $e");
      rethrow;
    }
  }

  Future<void> submitTicketFeedback(
      String ticketId, int rating, String comment) async {
    if (!supportEnabled) {
      throw Exception('Customer support is unavailable for this store');
    }
    final session = _customerSession;
    try {
      await api.submitTicketFeedback(
        ticketId: ticketId,
        rating: rating,
        comment: comment,
        session: session,
      );
      await loadSupportTickets();
    } catch (e) {
      debugPrint("Submit ticket feedback failed: $e");
      rethrow;
    }
  }

  // Mark notification read
  Future<void> markNotificationRead(String id) async {
    if (!notificationsEnabled) return;
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

  void addLocalNotification({
    required String title,
    required String message,
    String actionType = 'support',
    String actionValue = '',
  }) {
    final notif = {
      'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'message': message,
      'time': 'Just now',
      'isRead': false,
      'actionType': actionType,
      'actionValue': actionValue,
    };
    _notifications.insert(0, notif);
    notifyListeners();
  }

  static String themeCacheKeyForStore(String storeSlug) =>
      '${storeSlug}_store_branding';

  static Future<StoreBranding?> loadCachedBranding(String storeSlug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(themeCacheKeyForStore(storeSlug));
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return StoreBranding.fromJson(decoded);
    } catch (e) {
      debugPrint('Storefront theme cache skipped: $e');
      return null;
    }
  }

  static Future<void> cacheBranding(
      String storeSlug, StoreBranding branding) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        themeCacheKeyForStore(storeSlug),
        jsonEncode(branding.toJson()),
      );
    } catch (e) {
      debugPrint('Storefront theme cache save skipped: $e');
    }
  }

  // Try fetching config from actual backend
  Future<void> _fetchBackendConfig(
      {Map<String, dynamic>? initialConfig}) async {
    _isLoadingConfig = true;
    notifyListeners();

    try {
      final config = initialConfig ?? await api.getConfig();
      _branding = StoreBranding.fromConfig(config, fallbackSlug: api.storeSlug);
      await cacheBranding(api.storeSlug, _branding);
      _featureFlags
        ..clear()
        ..addAll(_parseFeatureFlags(config));
      _hasLiveFeatureConfig = true;
      _deliveryCharge = _parseDeliveryCharge(config);

      // Parse wholesale settings if available in backend config
      final wsSettings = config['wholesale_settings'] as Map<String, dynamic>?;
      if (wsSettings != null) {
        _wholesaleSettingsEnabled =
            wsSettings['is_enabled'] == true || wsSettings['is_enabled'] == 1;
        _wholesaleMinOrderAmount =
            (wsSettings['minimum_order_amount'] as num?)?.toDouble() ?? 0.0;
      } else {
        _wholesaleSettingsEnabled = false;
      }
      _applyFeatureVisibilityRules();
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
      _hasLiveFeatureConfig = false;
      debugPrint("Storefront backend config unavailable: $e");
    } finally {
      _isLoadingConfig = false;
      notifyListeners();
    }
  }

  void _applyFeatureVisibilityRules() {
    if (!productsEnabled) {
      _products.clear();
      _cart.clear();
    }
    if (!categoriesEnabled) {
      _categories.clear();
      _categoryRecords.clear();
      if (_selectedCategory != 'All') {
        _selectedCategory = 'All';
      }
    }
    if (!brandsEnabled) {
      _brands.clear();
    }
    if (!contentEnabled) {
      _banners.clear();
      _stories.clear();
    }
    if (!promotionsEnabled) {
      _promotions.clear();
    }
    if (!bundlesEnabled) {
      _bundles.clear();
    }
    if (!deliveryEnabled) {
      _deliveryZones.clear();
    }
    if (!reviewsEnabled) {
      _reviews.clear();
      _storeReviews.clear();
      _myReviews.clear();
    }
    if (!supportEnabled) {
      _tickets.clear();
    }
    if (!notificationsEnabled) {
      _notifications.clear();
    }
    if (!ordersEnabled) {
      _orders.clear();
      _orderTimelines.clear();
      _cart.clear();
    }
    if (!wholesaleEnabled) {
      _isWholesaleMode = false;
      _wholesaleToken = null;
      _wholesaleMinOrderAmount = 0.0;
    }
    ensureCurrentTabIsEnabled();
  }

  Future<void> refreshStorefrontData() async {
    await _fetchBackendConfig();
    if (_customerSession != null) {
      await loadCustomerData();
    }
  }

  Future<void> requestWholesaleAccess(String password) async {
    try {
      final data = await api.requestWholesaleAccess(password);
      _wholesaleToken = data['wholesale_token']?.toString();
      _wholesaleMinOrderAmount =
          (data['minimum_order_amount'] as num?)?.toDouble() ?? 0.0;
      _isWholesaleMode = true;
      _cart.clear(); // Clear cart as retail prices no longer apply
      await _loadProductsForSelectedBranch(notify: false);
      notifyListeners();
    } catch (e) {
      debugPrint("Wholesale access request failed: $e");
      rethrow;
    }
  }

  void leaveWholesaleMode() {
    _isWholesaleMode = false;
    _wholesaleToken = null;
    _wholesaleMinOrderAmount = 0.0;
    _cart.clear(); // Clear cart as wholesale prices no longer apply
    _loadProductsForSelectedBranch(notify: false);
    notifyListeners();
  }

  Future<void> _loadProductsForSelectedBranch({bool notify = true}) async {
    if (!productsEnabled) {
      _products.clear();
      if (notify) {
        notifyListeners();
      }
      return;
    }

    if (!_isLiveBackendConnected && notify) {
      _products.clear();
      notifyListeners();
      return;
    }

    try {
      final List<Product> liveProducts;
      if (_isWholesaleMode && _wholesaleToken != null) {
        liveProducts = await api.listWholesaleProducts(
          wholesaleToken: _wholesaleToken!,
          branchId: selectedBranchId,
        );
      } else {
        liveProducts = await api.listProducts(branchId: selectedBranchId);
      }
      _products = liveProducts;
      _reconcileCartWithProducts();
      if (notify) {
        notifyListeners();
      }
    } catch (e) {
      _products.clear();
      if (notify) {
        notifyListeners();
      }
      debugPrint("Storefront catalog cleared after failed live load: $e");
    }
  }

  void _reconcileCartWithProducts() {
    if (_cart.isEmpty || _products.isEmpty) return;
    var changed = false;
    final reconciled = <CartItem>[];

    for (final item in _cart) {
      Product? liveProduct;
      for (final product in _products) {
        if (Product.compareIds(product.id, item.product.id)) {
          liveProduct = product;
          break;
        }
      }
      if (liveProduct == null) {
        changed = true;
        continue;
      }

      ProductVariant? liveVariant;
      if (item.variantId.isNotEmpty) {
        for (final variant in liveProduct.variants) {
          if (variant.id == item.variantId) {
            liveVariant = variant;
            break;
          }
        }
        if (liveVariant == null) {
          changed = true;
          continue;
        }
      } else if (liveProduct.variants.isNotEmpty) {
        changed = true;
        continue;
      }

      final stock = liveVariant?.stockQuantity ?? liveProduct.stockQuantity;
      if (stock <= 0) {
        changed = true;
        continue;
      }
      final quantity = item.quantity > stock ? stock : item.quantity;
      if (quantity != item.quantity ||
          liveProduct.id != item.product.id ||
          liveVariant?.id != item.variant?.id) {
        changed = true;
      }
      reconciled.add(CartItem(
        product: liveProduct,
        variant: liveVariant,
        quantity: quantity,
      ));
    }

    if (changed) {
      _cart
        ..clear()
        ..addAll(reconciled);
      _saveCart();
    }
  }

  Future<void> _loadCustomerModulesForSelectedBranch(
      {bool notify = true}) async {
    await Future.wait([
      if (productsEnabled) _loadProductsForSelectedBranch(notify: false),
      if (categoriesEnabled) _loadCategories(),
      if (brandsEnabled) _loadBrands(),
      if (contentEnabled) _loadContent(),
      if (promotionsEnabled) _loadPromotions(),
      if (bundlesEnabled) _loadBundles(),
      if (deliveryEnabled) _loadDeliveryZones(),
      if (reviewsEnabled) _loadReviews(),
      if (reviewsEnabled) _loadStoreReviews(),
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
      _banners.clear();
      _stories.clear();
      debugPrint("Storefront content cleared after failed live load: $e");
    }
  }

  Future<void> _loadCategories() async {
    if (!categoriesEnabled) {
      _categories.clear();
      _categoryRecords.clear();
      return;
    }
    try {
      final liveCategories =
          await api.listCategories(branchId: selectedBranchId);
      final visibleCategories =
          liveCategories.where(_recordHasProductsOrUnknown).toList();
      _categoryRecords
        ..removeWhere((category) => _recordKey(category).isNotEmpty)
        ..addAll(visibleCategories);
      _dedupeRecords(_categoryRecords);
      _categories
        ..clear()
        ..add('All')
        ..addAll(visibleCategories
            .map((category) => category['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty));
    } catch (e) {
      _categories.clear();
      _categoryRecords.clear();
      if (_selectedCategory != 'All') {
        _selectedCategory = 'All';
      }
      debugPrint("Storefront categories cleared after failed live load: $e");
    }
  }

  Future<void> _loadBrands() async {
    if (!brandsEnabled) {
      _brands.clear();
      return;
    }
    try {
      final liveBrands = await api.listBrands(branchId: selectedBranchId);
      final visibleBrands = liveBrands.where(_recordHasProductsOrUnknown);
      _brands
        ..removeWhere((brand) => _recordKey(brand).isNotEmpty)
        ..addAll(visibleBrands);
      _dedupeRecords(_brands);
    } catch (e) {
      _brands.clear();
      debugPrint("Storefront brands cleared after failed live load: $e");
    }
  }

  Future<void> _loadPromotions() async {
    if (!promotionsEnabled) {
      _promotions.clear();
      return;
    }
    try {
      final livePromos = await api.listPromotions(branchId: selectedBranchId);
      _promotions
        ..clear()
        ..addAll(livePromos);
    } catch (e) {
      _promotions.clear();
      debugPrint("Storefront promotions cleared after failed live load: $e");
    }
  }

  Future<void> _loadBundles() async {
    if (!bundlesEnabled) {
      _bundles.clear();
      return;
    }
    try {
      _bundles
        ..clear()
        ..addAll(await api.listBundles(branchId: selectedBranchId));
    } catch (e) {
      _bundles.clear();
      debugPrint("Storefront bundles cleared after failed live load: $e");
    }
  }

  Future<void> _loadDeliveryZones() async {
    if (!deliveryEnabled) {
      _deliveryZones.clear();
      return;
    }
    try {
      _deliveryZones
        ..clear()
        ..addAll(await api.listDeliveryZones(branchId: selectedBranchId));
    } catch (e) {
      _deliveryZones.clear();
      debugPrint(
          "Storefront delivery zones cleared after failed live load: $e");
    }
  }

  Future<void> _loadReviews() async {
    if (!reviewsEnabled) {
      _reviews.clear();
      return;
    }
    try {
      _reviews
        ..clear()
        ..addAll(await api.listReviews());
    } catch (e) {
      _reviews.clear();
      debugPrint("Storefront reviews cleared after failed live load: $e");
    }
  }

  Future<void> _loadStoreReviews() async {
    if (!reviewsEnabled) {
      _storeReviews.clear();
      return;
    }
    try {
      final all = _reviews.isNotEmpty ? _reviews : await api.listReviews();
      _storeReviews
        ..clear()
        ..addAll(all.where((r) => r['review_type'] == 'store'));
    } catch (e) {
      _storeReviews.clear();
      debugPrint("Store reviews load skipped: $e");
    }
  }

  Future<void> loadMyReviews() async {
    final session = _customerSession;
    if (session == null) return;
    if (!reviewsEnabled) {
      _myReviews.clear();
      notifyListeners();
      return;
    }
    try {
      final data = await api.listMyReviews(session);
      _myReviews
        ..clear()
        ..addAll(data);
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to load my reviews: $e");
    }
  }

  Future<void> loadPublicReviews() async {
    if (!reviewsEnabled) return;
    await _loadReviews();
    await _loadStoreReviews();
    notifyListeners();
  }

  Future<void> submitReview({
    String? productId,
    required int rating,
    String? title,
    String? body,
  }) async {
    if (!reviewsEnabled) {
      throw Exception('Reviews are unavailable for this store');
    }
    if (_customerSession == null) {
      throw Exception('Must be signed in to submit a review');
    }
    final review = await api.createReview(
      productId: productId,
      rating: rating,
      title: title,
      body: body,
      session: _customerSession,
    );
    if (review.isNotEmpty) {
      _myReviews.insert(0, review);
      if (productId != null) {
        _reviews.insert(0, review);
      } else {
        _storeReviews.insert(0, review);
      }
    }
    notifyListeners();
  }

  Future<void> deleteReview(int reviewId) async {
    if (!reviewsEnabled) {
      throw Exception('Reviews are unavailable for this store');
    }
    final session = _customerSession;
    if (session == null) {
      throw Exception('Must be signed in to delete a review');
    }
    await api.deleteReview(reviewId: reviewId, session: session);
    _myReviews.removeWhere((r) => r['id']?.toString() == reviewId.toString());
    _reviews.removeWhere((r) => r['id']?.toString() == reviewId.toString());
    _storeReviews
        .removeWhere((r) => r['id']?.toString() == reviewId.toString());
    notifyListeners();
  }

  Future<Map<String, dynamic>> requestCustomerOtp(String identifier,
      {bool checkExists = false, bool checkNotExists = false}) async {
    if (!_isLiveBackendConnected) {
      throw const StorefrontApiException(
          "Customer authentication is unavailable while the store backend is offline.");
    }
    return api.requestOtp(identifier,
        checkExists: checkExists, checkNotExists: checkNotExists);
  }

  Future<void> requestPasswordReset(String identifier) async {
    if (!_isLiveBackendConnected) {
      throw const StorefrontApiException(
          "Password reset requests are unavailable while the store backend is offline.");
    }
    await api.requestPasswordReset(identifier);
  }

  Future<void> verifyCustomerOtp({
    required String identifier,
    required String challenge,
    required String code,
    String? fullName,
  }) async {
    if (!_isLiveBackendConnected) {
      throw const StorefrontApiException(
          "Customer authentication is unavailable while the store backend is offline.");
    }
    final session = await api.verifyOtp(
      identifier: identifier,
      challenge: challenge,
      code: code,
      fullName: fullName ?? profileName,
    );
    if (session.customerId <= 0 || session.customerToken.isEmpty) {
      throw const StorefrontApiException(
          "Customer authentication did not return a valid session.");
    }
    _customerSession = session;
    profileEmail = identifier.contains("@") ? identifier : profileEmail;
    if (fullName != null && fullName.isNotEmpty) {
      profileName = fullName;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storeScopedKey('customer_id'), session.customerId);
    await prefs.setString(
        _storeScopedKey('customer_token'), session.customerToken);
    await prefs.setString(_storeScopedKey('customer_identifier'), identifier);
    if (!identifier.contains("@")) {
      profilePhone = identifier;
      await prefs.setString(_storeScopedKey('customer_phone'), identifier);
    }
    if (fullName != null && fullName.isNotEmpty) {
      await prefs.setString(_storeScopedKey('customer_name'), fullName);
    }
    await _restoreCart();
    await _restoreWishlist();
    notifyListeners();
    await loadCustomerData();
  }

  Future<void> signOutCustomer() async {
    final session = _customerSession;
    if (_isLiveBackendConnected && session != null) {
      try {
        await api.logout(session);
      } catch (e) {
        debugPrint("Storefront logout API failed; clearing local session: $e");
      }
    }

    _customerSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeScopedKey('customer_id'));
    await prefs.remove(_storeScopedKey('customer_token'));
    await prefs.remove(_storeScopedKey('customer_identifier'));
    await prefs.remove(_storeScopedKey('customer_email'));
    await prefs.remove(_storeScopedKey('customer_password'));
    await prefs.remove(_storeScopedKey('customer_dob'));
    await prefs.remove(_storeScopedKey('customer_gender'));
    await prefs.remove(_storeScopedKey('customer_profile_image'));
    await prefs.remove(_storeScopedKey('customer_name'));
    await prefs.remove(_storeScopedKey('customer_phone'));
    await prefs.remove(_storeScopedKey('customer_skin_concern'));
    await prefs.remove(_storeScopedKey('customer_wishlist'));

    // Reset profile fields
    profileName = "Store Customer";
    profileEmail = "";
    profilePhone = "";
    profileSkinConcern = "All";
    profileDob = "";
    profileGender = "";
    profileImageUrl = null;
    _accountPassword = null;

    // Clear all customer-scoped data to prevent cross-account leakage
    _tickets.clear();
    _notifications.clear();
    _myReviews.clear();
    _wishlist.clear();
    _customerAddresses.clear();
    _savedAddresses.clear();

    _isWholesaleMode = false;
    _wholesaleToken = null;
    _wholesaleMinOrderAmount = 0.0;

    notifyListeners();
  }

  Future<void> deleteCustomerAccount() async {
    final session = _customerSession;
    if (session == null) {
      throw Exception('Must be signed in to delete your account');
    }
    await api.deleteAccount(session);
    await signOutCustomer();
  }

  Future<void> refreshAllData() async {
    await Future.wait([
      _loadCustomerModulesForSelectedBranch(notify: false),
      loadCustomerData(),
    ]);
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
        profileEnabled
            ? api.getProfile(session)
            : Future.value(<String, dynamic>{}),
        profileEnabled
            ? api.listAddresses(session)
            : Future.value(<Map<String, dynamic>>[]),
        ordersEnabled
            ? api.listOrders(session)
            : Future.value(<Map<String, dynamic>>[]),
        notificationsEnabled
            ? api.listNotifications(session)
            : Future.value(<Map<String, dynamic>>[]),
        supportEnabled
            ? api.listSupportTickets(session)
            : Future.value(<Map<String, dynamic>>[]),
        reviewsEnabled
            ? api.listMyReviews(session)
            : Future.value(<Map<String, dynamic>>[]),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      final addresses = results[1] as List<Map<String, dynamic>>;
      final orders = results[2] as List<Map<String, dynamic>>;
      final liveNotifications = results[3] as List<Map<String, dynamic>>;
      final tickets = results[4] as List<Map<String, dynamic>>;

      if (profileEnabled) {
        final name =
            profile['full_name'] ?? profile['name'] ?? profile['customer_name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          profileName = name.toString();
        }
        final phone = profile['phone'];
        if (phone != null) {
          profilePhone = phone.toString();
        }
        final avatar = profile['profile_image_url'];
        if (avatar != null && avatar.toString().trim().isNotEmpty) {
          profileImageUrl = avatar.toString();
        }

        final prefs = await SharedPreferences.getInstance();
        if (name != null) {
          await prefs.setString(
              _storeScopedKey('customer_name'), name.toString());
        }
        if (phone != null) {
          await prefs.setString(
              _storeScopedKey('customer_phone'), phone.toString());
        }
        if (profileImageUrl != null) {
          await prefs.setString(
              _storeScopedKey('customer_profile_image'), profileImageUrl!);
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
      } else {
        _customerAddresses.clear();
        _savedAddresses.clear();
      }

      _orders
        ..clear()
        ..addAll(orders.map(_orderFromPayload));

      _notifications
        ..clear()
        ..addAll(liveNotifications.map(_notificationFromPayload));

      _tickets
        ..clear()
        ..addAll(tickets.map(_ticketFromPayload));

      final myReviewsData = results[5] as List<Map<String, dynamic>>;
      _myReviews
        ..clear()
        ..addAll(myReviewsData);
    } catch (e) {
      _customerAddresses.clear();
      _savedAddresses.clear();
      _orders.clear();
      _orderTimelines.clear();
      _notifications.clear();
      _tickets.clear();
      _myReviews.clear();
      debugPrint("Storefront customer data cleared after failed live load: $e");
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

  Future<void> cancelOrder(String orderId) async {
    final session = _customerSession;
    if (session == null) {
      throw Exception("Must be signed in to cancel an order");
    }

    try {
      final updatedPayload =
          await api.cancelOrder(orderId: orderId, session: session);
      if (updatedPayload.isNotEmpty) {
        final liveOrder = _orderFromPayload(updatedPayload);
        final index = _orders.indexWhere((order) => order.id == orderId);
        if (index >= 0) {
          _orders[index] = liveOrder;
        }
        notifyListeners();
      }
      await refreshOrder(orderId);
    } catch (e) {
      debugPrint("Storefront order cancellation failed: $e");
      rethrow;
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

      profileName =
          prefs.getString(_storeScopedKey('customer_name')) ?? profileName;
      profilePhone =
          prefs.getString(_storeScopedKey('customer_phone')) ?? profilePhone;
      profileSkinConcern =
          prefs.getString(_storeScopedKey('customer_skin_concern')) ??
              profileSkinConcern;
      profileImageUrl =
          prefs.getString(_storeScopedKey('customer_profile_image'));
      profileEmail = '';
      profileDob = '';
      profileGender = '';
      _accountPassword = null;
      await prefs.remove(_storeScopedKey('customer_email'));
      await prefs.remove(_storeScopedKey('customer_dob'));
      await prefs.remove(_storeScopedKey('customer_gender'));
      await prefs.remove(_storeScopedKey('customer_password'));

      await _restoreCart();

      // Reviews are now loaded from backend in loadCustomerData()

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
        } else if (identifier != null && identifier.isNotEmpty) {
          profilePhone = identifier;
        }
        await _restoreWishlist();
        notifyListeners();
        await loadCustomerData();
      }
    } catch (e) {
      debugPrint("Storefront customer session restore skipped: $e");
    }
  }

  Future<void> updateProfileData({
    required String name,
  }) async {
    final nextName = normalizeFullName(name);

    if (_isLiveBackendConnected && _customerSession != null) {
      try {
        final updatedProfile = await api.updateProfile(
          session: _customerSession!,
          name: nextName,
        );
        profileName = (updatedProfile['full_name'] ??
                updatedProfile['name'] ??
                updatedProfile['customer_name'] ??
                nextName)
            .toString();
      } catch (e) {
        debugPrint("Failed to update profile on backend: $e");
        rethrow;
      }
    }

    profileName = profileName.isEmpty ? nextName : profileName;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeScopedKey('customer_name'), profileName);
    } catch (e) {
      debugPrint("Failed to persist profile updates locally: $e");
    }

    notifyListeners();
  }

  Future<void> uploadProfileImage(String imagePath) async {
    final session = _customerSession;
    if (session == null) {
      throw StateError('Sign in to update your profile picture.');
    }
    final file = File(imagePath);
    final extension = imagePath.split('.').last.toLowerCase();
    const allowedExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    if (!allowedExtensions.contains(extension)) {
      throw ArgumentError('Choose a JPEG, PNG, GIF, or WebP image.');
    }
    if (!await file.exists() || await file.length() > 5 * 1024 * 1024) {
      throw ArgumentError('Choose an image smaller than 5 MB.');
    }
    final profile = await api.uploadProfileImage(
      session: session,
      filePath: imagePath,
    );
    final imageUrl = profile['profile_image_url']?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw const StorefrontApiException(
          'The profile picture could not be saved.');
    }
    profileImageUrl = api.resolveMediaUrl(imageUrl);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _storeScopedKey('customer_profile_image'), profileImageUrl!);
    } catch (e) {
      debugPrint("Failed to persist profile image locally: $e");
    }
    notifyListeners();
  }

  Future<void> removeProfileImage() async {
    final session = _customerSession;
    if (session == null) return;
    await api.removeProfileImage(session);
    profileImageUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeScopedKey('customer_profile_image'));
    notifyListeners();
  }

  Future<void> updatePassword(String newPassword) async {
    if (_isLiveBackendConnected && _customerSession != null) {
      try {
        await api.updateProfile(
          session: _customerSession!,
          name: profileName,
          password: newPassword,
        );
      } catch (e) {
        debugPrint("Failed to update password on backend: $e");
        rethrow;
      }
    }

    notifyListeners();
    await signOutCustomer();
  }

  Future<void> registerWithPassword({
    required String name,
    required String phone,
    required String password,
    CustomerSession? backendSession,
  }) async {
    CustomerSession? session = backendSession;
    final normalizedPhone = normalizePhoneNumber(phone);

    if (!_isLiveBackendConnected && session == null) {
      throw const StorefrontApiException(
          "Customer registration is unavailable while the store backend is offline.");
    }

    if (session == null) {
      try {
        session = await api.registerWithPhonePassword(
          name: normalizeFullName(name),
          phone: normalizedPhone,
          password: password,
        );
      } catch (e) {
        debugPrint("Backend phone registration failed: $e");
        rethrow;
      }
    }

    _customerSession = CustomerSession(
      customerId: session.customerId,
      customerToken: session.customerToken,
    );

    profileName = normalizeFullName(name);
    profileEmail = '';
    profilePhone = normalizedPhone;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storeScopedKey('customer_id'), session.customerId);
      await prefs.setString(
          _storeScopedKey('customer_token'), session.customerToken);
      await prefs.setString(
          _storeScopedKey('customer_identifier'), normalizedPhone);
      await prefs.setString(_storeScopedKey('customer_name'), profileName);
      await prefs.remove(_storeScopedKey('customer_email'));
      await prefs.setString(_storeScopedKey('customer_phone'), normalizedPhone);
      await prefs.remove(_storeScopedKey('customer_dob'));
      await prefs.remove(_storeScopedKey('customer_gender'));
      await prefs.remove(_storeScopedKey('customer_password'));
    } catch (e) {
      debugPrint("Failed to persist registration details locally: $e");
    }

    await _restoreCart();
    await _restoreWishlist();
    notifyListeners();
    await loadCustomerData();
  }

  Future<void> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    if (!_isLiveBackendConnected) {
      throw const StorefrontApiException(
          "Customer login is unavailable while the store backend is offline.");
    }

    try {
      final normalizedPhone = normalizePhoneNumber(phone);
      final session = await api.loginWithPassword(
        phone: normalizedPhone,
        password: password,
      );
      _customerSession = session;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storeScopedKey('customer_id'), session.customerId);
      await prefs.setString(
          _storeScopedKey('customer_token'), session.customerToken);
      await prefs.setString(
          _storeScopedKey('customer_identifier'), normalizedPhone);
      await prefs.remove(_storeScopedKey('customer_email'));
      profileEmail = '';
      profilePhone = normalizedPhone;
      await prefs.setString(_storeScopedKey('customer_phone'), normalizedPhone);
      await prefs.remove(_storeScopedKey('customer_password'));

      await _restoreCart();
      await _restoreWishlist();
      notifyListeners();
      await loadCustomerData();
    } catch (e) {
      debugPrint("Backend password login failed: $e");
      rethrow;
    }
  }

  // addCustomerReview has been replaced by submitReview() above.

  AppOrder _orderFromPayload(Map<String, dynamic> json) {
    final rawItems =
        (json['items'] as List?)?.whereType<Map<String, dynamic>>();
    final items = rawItems?.map((item) {
          final productId =
              (item['product_id'] ?? item['catalog_product_id'] ?? item['id'])
                  ?.toString();
          final unitPrice = _number(item['unit_price'], 0);
          final product = _products.firstWhere(
            (entry) => entry.id == productId,
            orElse: () => Product(
              id: productId ?? '',
              name: (item['product_name_snapshot'] ??
                      item['item_name_snapshot'] ??
                      item['product_name'] ??
                      item['name'] ??
                      'Product')
                  .toString(),
              description: '',
              shortDescription: '',
              price: unitPrice,
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
          final variantId = item['variant_id']?.toString() ?? '';
          final variant = variantId.isEmpty
              ? null
              : product.variants
                  .where((entry) => entry.id == variantId)
                  .cast<ProductVariant?>()
                  .firstWhere(
                    (entry) => entry != null,
                    orElse: () => ProductVariant(
                      id: variantId,
                      name: (item['variant_name_snapshot'] ??
                              item['variant_name'] ??
                              '')
                          .toString(),
                      displayName: (item['variant_name_snapshot'] ??
                              item['variant_name'] ??
                              'Variant')
                          .toString(),
                      sku: (item['sku_snapshot'] ?? item['sku'] ?? '')
                          .toString(),
                      price: unitPrice > 0 ? unitPrice : product.price,
                      stockQuantity: 1,
                      imageUrl: item['variant_image_url']?.toString() ?? '',
                    ),
                  );
          return CartItem(
            product: product,
            variant: variant,
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
                  attachments: (message['attachments'] is List)
                      ? (message['attachments'] as List)
                          .whereType<Map>()
                          .map((att) => Map<String, dynamic>.from(att))
                          .toList()
                      : [],
                ))
            .where((message) => message.content.isNotEmpty)
            .toList() ??
        [];

    return SupportTicket(
      id: (json['id'] ?? json['ticket_id'] ?? '').toString(),
      category: (() {
        final cat = (json['category'] ?? json['issue_category'] ?? 'Support')
            .toString();
        if (cat == 'product') return 'Product Advisory';
        if (cat == 'delivery') return 'Fulfillment Case';
        if (cat == 'other') return 'Other';
        return _titleCase(cat);
      })(),
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
      'actionType': (json['action_type'] ?? 'none').toString(),
      'actionValue': (json['action_value'] ?? '').toString(),
    };
  }

  String _storeScopedKey(String key) => '${api.storeSlug}_$key';
}

String _recordKey(Map<String, dynamic> record) {
  final id = record['id']?.toString().trim() ?? '';
  if (id.isNotEmpty) {
    return 'id:$id';
  }
  final name = record['name']?.toString().trim().toLowerCase() ?? '';
  return name.isEmpty ? '' : 'name:$name';
}

bool _recordHasProductsOrUnknown(Map<String, dynamic> record) {
  if (!record.containsKey('product_count')) {
    return true;
  }
  final rawCount = record['product_count'];
  final count = rawCount is num ? rawCount : num.tryParse(rawCount.toString());
  return count == null || count > 0;
}

void _dedupeRecords(List<Map<String, dynamic>> records) {
  final seen = <String>{};
  records.removeWhere((record) {
    final key = _recordKey(record);
    return key.isNotEmpty && !seen.add(key);
  });
}

Map<String, bool> _parseFeatureFlags(Map<String, dynamic> config) {
  final appSettings = (config['app_settings'] as Map<String, dynamic>?) ?? {};
  final rawFeatures = config['feature_access'] ??
      config['features'] ??
      appSettings['features'] ??
      appSettings['feature_flags'];
  final flags = <String, bool>{};

  if (rawFeatures is Map) {
    rawFeatures.forEach((key, value) {
      if (value is Map) {
        final isActive = _truthyFeatureFlag(
          value['feature_is_active'] ??
              value['store_is_active'] ??
              value['is_active'] ??
              value['enabled'] ??
              value['value'] ??
              true,
        );
        final canView = _truthyFeatureFlag(
          value['can_view'] ??
              (value['actions'] is Map
                  ? (value['actions'] as Map)['view']
                  : null) ??
              true,
        );
        flags[key.toString()] = isActive && canView;
      } else {
        flags[key.toString()] = _truthyFeatureFlag(value);
      }
    });
  }

  if (rawFeatures is List) {
    for (final item in rawFeatures) {
      if (item is String) {
        flags[item] = true;
      } else if (item is Map) {
        final key = item['feature_key'] ?? item['key'] ?? item['name'];
        if (key != null) {
          final isActive = _truthyFeatureFlag(
            item['feature_is_active'] ??
                item['store_is_active'] ??
                item['is_active'] ??
                item['enabled'] ??
                item['value'] ??
                true,
          );
          final canView = _truthyFeatureFlag(
            item['can_view'] ??
                (item['actions'] is Map
                    ? (item['actions'] as Map)['view']
                    : null) ??
                true,
          );
          flags[key.toString()] = isActive && canView;
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

double _parseDeliveryCharge(Map<String, dynamic> config) {
  final appSettings = (config['app_settings'] as Map<String, dynamic>?) ?? {};
  final settingsJson =
      (appSettings['settings_json'] as Map<String, dynamic>?) ?? {};
  return _number(
    settingsJson['delivery_charge'] ??
        appSettings['delivery_charge'] ??
        settingsJson['delivery_fee'] ??
        appSettings['delivery_fee'],
    0.0,
  );
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
