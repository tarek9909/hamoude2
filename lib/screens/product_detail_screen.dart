import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_refresh.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/top_toast.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedImageIndex = 0;
  Product? _liveProduct;
  ProductVariant? _selectedVariant;
  final Map<String, String> _selectedVariantOptions = {};
  final PageController _imagePageController = PageController();
  List<Map<String, dynamic>> _productReviews = [];
  bool _loadingReviews = false;

  @override
  void initState() {
    super.initState();
    _seedVariantSelection(widget.product);
    _fetchLiveProduct();
    _loadProductReviews();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveProduct() async {
    if (!mounted) return;

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (!appState.productsEnabled) return;
      final product = await appState.api.getProduct(
        widget.product.id,
        branchId: appState.selectedBranchId,
      );
      if (product != null && mounted) {
        setState(() {
          _liveProduct = product;
          _seedVariantSelection(product);
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch product details from backend: $e");
    }
  }

  void _seedVariantSelection(Product product) {
    if (product.variants.isEmpty) {
      _selectedVariant = null;
      _selectedVariantOptions.clear();
      return;
    }
    final currentId = _selectedVariant?.id;
    ProductVariant? selected;
    for (final variant in product.variants) {
      if (variant.id == currentId && variant.stockQuantity > 0) {
        selected = variant;
        break;
      }
    }
    selected ??= product.variants
        .where((variant) => variant.isDefault && variant.stockQuantity > 0)
        .cast<ProductVariant?>()
        .firstWhere((variant) => variant != null, orElse: () => null);
    selected ??= product.variants
        .where((variant) => variant.stockQuantity > 0)
        .cast<ProductVariant?>()
        .firstWhere((variant) => variant != null, orElse: () => null);
    selected ??= product.variants
        .where((variant) => variant.isDefault)
        .cast<ProductVariant?>()
        .firstWhere((variant) => variant != null, orElse: () => null);
    selected ??= product.variants.first;
    _selectedVariant = selected;
    _selectedVariantOptions
      ..clear()
      ..addAll(_optionsForVariant(selected));
    final images = _galleryImages(product, selected);
    if (_selectedImageIndex >= images.length) {
      _selectedImageIndex = 0;
    }
    final stock = selected.stockQuantity;
    if (_quantity > stock) {
      _quantity = stock > 0 ? stock : 1;
    }
  }

  Map<String, String> _optionsForVariant(ProductVariant? variant) {
    if (variant == null) return {};
    final options = <String, String>{};
    for (final attribute in variant.attributes) {
      if (attribute.code.isNotEmpty && attribute.displayValue.isNotEmpty) {
        options[attribute.code] = attribute.displayValue;
      }
    }
    return options;
  }

  Map<String, String> _variantOptionLabels(Product product) {
    final labels = <String, String>{};
    for (final variant in product.variants) {
      for (final attribute in variant.attributes) {
        if (attribute.code.isNotEmpty && attribute.displayValue.isNotEmpty) {
          labels.putIfAbsent(attribute.code, () => attribute.label);
        }
      }
    }
    return labels;
  }

  Map<String, List<String>> _variantOptions(Product product) {
    final options = <String, List<String>>{};
    for (final variant in product.variants) {
      for (final attribute in variant.attributes) {
        if (attribute.code.isEmpty || attribute.displayValue.isEmpty) continue;
        options.putIfAbsent(attribute.code, () => <String>[]);
        for (final option in attribute.options) {
          if (!options[attribute.code]!.contains(option)) {
            options[attribute.code]!.add(option);
          }
        }
        if (!options[attribute.code]!.contains(attribute.displayValue)) {
          options[attribute.code]!.add(attribute.displayValue);
        }
      }
    }
    return options;
  }

  String _variantValue(ProductVariant variant, String code) {
    for (final attribute in variant.attributes) {
      if (attribute.code == code) {
        return attribute.displayValue;
      }
    }
    return '';
  }

  bool _matchesOptions(ProductVariant variant, Map<String, String> options) {
    for (final entry in options.entries) {
      if (_variantValue(variant, entry.key) != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _optionAvailable(
    Product product,
    String code,
    String value,
  ) {
    final candidateOptions = Map<String, String>.from(_selectedVariantOptions)
      ..[code] = value;
    return product.variants.any(
      (variant) =>
          variant.stockQuantity > 0 &&
          _matchesOptions(variant, candidateOptions),
    );
  }

  ProductVariant? _variantForOptions(
    Product product,
    Map<String, String> options,
  ) {
    for (final variant in product.variants) {
      if (variant.stockQuantity > 0 && _matchesOptions(variant, options)) {
        return variant;
      }
    }
    for (final variant in product.variants) {
      if (_matchesOptions(variant, options)) {
        return variant;
      }
    }
    return null;
  }

  void _selectVariantOption(Product product, String code, String value) {
    final options = Map<String, String>.from(_selectedVariantOptions)
      ..[code] = value;
    final variant = _variantForOptions(product, options);
    setState(() {
      _selectedVariantOptions
        ..clear()
        ..addAll(options);
      _selectedVariant = variant;
      final stock = variant?.stockQuantity ?? product.stockQuantity;
      if (_quantity > stock) {
        _quantity = stock > 0 ? stock : 1;
      }
    });
    _focusVariantImage(product, variant);
  }

  List<ProductImage> _galleryImages(Product product, ProductVariant? variant) {
    final images = <ProductImage>[];
    if (variant?.imageUrl.isNotEmpty == true) {
      images.add(ProductImage(
        id: 'variant_${variant!.id}',
        variantId: variant.id,
        imageUrl: variant.imageUrl,
        isPrimary: true,
      ));
    }
    for (final image in product.images) {
      if (!images.any((entry) => entry.imageUrl == image.imageUrl)) {
        images.add(image);
      }
    }
    if (images.isEmpty && product.imageUrl.isNotEmpty) {
      images.add(ProductImage(
        id: 'primary',
        imageUrl: product.imageUrl,
        isPrimary: true,
      ));
    }
    return images;
  }

  void _focusVariantImage(Product product, ProductVariant? variant) {
    if (variant == null || variant.imageUrl.isEmpty) return;
    final images = _galleryImages(product, variant);
    final index =
        images.indexWhere((image) => image.imageUrl == variant.imageUrl);
    if (index < 0) return;
    setState(() => _selectedImageIndex = index);
    if (_imagePageController.hasClients) {
      _imagePageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  double _priceForSelection({
    required Product product,
    required ProductVariant? variant,
    required double? discountedProductPrice,
  }) {
    final variantPrice = variant?.price;
    if (variantPrice == null) {
      return discountedProductPrice ?? product.price;
    }
    if (discountedProductPrice == null || product.price <= 0) {
      return variantPrice;
    }
    final discountRatio = discountedProductPrice / product.price;
    if (discountRatio <= 0 || discountRatio >= 1) {
      return variantPrice;
    }
    return variantPrice * discountRatio;
  }

  Color? _colorForOption(String value) {
    final normalized = value.trim().toLowerCase();
    if (RegExp(r'^#?[0-9a-f]{6}$').hasMatch(normalized)) {
      final hex = normalized.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    }
    const named = {
      'black': Colors.black,
      'white': Colors.white,
      'red': Colors.red,
      'pink': Colors.pink,
      'purple': Colors.purple,
      'blue': Colors.blue,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'brown': Colors.brown,
      'grey': Colors.grey,
      'gray': Colors.grey,
    };
    return named[normalized];
  }

  Widget _variantColorSwatches(List<String> colorHexes, {double size = 14}) {
    if (colorHexes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: colorHexes.map((hex) {
        final color = _colorForOption(hex) ?? AppTheme.accent;
        final isLight = color.computeLuminance() > 0.75;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: isLight ? AppTheme.secondary : AppTheme.border,
              width: 0.8,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVariantSelector(
    Product product,
    ProductVariant? selectedVariant,
  ) {
    final labels = _variantOptionLabels(product);
    final options = _variantOptions(product);
    if (options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPTIONS',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: product.variants.map((variant) {
              final selected = selectedVariant?.id == variant.id;
              final available = variant.stockQuantity > 0;
              return ChoiceChip(
                showCheckmark: false,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(variant.displayName),
                    if (variant.colorHexes.isNotEmpty) ...[
                      const SizedBox(width: 7),
                      _variantColorSwatches(variant.colorHexes, size: 12),
                    ],
                  ],
                ),
                selected: selected,
                onSelected: available
                    ? (_) {
                        setState(() {
                          _selectedVariant = variant;
                          _selectedVariantOptions
                            ..clear()
                            ..addAll(_optionsForVariant(variant));
                          if (_quantity > variant.stockQuantity) {
                            _quantity = variant.stockQuantity > 0
                                ? variant.stockQuantity
                                : 1;
                          }
                        });
                        _focusVariantImage(product, variant);
                      }
                    : null,
              );
            }).toList(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...options.entries.map((entry) {
          final label = labels[entry.key]?.isNotEmpty == true
              ? labels[entry.key]!
              : entry.key;
          final isColor = entry.key.contains('color') ||
              label.toLowerCase().contains('color');
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.value.map((value) {
                    final selected =
                        _selectedVariantOptions[entry.key] == value;
                    final available =
                        _optionAvailable(product, entry.key, value);
                    final color = isColor ? _colorForOption(value) : null;
                    if (isColor) {
                      return Tooltip(
                        message: value,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: available
                              ? () => _selectVariantOption(
                                  product, entry.key, value)
                              : null,
                          child: Opacity(
                            opacity: available ? 1 : 0.35,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                  width: selected ? 1.4 : 0.8,
                                ),
                                color: selected
                                    ? AppTheme.primary.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.55),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color ?? AppTheme.accent,
                                      border: Border.all(
                                        color: (color ?? AppTheme.accent)
                                                    .computeLuminance() >
                                                0.75
                                            ? AppTheme.secondary
                                            : AppTheme.border,
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(value),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return ChoiceChip(
                      showCheckmark: false,
                      label: Text(value),
                      selected: selected,
                      onSelected: available
                          ? (_) =>
                              _selectVariantOption(product, entry.key, value)
                          : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
        if (selectedVariant != null) ...[
          Text(
            selectedVariant.stockQuantity > 0
                ? '${selectedVariant.stockQuantity} available'
                : 'Selected option is sold out',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: selectedVariant.stockQuantity > 0
                  ? AppTheme.secondary
                  : const Color(0xFFBA1A1A),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadProductReviews() async {
    if (!mounted) return;
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (!appState.reviewsEnabled) {
        setState(() {
          _productReviews = [];
          _loadingReviews = false;
        });
        return;
      }
      setState(() => _loadingReviews = true);
      final reviews = await appState.api.listReviews(
        productId: widget.product.id,
      );
      if (mounted) {
        setState(() {
          _productReviews = _mergeReviewsById(
            reviews,
            appState.reviewsForProduct(widget.product.id),
          );
          _loadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load product reviews: $e");
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        setState(() {
          _productReviews = appState.reviewsForProduct(widget.product.id);
          _loadingReviews = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _mergeReviewsById(
    List<Map<String, dynamic>> primary,
    List<Map<String, dynamic>> fallback,
  ) {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final review in [...primary, ...fallback]) {
      final key = [
        review['id']?.toString() ?? '',
        review['product_id']?.toString() ?? '',
        review['created_at']?.toString() ?? '',
      ].join('|');
      if (seen.add(key)) {
        merged.add(review);
      }
    }

    return merged;
  }

  bool _hasUserReviewedProduct(AppState appState) {
    if (!appState.isCustomerSignedIn) return false;
    final customerId = appState.customerSession?.customerId;
    if (customerId == null) return false;
    return appState.myReviews.any(
      (r) =>
          r['product_id']?.toString() == widget.product.id &&
          r['id']?.toString().startsWith('local-') != true,
    );
  }

  Future<void> _showWriteReviewSheet(
      BuildContext context, AppState appState) async {
    int selectedRating = 5;
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'WRITE A REVIEW',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.name,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Star rating
                    Text(
                      'YOUR RATING',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedRating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              i < selectedRating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: i < selectedRating
                                  ? const Color(0xFFE5B556)
                                  : AppTheme.secondary.withValues(alpha: 0.3),
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    TextField(
                      controller: titleController,
                      style: GoogleFonts.manrope(
                          fontSize: 14, color: AppTheme.primary),
                      decoration: InputDecoration(
                        hintText: 'Review title (optional)',
                        hintStyle: GoogleFonts.manrope(
                            fontSize: 13, color: AppTheme.secondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Body
                    TextField(
                      controller: bodyController,
                      style: GoogleFonts.manrope(
                          fontSize: 14, color: AppTheme.primary),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Share your experience...',
                        hintStyle: GoogleFonts.manrope(
                            fontSize: 13, color: AppTheme.secondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setSheetState(() => isSubmitting = true);
                                try {
                                  await appState.submitReview(
                                    productId: widget.product.id,
                                    rating: selectedRating,
                                    title: titleController.text.trim().isEmpty
                                        ? null
                                        : titleController.text.trim(),
                                    body: bodyController.text.trim().isEmpty
                                        ? null
                                        : bodyController.text.trim(),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!context.mounted) return;
                                  showTopToast(context,
                                      'Review submitted successfully!');
                                  _loadProductReviews();
                                } catch (e) {
                                  setSheetState(() => isSubmitting = false);
                                  if (ctx.mounted) {
                                    showTopToast(
                                        ctx,
                                        e
                                            .toString()
                                            .replaceAll('Exception: ', ''));
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              )
                            : Text(
                                'SUBMIT REVIEW',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteReview(AppState appState, int reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Review',
          style: GoogleFonts.ebGaramond(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this review? This action cannot be undone.',
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.secondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.manrope(color: AppTheme.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.manrope(
                    color: const Color(0xFFBA1A1A),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await appState.deleteReview(reviewId);
      if (mounted) {
        showTopToast(context, 'Review deleted');
        _loadProductReviews();
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, 'Failed to delete review');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final canCheckout = appState.checkoutEnabled;
    final product = _liveProduct ?? widget.product;
    final selectedVariant = _selectedVariant != null
        ? product.variants
            .where((variant) => variant.id == _selectedVariant!.id)
            .cast<ProductVariant?>()
            .firstWhere((variant) => variant != null, orElse: () => null)
        : null;
    final galleryImages = _galleryImages(product, selectedVariant);
    final promoInfo = appState.getPromotionForProduct(product);
    final discountedPrice = promoInfo?['discountedPrice'] as double?;
    final discountLabel = promoInfo?['discountLabel'] as String?;
    final displayPrice = _priceForSelection(
      product: product,
      variant: selectedVariant,
      discountedProductPrice: discountedPrice,
    );
    final originalDisplayPrice = selectedVariant?.price ?? product.price;
    final selectedStock =
        selectedVariant?.stockQuantity ?? product.availableStockQuantity;
    final requiresVariant = product.variants.isNotEmpty;
    final variantOptions = _variantOptions(product);
    final hasSelectedRequiredOptions = variantOptions.isEmpty ||
        variantOptions.keys.every(
            (code) => _selectedVariantOptions[code]?.trim().isNotEmpty == true);
    final canAddSelected = canCheckout &&
        selectedStock > 0 &&
        (!requiresVariant ||
            (selectedVariant != null && hasSelectedRequiredOptions));
    final showWholesaleOriginal = discountedPrice == null &&
        selectedVariant == null &&
        appState.isWholesaleMode &&
        product.retailPrice != null &&
        product.retailPrice! > product.price;
    final hasReviewed = _hasUserReviewedProduct(appState);
    final currentCustomerId = appState.customerSession?.customerId;

    if (!appState.productsEnabled) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: AppTheme.background, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Product browsing is unavailable for this store.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppTheme.secondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppRefresh(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Elegant Header with Full-Bleed Product Image
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              backgroundColor: AppTheme.background,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'product_img_${product.id}',
                      child: galleryImages.isEmpty
                          ? Container(
                              color: AppTheme.border.withValues(alpha: 0.35),
                              child: Icon(Icons.spa_outlined,
                                  size: 48, color: AppTheme.secondary),
                            )
                          : PageView.builder(
                              controller: _imagePageController,
                              itemCount: galleryImages.length,
                              onPageChanged: (index) {
                                setState(() => _selectedImageIndex = index);
                              },
                              itemBuilder: (context, index) {
                                final image = galleryImages[index];
                                return ShimmerImage(
                                  imageUrl: image.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorWidget: Container(
                                    color:
                                        AppTheme.border.withValues(alpha: 0.35),
                                    child: Icon(Icons.spa_outlined,
                                        size: 48, color: AppTheme.secondary),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (galleryImages.length > 1)
                      Positioned(
                        bottom: 18,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(galleryImages.length, (i) {
                            final selected = i ==
                                _selectedImageIndex.clamp(
                                    0, galleryImages.length - 1);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: selected ? 18 : 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back,
                        color: AppTheme.primary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: Icon(
                        appState.isInWishlist(product)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: appState.isInWishlist(product)
                            ? Colors.redAccent
                            : AppTheme.primary,
                        size: 20,
                      ),
                      onPressed: () {
                        appState.toggleWishlist(product);
                        showTopToast(
                          context,
                          appState.isInWishlist(product)
                              ? '${product.name} added to wishlist'
                              : '${product.name} removed from wishlist',
                        );
                      },
                      tooltip: 'Wishlist',
                    ),
                  ),
                ),
                if (canCheckout)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      child: IconButton(
                        icon: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                color: AppTheme.primary, size: 20),
                            if (appState.cart.isNotEmpty)
                              Positioned(
                                top: -5,
                                right: -5,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFBA1A1A),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 12,
                                    minHeight: 12,
                                  ),
                                  child: Center(
                                    child: Text(
                                      appState.cart
                                          .fold(
                                              0,
                                              (sum, item) =>
                                                  sum + item.quantity)
                                          .toString(),
                                      style: const TextStyle(
                                        fontSize: 7.5,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () {
                          appState.goToCartTab();
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        tooltip: 'Cart',
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            // Product Information
            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.background,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category & Volume tags
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: AppTheme.border, width: 0.5),
                          ),
                          child: Text(
                            product.category.toUpperCase(),
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          [
                            product.measurementLabel,
                            if (product.measurementLabel.isEmpty)
                              product.volume,
                          ].where((value) => value.trim().isNotEmpty).join(''),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Product Name in EB Garamond
                    Text(
                      product.name,
                      style: GoogleFonts.ebGaramond(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Rating details
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFE5B556), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          product.rating.toString(),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        if (appState.reviewsEnabled) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${_productReviews.isNotEmpty ? _productReviews.length : product.reviewsCount} reviews)',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Price tag
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '\$${displayPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        if (discountedPrice != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            '\$${originalDisplayPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              color: const Color(0xFF9E9E9E),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF070F0A),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              discountLabel?.toUpperCase() ?? 'SALE',
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ] else if (showWholesaleOriginal) ...[
                          const SizedBox(width: 10),
                          Text(
                            '\$${product.retailPrice!.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              color: const Color(0xFF9E9E9E),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (product.variants.isNotEmpty) ...[
                      _buildVariantSelector(product, selectedVariant),
                      const SizedBox(height: 20),
                    ],
                    Divider(color: AppTheme.border, thickness: 0.6),
                    const SizedBox(height: 20),
                    // Product Description
                    Text(
                      'THE ELIXIR',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.shortDescription,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AppTheme.primary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Reviews Section
                    if (appState.reviewsEnabled) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CUSTOMER REVIEWS',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (appState.isCustomerSignedIn && !hasReviewed)
                            GestureDetector(
                              onTap: () =>
                                  _showWriteReviewSheet(context, appState),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: AppTheme.primary, width: 1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'WRITE A REVIEW',
                                  style: GoogleFonts.manrope(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (hasReviewed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 14,
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.6)),
                              const SizedBox(width: 6),
                              Text(
                                'You\'ve reviewed this product',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_loadingReviews)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.secondary,
                              ),
                            ),
                          ),
                        )
                      else if (_productReviews.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No reviews yet. Be the first to share your experience!',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.secondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 195,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _productReviews.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final review = _productReviews[index];
                              final isOwned = currentCustomerId != null &&
                                  review['customer_id']?.toString() ==
                                      currentCustomerId.toString();
                              final rating =
                                  (review['rating'] as num?)?.toInt() ?? 5;
                              final name =
                                  review['reviewer_name']?.toString() ??
                                      'Customer';
                              final title = review['title']?.toString() ?? '';
                              final body = (review['body'] ?? review['comment'])
                                      ?.toString() ??
                                  '';
                              final adminReply =
                                  review['admin_reply']?.toString() ?? '';
                              final dateStr = review['created_at'] != null
                                  ? _formatDate(review['created_at'].toString())
                                  : '';

                              return Container(
                                width: MediaQuery.of(context).size.width * 0.8,
                                margin:
                                    const EdgeInsets.only(right: 12, bottom: 6),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                  border: Border.all(
                                      color: AppTheme.border
                                          .withValues(alpha: 0.6)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: List.generate(
                                                      5,
                                                      (i) => Icon(
                                                            i < rating
                                                                ? Icons
                                                                    .star_rounded
                                                                : Icons
                                                                    .star_outline_rounded,
                                                            color: i < rating
                                                                ? const Color(
                                                                    0xFFE5B556)
                                                                : AppTheme
                                                                    .secondary
                                                                    .withValues(
                                                                        alpha:
                                                                            0.2),
                                                            size: 14,
                                                          )),
                                                ),
                                                if (isOwned)
                                                  GestureDetector(
                                                    onTap: () {
                                                      final reviewId =
                                                          review['id'];
                                                      if (reviewId is num) {
                                                        _deleteReview(appState,
                                                            reviewId.toInt());
                                                      }
                                                    },
                                                    child: Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 16,
                                                      color: AppTheme.secondary
                                                          .withValues(
                                                              alpha: 0.5),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (title.isNotEmpty) ...[
                                              Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                            ],
                                            if (body.isNotEmpty) ...[
                                              Text(
                                                body,
                                                maxLines: adminReply.isNotEmpty
                                                    ? 2
                                                    : 4,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12,
                                                  color: AppTheme.secondary,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                            if (adminReply.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary
                                                      .withValues(alpha: 0.04),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .storefront_outlined,
                                                        size: 12,
                                                        color:
                                                            AppTheme.primary),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        adminReply,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.manrope(
                                                          fontSize: 10.5,
                                                          color:
                                                              AppTheme.primary,
                                                          height: 1.3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        if (dateStr.isNotEmpty)
                                          Text(
                                            dateStr,
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              color: AppTheme.secondary
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

                    // Application ritual card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.8),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Icon(Icons.self_improvement_outlined,
                              color: AppTheme.primary),
                          title: Text(
                            'How To Use',
                            style: GoogleFonts.ebGaramond(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 20, right: 20, bottom: 20),
                              child: Text(
                                product.description,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppTheme.secondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                        height: 120), // Spacing for absolute bottom sheet
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Sticky Flat Bottom Buy Bar
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              offset: const Offset(0, -4),
              blurRadius: 8,
            ),
          ],
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 0.8),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (canAddSelected) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border, width: 0.8),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove,
                            size: 14, color: AppTheme.primary),
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        },
                      ),
                      Text(
                        _quantity.toString(),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon:
                            Icon(Icons.add, size: 14, color: AppTheme.primary),
                        onPressed: () {
                          if (_quantity < selectedStock) {
                            setState(() => _quantity++);
                          } else {
                            showTopToast(
                              context,
                              'Only $selectedStock items in stock.',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: canAddSelected
                    ? ElevatedButton(
                        onPressed: () {
                          final added = appState.addToCart(
                            product,
                            quantity: _quantity,
                            variant: selectedVariant,
                          );
                          final itemName = selectedVariant == null
                              ? product.name
                              : '${product.name} - ${selectedVariant.displayName}';
                          showTopToast(
                            context,
                            added
                                ? '$_quantity x $itemName added to bag'
                                : 'Only $selectedStock items in stock.',
                          );
                        },
                        child: Text(
                            'ADD TO BAG - \$${(displayPrice * _quantity).toStringAsFixed(2)}'),
                      )
                    : Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(
                            !canCheckout
                                ? 'CHECKOUT DISABLED'
                                : requiresVariant && selectedVariant == null
                                    ? 'SELECT OPTIONS'
                                    : 'SOLD OUT',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
