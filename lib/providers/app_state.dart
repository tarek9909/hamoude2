import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_quote.dart';
import '../models/delivery_zone.dart';
import '../models/product.dart';
import '../services/storefront_api.dart';

export '../models/cart_quote.dart';
export '../models/delivery_zone.dart';

const sessionExpiredNotice = 'Your session expired. Please sign in again.';

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

String normalizeUsername(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9](?:[a-z0-9._-]{1,28}[a-z0-9])?$')
      .hasMatch(normalized)) {
    throw ArgumentError(
        'Username must be 3-30 characters and use letters, numbers, dots, underscores, or hyphens.');
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
  final String fulfillmentMode;
  final String preorderEtaText;
  final String splitFromOrderNumber;

  /// The branch the order belongs to (pickup location for pickup orders).
  final String branchName;

  /// The customer's own note for the store, if any.
  final String notes;

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
    this.fulfillmentMode = 'standard',
    this.preorderEtaText = '',
    this.splitFromOrderNumber = '',
    this.branchName = '',
    this.notes = '',
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

  /// The street address without the label, e.g. for order summaries.
  String get formattedAddress {
    return [addressLine1, addressLine2, city, state, postalCode, country]
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
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

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final StorefrontApi api;
  final bool allowMockCheckoutFallback;
  static const _catalogRefreshInterval = Duration(seconds: 60);
  Timer? _catalogRefreshTimer;
  DateTime? _lastAutomaticCatalogRefresh;
  bool _isAutomaticCatalogRefreshRunning = false;

  AppState({
    StorefrontApi? api,
    StoreBranding? initialBranding,
    Map<String, dynamic>? initialConfig,
    this.allowMockCheckoutFallback = const bool.fromEnvironment(
      'ALLOW_MOCK_CHECKOUT_FALLBACK',
      defaultValue: false,
    ),
  }) : api = api ?? StorefrontApi() {
    WidgetsBinding.instance.addObserver(this);
    _catalogRefreshTimer = Timer.periodic(_catalogRefreshInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _onPeriodicRefresh();
      }
    });
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
  bool _isReconnecting = false;

  /// True while the product catalog for the branch is loading for the first
  /// time (not during silent background refreshes).
  bool _isCatalogLoading = true;
  bool get isCatalogLoading => _isCatalogLoading;

  /// A one-time message for the UI, e.g. after an expired session forced a
  /// sign-out. Call [clearSessionNotice] once it has been shown.
  String? _sessionNotice;
  String? get sessionNotice => _sessionNotice;
  void clearSessionNotice() {
    if (_sessionNotice == null) return;
    _sessionNotice = null;
    notifyListeners();
  }

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
  String profileUsername = "";
  @Deprecated('Email is not used in the customer storefront.')
  String profileEmail = "";
  String profilePhone = "";
  String profileSkinConcern = "All";
  String profileDob = ""; // Legacy data; never displayed or submitted.
  String profileGender = ""; // Legacy data; never displayed or submitted.
  String? profileImageUrl;
  String? _accountPassword;
  @Deprecated('Passwords are never stored locally; use changePassword, which '
      'verifies the current password on the server.')
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
      final discountVal =
          double.tryParse(promo['discount_value']?.toString() ?? '');
      final discountLabel = promo['discount_label']?.toString() ??
          promo['badge']?.toString() ??
          (discountType == 'percentage' && discountVal != null
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
        final promoPrice = double.tryParse(promo['price']?.toString() ?? '');
        final linkCount = rawItems.isNotEmpty ? rawItems.length : 1;

        // A single explicit promo price only applies to single-product promos.
        if (promoPrice != null && linkCount == 1) {
          discPrice = promoPrice;
        } else if (discountVal != null) {
          if (discountType == 'percentage') {
            discPrice = product.price * (1 - discountVal / 100);
          } else {
            discPrice =
                (product.price - discountVal).clamp(0.0, double.infinity);
          }
        } else {
          // No discount data from the backend: never invent one.
          continue;
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

  final List<DeliveryZone> _deliveryZones = [];
  List<DeliveryZone> get deliveryZones => List.unmodifiable(_deliveryZones);

  String? _selectedDeliveryZoneId;

  /// The zone sent with delivery orders. Defaults to the first zone for the
  /// selected branch.
  DeliveryZone? get selectedDeliveryZone {
    if (_deliveryZones.isEmpty) return null;
    for (final zone in _deliveryZones) {
      if (zone.id == _selectedDeliveryZoneId) return zone;
    }
    final branchId = selectedBranchId;
    for (final zone in _deliveryZones) {
      if (zone.branchId == branchId) return zone;
    }
    for (final zone in _deliveryZones) {
      if (zone.servesBranch(branchId)) return zone;
    }
    return _deliveryZones.first;
  }

  String? get selectedDeliveryZoneId => selectedDeliveryZone?.id;

  void selectDeliveryZone(String id) {
    if (!_deliveryZones.any((zone) => zone.id == id)) return;
    if (_selectedDeliveryZoneId == id) return;
    _selectedDeliveryZoneId = id;
    _invalidateCartQuote();
    notifyListeners();
  }

  /// False when the store has delivery disabled or no active zones, since the
  /// backend rejects delivery orders without a zone.
  bool get deliveryAvailable => deliveryEnabled && _deliveryZones.isNotEmpty;

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

  /// The saved address whose [CustomerAddress.displayLabel] (or id) is
  /// [label], or null.
  CustomerAddress? addressForLabel(String label) {
    for (final address in _customerAddresses) {
      if (address.displayLabel == label || address.id == label) {
        return address;
      }
    }
    return null;
  }

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

  // Home "All Products" feed, loaded page by page from the backend
  static const int _homeProductsPerPage = 20;
  final List<Product> _homeProducts = [];
  List<Product> get homeProducts => _homeProducts;
  int _homeProductsPage = 0;
  int _homeProductsTotal = 0;
  int get homeProductsTotal => _homeProductsTotal;
  bool _homeProductsHasMore = true;
  bool get homeProductsHasMore => _homeProductsHasMore;
  bool _isLoadingHomeProducts = false;
  bool get isLoadingHomeProducts => _isLoadingHomeProducts;
  int _homeProductsRequestId = 0;

  /// True after the last home-feed page failed to load. While set, scroll
  /// triggered loads are throttled with a backoff; call [retryHomeProducts]
  /// from a retry button.
  bool _homeProductsLoadFailed = false;
  bool get homeProductsLoadFailed => _homeProductsLoadFailed;
  int _homeProductsFailures = 0;
  DateTime? _homeProductsRetryAt;

  Future<void> retryHomeProducts() {
    _homeProductsRetryAt = null;
    return loadHomeProducts(reset: _homeProducts.isEmpty);
  }

  Future<void> loadHomeProducts({bool reset = false}) async {
    if (!productsEnabled) return;
    if (!reset && (_isLoadingHomeProducts || !_homeProductsHasMore)) return;
    final retryAt = _homeProductsRetryAt;
    if (!reset && retryAt != null && DateTime.now().isBefore(retryAt)) {
      return;
    }

    final requestId = ++_homeProductsRequestId;
    final nextPage = reset ? 1 : _homeProductsPage + 1;
    _isLoadingHomeProducts = true;
    notifyListeners();

    try {
      final result = await api.listProductsPage(
        page: nextPage,
        perPage: _homeProductsPerPage,
        branchId: selectedBranchId,
        wholesaleToken: _isWholesaleMode ? _wholesaleToken : null,
        excludePreorder: true,
      );
      // A newer reset (branch switch, refresh) superseded this request.
      if (requestId != _homeProductsRequestId) return;

      if (reset) _homeProducts.clear();
      final seenIds = _homeProducts.map((product) => product.id).toSet();
      _homeProducts.addAll(result.items.where(
        (product) => !product.isPreorder && seenIds.add(product.id),
      ));
      _homeProductsPage = nextPage;
      _homeProductsTotal = result.total;
      _homeProductsHasMore = result.hasMore;
      _homeProductsLoadFailed = false;
      _homeProductsFailures = 0;
      _homeProductsRetryAt = null;
    } catch (e) {
      if (requestId == _homeProductsRequestId) {
        _homeProductsLoadFailed = true;
        _homeProductsFailures++;
        final delaySeconds = min(60, 1 << min(_homeProductsFailures, 6));
        _homeProductsRetryAt =
            DateTime.now().add(Duration(seconds: delaySeconds));
      }
      debugPrint("Failed to load home products page $nextPage: $e");
    } finally {
      if (requestId == _homeProductsRequestId) {
        _isLoadingHomeProducts = false;
        notifyListeners();
      }
    }
  }

  /// Replaces home-feed items with their refreshed versions without
  /// resetting pagination, so a background refresh never jumps the feed back
  /// to page 1.
  void _refreshHomeProductsInPlace() {
    if (_homeProducts.isEmpty) {
      unawaited(loadHomeProducts(reset: true));
      return;
    }
    final liveById = {for (final product in _products) product.id: product};
    for (var i = _homeProducts.length - 1; i >= 0; i--) {
      final live = liveById[_homeProducts[i].id];
      if (live == null || live.isPreorder) {
        _homeProducts.removeAt(i);
      } else {
        _homeProducts[i] = live;
      }
    }
  }

  // Cart
  final List<CartItem> _cart = [];
  List<CartItem> get cart => _cart;
  bool get cartHasPreorder => _cart.any((item) => item.isPreorder);
  bool get cartHasItems => _cart.isNotEmpty;

  static const _openPreorderMaxQuantity = 99;

  /// The highest quantity [item] may reach in the bag: the pre-order limit
  /// for pre-orders, otherwise the available stock.
  int maxCartQuantityFor(CartItem item) {
    if (item.isPreorder) {
      return item.product.preorderMaxQuantity ?? _openPreorderMaxQuantity;
    }
    return item.stockQuantity < 0 ? 0 : item.stockQuantity;
  }

  // Server-side cart pricing
  CartQuote? _cartQuote;
  CartQuote? get cartQuote => _cartQuote;
  bool _isQuotingCart = false;
  bool get isQuotingCart => _isQuotingCart;
  Timer? _cartQuoteDebounce;
  int _cartQuoteRequestId = 0;
  static const _cartQuoteDebounceDuration = Duration(milliseconds: 400);

  String _fulfillmentType = 'delivery';

  /// 'delivery' or 'pickup'; used to price the cart quote.
  String get fulfillmentType => _fulfillmentType;
  void setFulfillmentType(String type) {
    final normalized =
        type.toLowerCase().trim() == 'pickup' ? 'pickup' : 'delivery';
    if (normalized == _fulfillmentType) return;
    _fulfillmentType = normalized;
    _invalidateCartQuote();
    notifyListeners();
  }

  /// Drops the current quote and schedules a debounced refresh.
  void _invalidateCartQuote() {
    _cartQuote = null;
    _cartQuoteDebounce?.cancel();
    if (_cart.isEmpty) {
      _cartQuoteRequestId++;
      _isQuotingCart = false;
      return;
    }
    _cartQuoteDebounce =
        Timer(_cartQuoteDebounceDuration, () => refreshCartQuote());
  }

  /// Prices the bag on the server (promotions, bundles, tax, delivery fee).
  Future<void> refreshCartQuote() async {
    _cartQuoteDebounce?.cancel();
    if (_cart.isEmpty || !_isLiveBackendConnected || !checkoutEnabled) {
      if (_cartQuote != null || _isQuotingCart) {
        _cartQuote = null;
        _isQuotingCart = false;
        notifyListeners();
      }
      return;
    }

    final requestId = ++_cartQuoteRequestId;
    var orderType =
        cartHasPreorder || !deliveryEnabled ? 'pickup' : _fulfillmentType;
    int? zoneId;
    if (orderType == 'delivery') {
      zoneId = selectedDeliveryZone?.numericId;
      // The backend refuses delivery quotes without a zone.
      if (zoneId == null) orderType = 'pickup';
    }
    final session = _customerSession;
    _isQuotingCart = true;
    notifyListeners();

    try {
      final data = await api.quoteCart(
        branchId: selectedBranchId,
        items: List<CartItem>.from(_cart),
        orderType: orderType,
        deliveryZoneId: zoneId,
        session: session,
        wholesaleToken: _isWholesaleMode ? _wholesaleToken : null,
      );
      if (requestId != _cartQuoteRequestId) return;
      _cartQuote = CartQuote.fromJson(data, orderType: orderType);
    } catch (e) {
      if (requestId != _cartQuoteRequestId) return;
      _cartQuote = null;
      if (session != null) {
        await _handleSessionError(e, session);
      }
      debugPrint("Cart quote unavailable, showing local totals: $e");
    } finally {
      if (requestId == _cartQuoteRequestId) {
        _isQuotingCart = false;
        notifyListeners();
      }
    }
  }

  /// Idempotency key reused for retries of the same checkout request.
  String? _checkoutIdempotencyKey;
  String? _checkoutRequestSignature;

  void _resetCheckoutAttempt() {
    _checkoutIdempotencyKey = null;
    _checkoutRequestSignature = null;
  }

  /// Persists the cart, ends the current checkout attempt and reprices.
  void _onCartChanged({bool notify = true}) {
    _saveCart();
    _resetCheckoutAttempt();
    _invalidateCartQuote();
    if (notify) notifyListeners();
  }

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
    if (branch == _selectedBranch) return;
    _selectedBranch = branch;
    _selectedDeliveryZoneId = null;
    _homeProductsRetryAt = null;
    _resetCheckoutAttempt();
    _invalidateCartQuote();
    notifyListeners();
    unawaited(_persistSelectedBranch());
    // Reloads products for the branch, which also re-checks the cart.
    _loadCustomerModulesForSelectedBranch();
  }

  Future<void> _persistSelectedBranch() async {
    if (_branchRecords.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _storeScopedKey('selected_branch_id'), selectedBranchId);
    } catch (e) {
      debugPrint('Failed to save selected branch: $e');
    }
  }

  Future<int?> _readSavedBranchId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_storeScopedKey('selected_branch_id'));
    } catch (_) {
      return null;
    }
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
          Product.compareIds(item.variantId, variantId),
    );
    return existingIndex >= 0 ? _cart[existingIndex].quantity : 0;
  }

  bool canAddToCart(Product product,
          [int quantity = 1, ProductVariant? variant]) =>
      cartAddBlockReason(product, quantity, variant) == null;

  /// Why [product] can't be added to the bag, or null when it can.
  String? cartAddBlockReason(Product product,
      [int quantity = 1, ProductVariant? variant]) {
    if (product.variants.isNotEmpty && variant == null) {
      return 'Select options before adding.';
    }
    if (quantity <= 0) {
      return 'Choose a quantity of at least 1.';
    }
    if (_cart.isNotEmpty &&
        _cart.any((item) => item.isPreorder != product.isPreorder)) {
      return product.isPreorder
          ? 'Your bag has regular items. Pre-orders are checked out on their own, so check out or remove those items first.'
          : 'Your bag has a pre-order item. Pre-orders are checked out on their own, so check out or remove it before adding regular items.';
    }

    final inBag = cartQuantityFor(product, variant: variant);
    if (product.isPreorder) {
      final maxQuantity = product.preorderMaxQuantity;
      if (maxQuantity != null && inBag + quantity > maxQuantity) {
        return inBag > 0
            ? 'Maximum $maxQuantity per pre-order. You already have $inBag in your bag.'
            : 'Maximum $maxQuantity per pre-order.';
      }
      return null;
    }

    final stockQuantity = variant?.stockQuantity ?? product.stockQuantity;
    if (stockQuantity <= 0) {
      return 'This item is out of stock.';
    }
    if (inBag + quantity > stockQuantity) {
      return inBag > 0
          ? 'Only $stockQuantity in stock. You already have $inBag in your bag.'
          : 'Only $stockQuantity in stock.';
    }
    return null;
  }

  bool addToCart(Product product, {int quantity = 1, ProductVariant? variant}) {
    if (!canAddToCart(product, quantity, variant)) {
      return false;
    }
    final variantId = variant?.id ?? '';
    final existingIndex = _cart.indexWhere(
      (item) =>
          Product.compareIds(item.product.id, product.id) &&
          Product.compareIds(item.variantId, variantId),
    );
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += quantity;
    } else {
      _cart.add(
          CartItem(product: product, variant: variant, quantity: quantity));
    }
    _onCartChanged();
    return true;
  }

  void removeFromCart(Product product, {ProductVariant? variant}) {
    final variantId = variant?.id ?? '';
    _cart.removeWhere(
      (item) =>
          Product.compareIds(item.product.id, product.id) &&
          Product.compareIds(item.variantId, variantId),
    );
    _onCartChanged();
  }

  void removeCartItem(CartItem cartItem) {
    _cart.removeWhere((item) => item.cartKey == cartItem.cartKey);
    _onCartChanged();
  }

  bool updateQuantity(Product product, int quantity,
      {ProductVariant? variant}) {
    final variantId = variant?.id ?? '';
    final index = _cart.indexWhere(
      (item) =>
          Product.compareIds(item.product.id, product.id) &&
          Product.compareIds(item.variantId, variantId),
    );
    if (index >= 0) {
      if (quantity <= 0) {
        _cart.removeAt(index);
      } else if (quantity > maxCartQuantityFor(_cart[index])) {
        return false;
      } else {
        _cart[index].quantity = quantity;
      }
      _onCartChanged();
      return true;
    } else if (quantity > 0) {
      // A new line goes through the same checks as addToCart, including the
      // rule that keeps pre-orders and regular items in separate orders.
      if (cartAddBlockReason(product, quantity, variant) != null) {
        return false;
      }
      _cart.add(
          CartItem(product: product, variant: variant, quantity: quantity));
      _onCartChanged();
      return true;
    }
    return true;
  }

  /// Adds a bundle's real component products (and variants) as normal cart
  /// lines in their required quantities. The backend applies the bundle
  /// price automatically at quote and checkout.
  Future<void> addBundleToCart(Map<String, dynamic> bundle,
      {int sets = 1}) async {
    if (sets <= 0) {
      throw const StorefrontApiException('Choose at least one set.');
    }
    final rawItems =
        bundle['items'] ?? bundle['bundle_items'] ?? bundle['products'];
    final components =
        rawItems is List ? rawItems.whereType<Map>().toList() : <Map>[];
    if (components.isEmpty) {
      throw const StorefrontApiException('This bundle has no products to add.');
    }

    final lines = <String, CartItem>{};
    for (final component in components) {
      final productId =
          (component['product_id'] ?? component['id'])?.toString().trim() ?? '';
      final variantId = component['variant_id']?.toString().trim() ?? '';
      final componentName =
          (component['product_name'] ?? component['name'] ?? '')
              .toString()
              .trim();
      final unavailable = StorefrontApiException(componentName.isEmpty
          ? 'Part of this bundle is no longer available.'
          : '$componentName is no longer available.');
      final perSet =
          double.tryParse(component['quantity']?.toString() ?? '')?.toInt() ??
              1;
      final quantity = (perSet <= 0 ? 1 : perSet) * sets;
      if (productId.isEmpty) throw unavailable;

      Product? product;
      for (final candidate in _products) {
        if (Product.compareIds(candidate.id, productId)) {
          product = candidate;
          break;
        }
      }
      if ((product == null || !product.hasVariantData) && !_isWholesaleMode) {
        try {
          product =
              await api.getProduct(productId, branchId: selectedBranchId) ??
                  product;
        } catch (e) {
          debugPrint('Bundle component $productId lookup failed: $e');
        }
      }
      if (product == null) throw unavailable;

      ProductVariant? variant;
      if (variantId.isNotEmpty) {
        for (final candidate in product.variants) {
          if (Product.compareIds(candidate.id, variantId)) {
            variant = candidate;
            break;
          }
        }
        if (variant == null) throw unavailable;
      } else if (product.variants.isNotEmpty) {
        final inStock = product.variants
            .where((candidate) => candidate.stockQuantity >= quantity)
            .toList();
        if (inStock.isEmpty && !product.isPreorder) {
          throw StorefrontApiException(
              '${product.name} is out of stock in the bundle quantity.');
        }
        final pool = inStock.isEmpty ? product.variants : inStock;
        variant = pool.firstWhere((candidate) => candidate.isDefault,
            orElse: () => pool.first);
      }

      final line = CartItem(product: product, variant: variant);
      final existing = lines[line.cartKey];
      lines[line.cartKey] = CartItem(
        product: product,
        variant: variant,
        quantity: (existing?.quantity ?? 0) + quantity,
      );
    }

    for (final line in lines.values) {
      final reason =
          cartAddBlockReason(line.product, line.quantity, line.variant);
      if (reason != null) {
        throw StorefrontApiException('${line.displayName}: $reason');
      }
    }

    for (final line in lines.values) {
      final index = _cart.indexWhere((item) => item.cartKey == line.cartKey);
      if (index >= 0) {
        _cart[index].quantity += line.quantity;
      } else {
        _cart.add(line);
      }
    }
    _onCartChanged();
  }

  bool updateCartItemQuantity(CartItem cartItem, int quantity) {
    return updateQuantity(cartItem.product, quantity,
        variant: cartItem.variant);
  }

  /// Empties the bag in memory and in storage.
  void clearCart() {
    _cart.clear();
    _onCartChanged();
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

  double get _localCartSubtotal =>
      _cart.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Server-quoted values when a quote is present, local math otherwise.
  double get cartSubtotal => _cartQuote?.subtotal ?? _localCartSubtotal;
  double get cartDiscount => _cartQuote?.discount ?? 0.0;
  double get cartTax => _cartQuote?.tax ?? 0.0;
  List<String> get cartAppliedLabels => _cartQuote?.appliedLabels ?? const [];
  double get cartDeliveryFee {
    if (!deliveryEnabled || cartHasPreorder) return 0.0;
    final quote = _cartQuote;
    if (quote != null && quote.orderType == 'delivery') {
      return quote.deliveryFee;
    }
    return _deliveryCharge;
  }

  double get cartTotal => cartTotalFor(_fulfillmentType);
  double cartDeliveryFeeFor(String deliveryType) =>
      deliveryType.toLowerCase() == "delivery" ? cartDeliveryFee : 0.0;
  double cartTotalFor(String deliveryType) {
    final quote = _cartQuote;
    if (quote == null) {
      return _localCartSubtotal + cartDeliveryFeeFor(deliveryType);
    }
    return quote.total - quote.deliveryFee + cartDeliveryFeeFor(deliveryType);
  }

  static String _newIdempotencyKey(String storeSlug) {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    return '$storeSlug-${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  /// Places the order. Always returns the order or throws.
  ///
  /// [address] is the selected saved address label for delivery orders.
  /// [notes] is the customer's own note for the store.
  Future<AppOrder> checkout(String deliveryType, String address,
      {String? pickupTime, String? notes}) async {
    if (_cart.isEmpty) {
      throw StateError('Your bag is empty.');
    }
    if (_isCheckingOut) {
      throw const StorefrontApiException('Your order is already being placed.');
    }
    if (!checkoutEnabled) {
      throw const StorefrontApiException(
          'Checkout is unavailable for this store.');
    }
    if (cartHasPreorder) {
      // Pre-orders are collected in store once the items arrive.
      deliveryType = 'Pickup';
      pickupTime = null;
    }
    final isDelivery = deliveryType.toLowerCase() == 'delivery';
    final orderType = isDelivery ? 'delivery' : 'pickup';

    CustomerAddress? deliveryAddress;
    int? deliveryAddressId;
    int? deliveryZoneId;
    if (isDelivery) {
      if (!deliveryEnabled) {
        throw const StorefrontApiException(
            'Delivery is unavailable for this store.');
      }
      deliveryAddress = addressForLabel(address);
      deliveryAddressId = int.tryParse(deliveryAddress?.id ?? '');
      if (deliveryAddressId == null) {
        throw const StorefrontApiException(
            'Choose a saved delivery address before placing your order.');
      }
      deliveryZoneId = selectedDeliveryZone?.numericId;
      if (deliveryZoneId == null) {
        throw const StorefrontApiException(
            'Delivery is not available for this branch. Choose pickup instead.');
      }
    }
    final trimmedNotes = notes?.trim() ?? '';
    final session = _customerSession;
    final cartSnapshot = List<CartItem>.from(_cart);
    final branchId = selectedBranchId;
    final branchName = _selectedBranch;
    final wholesaleToken = _isWholesaleMode ? _wholesaleToken : null;

    // Same request → same key, so a retry after a timeout can't create a
    // second order. Any change to the request starts a new attempt.
    final signature = jsonEncode({
      'branch': branchId,
      'type': orderType,
      'address': deliveryAddressId,
      'zone': deliveryZoneId,
      'notes': trimmedNotes,
      'pickup': pickupTime,
      'wholesale': wholesaleToken != null,
      'customer': session?.customerId,
      'items': cartSnapshot
          .map((item) => [item.product.id, item.variantId, item.quantity])
          .toList(),
    });
    if (_checkoutIdempotencyKey == null ||
        _checkoutRequestSignature != signature) {
      _checkoutIdempotencyKey = _newIdempotencyKey(api.storeSlug);
      _checkoutRequestSignature = signature;
    }
    final idempotencyKey = _checkoutIdempotencyKey!;

    _isCheckingOut = true;
    notifyListeners();

    try {
      final Map<String, dynamic> result;
      if (wholesaleToken != null) {
        result = await api.checkoutWholesale(
          wholesaleToken: wholesaleToken,
          branchId: branchId,
          items: cartSnapshot,
          orderType: orderType,
          customerId: session?.customerId,
          customerToken: session?.customerToken,
          deliveryAddressId: deliveryAddressId,
          deliveryZoneId: deliveryZoneId,
          notes: trimmedNotes,
          pickupTime: pickupTime,
          idempotencyKey: idempotencyKey,
        );
      } else {
        result = await api.checkout(
          branchId: branchId,
          items: cartSnapshot,
          orderType: orderType,
          customerId: session?.customerId,
          customerToken: session?.customerToken,
          deliveryAddressId: deliveryAddressId,
          deliveryZoneId: deliveryZoneId,
          notes: trimmedNotes,
          pickupTime: pickupTime,
          idempotencyKey: idempotencyKey,
        );
      }
      final pricing = result['pricing'] as Map<String, dynamic>?;
      final resultBranch = result['branch_name']?.toString() ?? '';
      final orderBranch = resultBranch.isNotEmpty ? resultBranch : branchName;
      final liveOrder = AppOrder(
        id: result['order_number']?.toString() ??
            result['order_id']?.toString() ??
            idempotencyKey,
        items: cartSnapshot,
        subtotal: _number(pricing?['subtotal'], cartSubtotal),
        deliveryFee:
            _number(pricing?['delivery_fee'], cartDeliveryFeeFor(deliveryType)),
        discount: _number(pricing?['discount_amount'], cartDiscount),
        total: _number(pricing?['total'], cartTotalFor(deliveryType)),
        deliveryType: isDelivery ? 'Delivery' : 'Pickup',
        status: "Pending",
        createdAt: DateTime.now(),
        address: isDelivery
            ? (deliveryAddress?.formattedAddress.isNotEmpty == true
                ? deliveryAddress!.formattedAddress
                : address)
            : orderBranch,
        fulfillmentMode: result['fulfillment_mode']?.toString() ?? 'standard',
        preorderEtaText: result['preorder_eta_text']?.toString() ?? '',
        branchName: orderBranch,
        notes: trimmedNotes,
      );
      _orders.insert(0, liveOrder);
      // Persist the empty bag so the ordered items never come back.
      clearCart();
      return liveOrder;
    } catch (e) {
      debugPrint("Storefront checkout failed: $e");
      if (session != null) {
        await _handleSessionError(e, session);
      }
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
      await _handleSessionError(e, session);
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

      final session = _customerSession;
      final ticketData = session == null
          ? await api.createSupportTicket(
              subject: title,
              category: mappedCategory,
              message: description,
              attachments: attachments,
            )
          : await _guardSession(
              session,
              () => api.createSupportTicket(
                subject: title,
                category: mappedCategory,
                message: description,
                attachments: attachments,
                session: session,
              ),
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
      await _handleSessionError(e, session);
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
      await _guardSession(
        session,
        () => api.replySupportTicket(
          ticketId: ticketId,
          message: content,
          attachments: attachments,
          session: session,
        ),
      );
      await refreshTicketDetails(ticketId);
    } catch (e) {
      debugPrint("Storefront support reply failed: $e");
      rethrow;
    }
  }

  static const _maxSupportAttachmentBytes = 10 * 1024 * 1024;

  /// Uploads a picked file (web-safe: reads bytes, no dart:io) and returns
  /// the attachment payload to send with a ticket message.
  Future<Map<String, dynamic>> uploadSupportAttachment(XFile file,
      [String? filename]) async {
    if (!supportEnabled) {
      throw const StorefrontApiException(
          "Customer support is unavailable for this store.");
    }
    final session = _customerSession;
    if (session == null) {
      throw const StorefrontApiException(
          "Must be signed in to upload support attachments.");
    }
    final name = (filename?.trim().isNotEmpty == true)
        ? filename!.trim()
        : _fileNameOf(file);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const StorefrontApiException('That file is empty.');
    }
    if (bytes.length > _maxSupportAttachmentBytes) {
      throw const StorefrontApiException('Choose a file smaller than 10 MB.');
    }
    return _guardSession(
      session,
      () => api.uploadSupportAttachment(
        bytes: bytes,
        filename: name,
        mimeType: file.mimeType,
        session: session,
      ),
    );
  }

  static String _fileNameOf(XFile file) {
    if (file.name.trim().isNotEmpty) return file.name.trim();
    final segments = file.path.split(RegExp(r'[\\/]'));
    final last = segments.isEmpty ? '' : segments.last;
    return last.isEmpty ? 'upload.jpg' : last;
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

    final session = _customerSession;
    if (session != null &&
        !id.startsWith('mock-') &&
        !id.startsWith('local-')) {
      try {
        await api.markNotificationRead(
          notificationId: id,
          session: session,
        );
      } catch (e) {
        await _handleSessionError(e, session);
        debugPrint("Storefront notification read kept local: $e");
      }
    }
  }

  /// Marks every notification read with one request. Throws on failure.
  Future<void> markAllNotificationsRead() async {
    if (!notificationsEnabled) return;
    final session = _customerSession;
    if (session != null) {
      try {
        await _guardSession(
            session, () => api.markAllNotificationsRead(session));
      } on StorefrontApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        // Older backend without read-all: mark the unread ones one by one.
        final unread = _notifications
            .where((n) => n['isRead'] != true)
            .map((n) => n['id']?.toString() ?? '')
            .where((id) =>
                id.isNotEmpty &&
                !id.startsWith('mock-') &&
                !id.startsWith('local-'))
            .toList();
        for (final id in unread) {
          await _guardSession(
            session,
            () =>
                api.markNotificationRead(notificationId: id, session: session),
          );
        }
      }
    }
    for (final notification in _notifications) {
      notification['isRead'] = true;
    }
    notifyListeners();
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
    final previousBranchId = _branchRecords.isEmpty ? null : selectedBranchId;

    try {
      final config = initialConfig ?? await api.getConfig();
      final savedBranchId = await _readSavedBranchId();
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

        // Keep the customer's branch across refreshes and restarts.
        StorefrontBranch? keptBranch;
        for (final id in [previousBranchId, savedBranchId]) {
          if (id == null) continue;
          for (final branch in liveBranches) {
            if (branch.id == id) {
              keptBranch = branch;
              break;
            }
          }
          if (keptBranch != null) break;
        }
        _selectedBranch = keptBranch?.name ?? _branches.first;

        if (keptBranch == null && productsEnabled && liveBranches.length > 1) {
          for (final branch in liveBranches) {
            try {
              final summary = await api.getCatalogSummary(branchId: branch.id);
              final productCount = int.tryParse(
                    summary['product_count']?.toString() ?? '',
                  ) ??
                  0;
              if (productCount > 0) {
                _selectedBranch = branch.name;
                break;
              }
            } catch (_) {
              // Keep the configured first branch if the catalog summary is
              // unavailable; the normal storefront load reports its own errors.
              break;
            }
          }
        }
      }
      if (liveBranches.isNotEmpty) {
        unawaited(_persistSelectedBranch());
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
      _isCatalogLoading = false;
      notifyListeners();
    }
    if (_isLiveBackendConnected) {
      _invalidateCartQuote();
    }
  }

  /// Retries the backend after an offline start or a lost connection.
  Future<void> _reconnect() async {
    if (_isLoadingConfig || _isReconnecting) return;
    _isReconnecting = true;
    try {
      await _fetchBackendConfig();
      if (_isLiveBackendConnected && _customerSession != null) {
        await loadCustomerData();
      }
    } finally {
      _isReconnecting = false;
    }
  }

  void _onPeriodicRefresh() {
    if (!_isLiveBackendConnected) {
      unawaited(_reconnect());
      return;
    }
    unawaited(_refreshCatalogFromBackend());
  }

  void _applyFeatureVisibilityRules() {
    var cartCleared = false;
    if (!productsEnabled) {
      _products.clear();
      _homeProducts.clear();
      if (_cart.isNotEmpty) {
        _cart.clear();
        cartCleared = true;
      }
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
      if (_cart.isNotEmpty) {
        _cart.clear();
        cartCleared = true;
      }
    }
    if (cartCleared) {
      _onCartChanged(notify: false);
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
      // Retail prices no longer apply; persist the empty bag too.
      _cart.clear();
      _onCartChanged(notify: false);
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
    // Wholesale prices no longer apply; persist the empty bag too.
    _cart.clear();
    _onCartChanged(notify: false);
    _loadProductsForSelectedBranch(notify: false);
    notifyListeners();
  }

  int _productsRequestId = 0;

  /// Loads the catalog for the selected branch. [background] refreshes keep
  /// the home feed's pagination and don't flip [isCatalogLoading]. Results
  /// from a superseded request (e.g. an older branch) are ignored.
  Future<void> _loadProductsForSelectedBranch({
    bool notify = true,
    bool preserveOnError = false,
    bool background = false,
  }) async {
    if (!productsEnabled) {
      _products.clear();
      _isCatalogLoading = false;
      if (notify) {
        notifyListeners();
      }
      return;
    }

    if (!_isLiveBackendConnected && notify) {
      _products.clear();
      _isCatalogLoading = false;
      notifyListeners();
      return;
    }

    final requestId = ++_productsRequestId;
    final branchId = selectedBranchId;
    final wholesaleToken = _isWholesaleMode ? _wholesaleToken : null;
    if (!background) {
      _isCatalogLoading = true;
      if (notify) notifyListeners();
    }

    try {
      final List<Product> liveProducts;
      if (wholesaleToken != null) {
        liveProducts = await api.listWholesaleProducts(
          wholesaleToken: wholesaleToken,
          branchId: branchId,
        );
      } else {
        liveProducts = await api.listProducts(branchId: branchId);
      }
      if (requestId != _productsRequestId) return;
      _products = List<Product>.from(liveProducts);
      _reconcileCartWithProducts();
      if (background) {
        _refreshHomeProductsInPlace();
      } else {
        unawaited(loadHomeProducts(reset: true));
      }
    } catch (e) {
      if (requestId != _productsRequestId) return;
      if (!preserveOnError) {
        _products.clear();
      }
      debugPrint("Storefront catalog load failed: $e");
    } finally {
      if (requestId == _productsRequestId) {
        if (!background) _isCatalogLoading = false;
        if (notify) {
          notifyListeners();
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isLiveBackendConnected) {
        unawaited(_reconnect());
      } else {
        _refreshCatalogFromBackend(force: true);
      }
    }
  }

  Future<void> _refreshCatalogFromBackend({bool force = false}) async {
    if (!_isLiveBackendConnected ||
        !productsEnabled ||
        _isAutomaticCatalogRefreshRunning) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastAutomaticCatalogRefresh != null &&
        now.difference(_lastAutomaticCatalogRefresh!) <
            _catalogRefreshInterval) {
      return;
    }

    _lastAutomaticCatalogRefresh = now;
    _isAutomaticCatalogRefreshRunning = true;
    try {
      await _loadProductsForSelectedBranch(
        notify: false,
        preserveOnError: true,
        background: true,
      );
      notifyListeners();
    } finally {
      _isAutomaticCatalogRefreshRunning = false;
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
      if (item.variantId.isNotEmpty && !liveProduct.hasVariantData) {
        // The list payload has no variants, so the variant can't be checked
        // here. Keep the line as it is; quote and checkout validate it.
        reconciled.add(item);
        continue;
      }
      if (item.variantId.isNotEmpty) {
        for (final variant in liveProduct.variants) {
          if (Product.compareIds(variant.id, item.variantId)) {
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
      if (!liveProduct.isPreorder && stock <= 0) {
        changed = true;
        continue;
      }
      final quantity = liveProduct.isPreorder
          ? (liveProduct.preorderMaxQuantity == null
              ? item.quantity
              : (item.quantity > liveProduct.preorderMaxQuantity!
                  ? liveProduct.preorderMaxQuantity!
                  : item.quantity))
          : (item.quantity > stock ? stock : item.quantity);
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
      _onCartChanged(notify: false);
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
    if (_isLiveBackendConnected) {
      _invalidateCartQuote();
    }

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
    final branchId = selectedBranchId;
    try {
      final rows = await api.listDeliveryZones(branchId: branchId);
      // A newer branch switch owns the zone list.
      if (branchId != selectedBranchId) return;
      _deliveryZones
        ..clear()
        ..addAll(rows
            .map(DeliveryZone.fromJson)
            .where((zone) => zone.numericId != null));
      if (!_deliveryZones.any((zone) => zone.id == _selectedDeliveryZoneId)) {
        _selectedDeliveryZoneId = null;
      }
    } catch (e) {
      if (branchId != selectedBranchId) return;
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
      await _handleSessionError(e, session);
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

  /// Sends a reset request for [username] (or an email) and returns the
  /// server message to show.
  Future<String> requestPasswordReset(String username) async {
    if (!_isLiveBackendConnected) {
      throw const StorefrontApiException(
          "Password reset requests are unavailable while the store backend is offline.");
    }
    final value = username.trim();
    if (value.isEmpty) {
      throw const StorefrontApiException('Enter your username.');
    }
    final data = await api.requestPasswordReset(value);
    final message = data['message']?.toString().trim() ?? '';
    return message.isNotEmpty
        ? message
        : 'Your reset request was sent. The store will contact you.';
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
    _sessionNotice = null;
    profileEmail = identifier.contains("@") ? identifier : profileEmail;
    if (fullName != null && fullName.isNotEmpty) {
      profileName = fullName;
    }
    final prefs = await SharedPreferences.getInstance();
    await _persistSession(session);
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

  /// Signs out and clears every piece of customer data, in memory and in
  /// storage, then reloads the retail catalog.
  Future<void> signOutCustomer({bool notifyServer = true}) async {
    final session = _customerSession;
    if (notifyServer && _isLiveBackendConnected && session != null) {
      try {
        await api.logout(session);
      } catch (e) {
        debugPrint("Storefront logout API failed; clearing local session: $e");
      }
    }

    _customerSession = null;
    final wasWholesale = _isWholesaleMode;

    // Reset profile fields
    profileName = "Store Customer";
    profileUsername = "";
    profileEmail = "";
    profilePhone = "";
    profileSkinConcern = "All";
    profileDob = "";
    profileGender = "";
    profileImageUrl = null;
    _accountPassword = null;

    // Clear all customer-scoped data to prevent cross-account leakage
    _orders.clear();
    _orderTimelines.clear();
    _tickets.clear();
    _notifications.clear();
    _myReviews.clear();
    _wishlist.clear();
    _customerAddresses.clear();
    _savedAddresses.clear();
    _cart.clear();
    _cartQuoteDebounce?.cancel();
    _cartQuoteRequestId++;
    _cartQuote = null;
    _isQuotingCart = false;
    _resetCheckoutAttempt();

    _isWholesaleMode = false;
    _wholesaleToken = null;
    _wholesaleMinOrderAmount = 0.0;

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in const [
        'customer_id',
        'customer_token',
        'customer_token_expires_at',
        'customer_identifier',
        'customer_username',
        'customer_email',
        'customer_password',
        'customer_dob',
        'customer_gender',
        'customer_profile_image',
        'customer_name',
        'customer_phone',
        'customer_skin_concern',
        'customer_wishlist',
        'customer_cart',
      ]) {
        await prefs.remove(_storeScopedKey(key));
      }
    } catch (e) {
      debugPrint("Failed to clear stored customer data: $e");
    }

    notifyListeners();

    if (_isLiveBackendConnected && productsEnabled) {
      unawaited(_loadProductsForSelectedBranch(
        preserveOnError: true,
        background: !wasWholesale,
      ));
    }
  }

  /// Deletes the account after the server confirms [password].
  Future<void> deleteAccount({required String password}) async {
    final session = _customerSession;
    if (session == null) {
      throw StateError('Sign in to delete your account.');
    }
    if (password.isEmpty) {
      throw const StorefrontApiException('Enter your password to confirm.');
    }
    await _guardSession(
        session, () => api.deleteAccount(session, password: password));
    await signOutCustomer(notifyServer: false);
  }

  @Deprecated('Use deleteAccount(password: ...); the backend requires the '
      'password to confirm deletion.')
  Future<void> deleteCustomerAccount({String? password}) async {
    if (password == null || password.isEmpty) {
      throw const StorefrontApiException(
          'Enter your password to delete your account.');
    }
    await deleteAccount(password: password);
  }

  /// True when [error] means the customer token is no longer valid. Signs
  /// out (once) and sets [sessionNotice] when it belongs to the current
  /// session.
  Future<bool> _handleSessionError(
      Object error, CustomerSession? session) async {
    if (error is! StorefrontApiException || !error.isSessionExpired) {
      return false;
    }
    final current = _customerSession;
    if (current == null ||
        (session != null && session.customerToken != current.customerToken)) {
      return true;
    }
    _sessionNotice = sessionExpiredNotice;
    await signOutCustomer(notifyServer: false);
    return true;
  }

  /// Runs a customer call; an expired token signs out before rethrowing.
  Future<T> _guardSession<T>(
      CustomerSession session, Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      await _handleSessionError(e, session);
      rethrow;
    }
  }

  Future<void> _persistSession(CustomerSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storeScopedKey('customer_id'), session.customerId);
      await prefs.setString(
          _storeScopedKey('customer_token'), session.customerToken);
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        await prefs.setString(_storeScopedKey('customer_token_expires_at'),
            expiresAt.toIso8601String());
      } else {
        await prefs.remove(_storeScopedKey('customer_token_expires_at'));
      }
    } catch (e) {
      debugPrint("Failed to persist customer session: $e");
    }
  }

  Future<void> refreshAllData() async {
    await Future.wait([
      _loadCustomerModulesForSelectedBranch(notify: false),
      loadCustomerData(),
    ]);
    notifyListeners();
  }

  @override
  void dispose() {
    _catalogRefreshTimer?.cancel();
    _cartQuoteDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

      if (!identical(_customerSession, session)) {
        return; // Signed out or switched accounts while loading.
      }
      final profile = results[0] as Map<String, dynamic>;
      final addresses = results[1] as List<Map<String, dynamic>>;
      final tokenExpiresAt =
          CustomerSession.parseExpiry(profile['token_expires_at']);
      if (tokenExpiresAt != null && tokenExpiresAt != session.expiresAt) {
        _customerSession = session.copyWith(expiresAt: tokenExpiresAt);
        unawaited(_persistSession(_customerSession!));
      }
      final orders = results[2] as List<Map<String, dynamic>>;
      final liveNotifications = results[3] as List<Map<String, dynamic>>;
      final tickets = results[4] as List<Map<String, dynamic>>;

      if (profileEnabled) {
        final name =
            profile['full_name'] ?? profile['name'] ?? profile['customer_name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          profileName = name.toString();
        }
        final username = profile['username'];
        if (username != null && username.toString().trim().isNotEmpty) {
          profileUsername = username.toString();
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
        if (profileUsername.isNotEmpty) {
          await prefs.setString(
              _storeScopedKey('customer_identifier'), profileUsername);
          await prefs.setString(
              _storeScopedKey('customer_username'), profileUsername);
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
        // Only real saved addresses; never placeholders.
        _customerAddresses
          ..clear()
          ..addAll(mappedAddresses);
        _savedAddresses
          ..clear()
          ..addAll(mappedAddresses.map((address) => address.displayLabel));
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
      if (await _handleSessionError(e, session)) return;
      if (!identical(_customerSession, session)) return;
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
      await _handleSessionError(e, session);
      debugPrint("Storefront order detail kept local: $e");
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final session = _customerSession;
    if (session == null) {
      throw Exception("Must be signed in to cancel an order");
    }

    try {
      final updatedPayload = await _guardSession(
          session, () => api.cancelOrder(orderId: orderId, session: session));
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

  /// Creates or updates [address] and returns the saved address so the UI
  /// can select it.
  Future<CustomerAddress> saveCustomerAddress(CustomerAddress address) async {
    final session = _customerSession;
    if (session == null) {
      final local = _upsertLocalAddress(address);
      notifyListeners();
      return local;
    }

    final saved = await _guardSession(
      session,
      () => address.id.isEmpty
          ? api.createAddress(session: session, address: address.toPayload())
          : api.updateAddress(
              session: session,
              addressId: address.id,
              address: address.toPayload(),
            ),
    );
    var savedAddress = CustomerAddress.fromJson(saved);
    if (savedAddress.id.isEmpty || savedAddress.addressLine1.trim().isEmpty) {
      // Some responses only echo the id; keep what the customer entered.
      savedAddress = CustomerAddress(
        id: savedAddress.id.isNotEmpty ? savedAddress.id : address.id,
        label: address.label,
        recipientName: address.recipientName,
        recipientPhone: address.recipientPhone,
        addressLine1: address.addressLine1,
        addressLine2: address.addressLine2,
        city: address.city,
        state: address.state,
        postalCode: address.postalCode,
        country: address.country,
      );
    }
    final result = _upsertLocalAddress(savedAddress, replacing: address);
    notifyListeners();
    return result;
  }

  Future<void> deleteCustomerAddress(CustomerAddress address) async {
    final session = _customerSession;
    if (session != null && address.id.isNotEmpty) {
      await _guardSession(session,
          () => api.deleteAddress(session: session, addressId: address.id));
    }
    _customerAddresses.removeWhere((entry) =>
        entry.id.isNotEmpty && entry.id == address.id ||
        entry.displayLabel == address.displayLabel);
    _savedAddresses
      ..clear()
      ..addAll(_customerAddresses.map((entry) => entry.displayLabel));
    notifyListeners();
  }

  CustomerAddress _upsertLocalAddress(CustomerAddress address,
      {CustomerAddress? replacing}) {
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
    var index = _customerAddresses.indexWhere((entry) =>
        entry.id.isNotEmpty && entry.id == normalized.id ||
        entry.displayLabel == normalized.displayLabel);
    if (index < 0 && replacing != null && replacing.id.isNotEmpty) {
      index =
          _customerAddresses.indexWhere((entry) => entry.id == replacing.id);
    }
    if (index >= 0) {
      _customerAddresses[index] = normalized;
    } else {
      _customerAddresses.add(normalized);
    }
    _savedAddresses
      ..clear()
      ..addAll(_customerAddresses.map((entry) => entry.displayLabel));
    return normalized;
  }

  Future<void> _restoreCustomerSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getInt(_storeScopedKey('customer_id'));
      final customerToken = prefs.getString(_storeScopedKey('customer_token'));
      final tokenExpiresAt = CustomerSession.parseExpiry(
          prefs.getString(_storeScopedKey('customer_token_expires_at')));
      final identifier =
          prefs.getString(_storeScopedKey('customer_identifier'));

      profileName =
          prefs.getString(_storeScopedKey('customer_name')) ?? profileName;
      profilePhone =
          prefs.getString(_storeScopedKey('customer_phone')) ?? profilePhone;
      profileUsername =
          prefs.getString(_storeScopedKey('customer_username')) ?? '';
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
        final restored = CustomerSession(
          customerId: customerId,
          customerToken: customerToken,
          expiresAt: tokenExpiresAt,
        );
        if (restored.isExpired) {
          _customerSession = restored;
          _sessionNotice = sessionExpiredNotice;
          await signOutCustomer(notifyServer: false);
          return;
        }
        _customerSession = restored;
        if (identifier != null && identifier.isNotEmpty) {
          profileUsername = identifier;
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
        final session = _customerSession!;
        final updatedProfile = await _guardSession(
          session,
          () => api.updateProfile(session: session, name: nextName),
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

  static const _maxProfileImageBytes = 5 * 1024 * 1024;

  /// Uploads a picked image (web-safe: bytes, no dart:io) and returns the
  /// new profile image URL.
  Future<String> uploadProfileImage(XFile file) async {
    final session = _customerSession;
    if (session == null) {
      throw StateError('Sign in to update your profile picture.');
    }
    final name = _fileNameOf(file);
    final dot = name.lastIndexOf('.');
    final extension = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    const allowedExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    const allowedMimeTypes = {
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp'
    };
    final mimeType = file.mimeType?.toLowerCase();
    final typeAllowed = allowedExtensions.contains(extension) ||
        (extension.isEmpty &&
            mimeType != null &&
            allowedMimeTypes.contains(mimeType));
    if (!typeAllowed) {
      throw ArgumentError('Choose a JPEG, PNG, GIF, or WebP image.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > _maxProfileImageBytes) {
      throw ArgumentError('Choose an image smaller than 5 MB.');
    }
    final profile = await _guardSession(
      session,
      () => api.uploadProfileImage(
        session: session,
        bytes: bytes,
        filename: name,
        mimeType: allowedMimeTypes.contains(mimeType) ? mimeType : null,
      ),
    );
    final imageUrl = profile['profile_image_url']?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw const StorefrontApiException(
          'The profile picture could not be saved.');
    }
    final resolved = api.resolveMediaUrl(imageUrl);
    profileImageUrl = resolved;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _storeScopedKey('customer_profile_image'), resolved);
    } catch (e) {
      debugPrint("Failed to persist profile image locally: $e");
    }
    notifyListeners();
    return resolved;
  }

  Future<void> removeProfileImage() async {
    final session = _customerSession;
    if (session == null) return;
    await _guardSession(session, () => api.removeProfileImage(session));
    profileImageUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeScopedKey('customer_profile_image'));
    notifyListeners();
  }

  /// Changes the password on the server, which verifies [currentPassword].
  /// The session stays valid; a rotated token from the server replaces it.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = _customerSession;
    if (session == null) {
      throw StateError('Sign in to change your password.');
    }
    if (!_isLiveBackendConnected) {
      throw const StorefrontApiException(
          'Password changes are unavailable while the store backend is offline.');
    }
    if (currentPassword.isEmpty) {
      throw const StorefrontApiException('Enter your current password.');
    }
    if (newPassword.isEmpty) {
      throw const StorefrontApiException('Enter a new password.');
    }
    final data = await _guardSession(
      session,
      () => api.changePassword(
        session: session,
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
    final rotatedToken =
        (data['token'] ?? data['customer_token'])?.toString().trim() ?? '';
    if (rotatedToken.isNotEmpty && identical(_customerSession, session)) {
      _customerSession = session.copyWith(
        customerToken: rotatedToken,
        expiresAt: CustomerSession.parseExpiry(data['token_expires_at']),
      );
      await _persistSession(_customerSession!);
    }
    notifyListeners();
  }

  @Deprecated('Use changePassword(currentPassword:, newPassword:); the '
      'backend requires the current password.')
  Future<void> updatePassword(String newPassword,
      {String? currentPassword}) async {
    if (currentPassword == null || currentPassword.isEmpty) {
      throw const StorefrontApiException('Enter your current password.');
    }
    await changePassword(
        currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<void> registerWithPassword({
    required String name,
    required String username,
    required String password,
    CustomerSession? backendSession,
  }) async {
    CustomerSession? session = backendSession;
    final normalizedUsername = normalizeUsername(username);

    if (!_isLiveBackendConnected && session == null) {
      throw const StorefrontApiException(
          "Customer registration is unavailable while the store backend is offline.");
    }

    if (session == null) {
      try {
        session = await api.registerWithUsernamePassword(
          name: normalizeFullName(name),
          username: normalizedUsername,
          password: password,
        );
      } catch (e) {
        debugPrint("Backend username registration failed: $e");
        rethrow;
      }
    }

    _customerSession = session;
    _sessionNotice = null;

    profileName = normalizeFullName(name);
    profileEmail = '';
    profilePhone = '';
    profileUsername = normalizedUsername;

    try {
      final prefs = await SharedPreferences.getInstance();
      await _persistSession(session);
      await prefs.setString(
          _storeScopedKey('customer_identifier'), normalizedUsername);
      await prefs.setString(_storeScopedKey('customer_name'), profileName);
      await prefs.setString(
          _storeScopedKey('customer_username'), normalizedUsername);
      await prefs.remove(_storeScopedKey('customer_email'));
      await prefs.remove(_storeScopedKey('customer_phone'));
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
    required String username,
    required String password,
  }) async {
    if (!_isLiveBackendConnected) {
      throw const StorefrontApiException(
          "Customer login is unavailable while the store backend is offline.");
    }

    try {
      final normalizedUsername = normalizeUsername(username);
      final session = await api.loginWithPassword(
        username: normalizedUsername,
        password: password,
      );
      _customerSession = session;
      _sessionNotice = null;
      final prefs = await SharedPreferences.getInstance();
      await _persistSession(session);
      await prefs.setString(
          _storeScopedKey('customer_identifier'), normalizedUsername);
      await prefs.remove(_storeScopedKey('customer_email'));
      profileEmail = '';
      profilePhone = '';
      profileUsername = normalizedUsername;
      await prefs.setString(
          _storeScopedKey('customer_username'), normalizedUsername);
      await prefs.remove(_storeScopedKey('customer_phone'));
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
                  .where((entry) => Product.compareIds(entry.id, variantId))
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
    final orderType =
        (json['order_type']?.toString() ?? 'delivery').toLowerCase();
    final branchName = _orderBranchName(json);
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
      address: orderType == 'delivery'
          ? _orderDeliveryAddressText(json)
          : branchName,
      fulfillmentMode: json['fulfillment_mode']?.toString() ?? 'standard',
      preorderEtaText: json['preorder_eta_text']?.toString() ?? '',
      splitFromOrderNumber: json['split_from_order_number']?.toString() ?? '',
      branchName: branchName,
      notes: (json['notes'] ?? json['customer_notes'] ?? '').toString(),
    );
  }

  /// The order's own branch (never the currently selected one).
  String _orderBranchName(Map<String, dynamic> json) {
    final name = json['branch_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final branchId = int.tryParse(json['branch_id']?.toString() ?? '');
    for (final branch in _branchRecords) {
      if (branch.id == branchId) return branch.name;
    }
    return '';
  }

  /// A readable address from the order's address snapshot, which may be a
  /// map, a JSON string or plain text.
  String _orderDeliveryAddressText(Map<String, dynamic> json) {
    final raw = json['delivery_address_snapshot'] ??
        json['delivery_address'] ??
        json['address'];
    dynamic value = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('{')) {
        try {
          value = jsonDecode(trimmed);
        } catch (_) {
          return trimmed;
        }
      } else {
        return trimmed;
      }
    }
    if (value is Map) {
      final address =
          CustomerAddress.fromJson(Map<String, dynamic>.from(value));
      final text = address.formattedAddress;
      if (text.isNotEmpty) return text;
      return address.label == 'Address' ? '' : address.label;
    }
    return '';
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
        final isActive = _featureRowIsActive(value);
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
          final isActive = _featureRowIsActive(item);
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

/// A feature is active only when both the platform feature and the store's
/// own switch are on; a store-level disable is never ignored.
bool _featureRowIsActive(Map value) {
  if (value.containsKey('feature_is_active') ||
      value.containsKey('store_is_active')) {
    return _truthyFeatureFlag(value['feature_is_active'] ?? true) &&
        _truthyFeatureFlag(value['store_is_active'] ?? true);
  }
  return _truthyFeatureFlag(
    value['is_active'] ?? value['enabled'] ?? value['value'] ?? true,
  );
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
