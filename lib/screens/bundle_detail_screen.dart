import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_refresh.dart';
import '../widgets/top_toast.dart';
import 'product_detail_screen.dart';

double? _parseAmount(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _formatAmount(double value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
}

class BundleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> bundle;

  const BundleDetailScreen({super.key, required this.bundle});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    final title =
        bundle['name']?.toString() ?? bundle['title']?.toString() ?? "Bundle";

    final tag = bundle['subtitle']?.toString() ??
        bundle['tag']?.toString() ??
        "COLLECTION";

    final description = bundle['description']?.toString() ??
        bundle['summary']?.toString() ??
        "";

    final imageUrl = bundle['image_url']?.toString() ??
        bundle['media_url']?.toString() ??
        "";

    // Extract list of items
    final rawItems = bundle['items'] as List? ?? [];
    final itemsList = rawItems.whereType<Map<String, dynamic>>().toList();

    double computedOriginalPrice = 0.0;
    for (final item in itemsList) {
      final prodId = item['product_id']?.toString() ?? '';
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      Product? p;
      try {
        p = appState.products
            .firstWhere((entry) => Product.compareIds(entry.id, prodId));
      } catch (_) {}
      final itemPrice =
          p?.price ?? (item['unit_price_snapshot'] as num?)?.toDouble() ?? 0.0;
      computedOriginalPrice += itemPrice * qty;
    }

    final explicitBundlePrice =
        _parseAmount(bundle['bundle_price']) ?? _parseAmount(bundle['price']);
    final effectiveBundlePrice = explicitBundlePrice ??
        (computedOriginalPrice > 0 ? computedOriginalPrice : null);
    final price = effectiveBundlePrice != null
        ? _formatAmount(effectiveBundlePrice)
        : null;
    final originalPrice = explicitBundlePrice != null &&
            computedOriginalPrice > explicitBundlePrice
        ? _formatAmount(computedOriginalPrice)
        : null;

    final bundleType = bundle['bundle_type']?.toString() ?? "fixed_price";

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AppRefresh(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Elegant Header with Hero Bundle Image
            SliverAppBar(
              expandedHeight: 350,
              pinned: true,
              backgroundColor: AppTheme.background,
              flexibleSpace: FlexibleSpaceBar(
                background: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.border.withValues(alpha: 0.35),
                          child: Icon(Icons.spa_outlined,
                              size: 48, color: AppTheme.secondary),
                        ),
                      )
                    : Container(
                        color: AppTheme.border.withValues(alpha: 0.35),
                        child: Icon(Icons.spa_outlined,
                            size: 48, color: AppTheme.secondary),
                      ),
              ),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: colors.primary, size: 18),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                ),
              ),
              actions: [
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
                              color: colors.primary, size: 20),
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
                                        .fold(0,
                                            (sum, item) => sum + item.quantity)
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

            // Bundle Information
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag & Bundle type badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tag.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF7E807C),
                            letterSpacing: 2.0,
                          ),
                        ),
                        if (bundleType != 'fixed_price')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF070F0A),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              bundleType == 'buy_x_get_y'
                                  ? "BUY X GET Y"
                                  : "SPECIAL DEAL",
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      title,
                      style: GoogleFonts.ebGaramond(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF070F0A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (price != null) ...[
                      Row(
                        children: [
                          Text(
                            '\$$price',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF070F0A),
                            ),
                          ),
                          if (originalPrice != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              '\$$originalPrice',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                color: const Color(0xFF9E9E9E),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Divider(color: Color(0xFFE5E7E2), thickness: 0.8),
                    const SizedBox(height: 16),

                    // Description
                    if (description.isNotEmpty) ...[
                      Text(
                        'Description',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7E807C),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: const Color(0xFF4A554A),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Included Essentials Section
                    Text(
                      'INCLUDED ESSENTIALS',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF7E807C),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Items List
            if (itemsList.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'No items listed in this bundle.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: const Color(0xFF7E807C),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = itemsList[index];
                      final productId = item['product_id']?.toString() ?? '';
                      final requiredQty =
                          (item['quantity'] as num?)?.toInt() ?? 1;

                      // Attempt to lookup product from AppState to get images/pricing
                      Product? matchedProduct;
                      try {
                        matchedProduct = appState.products.firstWhere(
                          (p) => Product.compareIds(p.id, productId),
                        );
                      } catch (_) {
                        matchedProduct = null;
                      }

                      final name = matchedProduct?.name ??
                          item['product_name']?.toString() ??
                          "Product";
                      final variantName =
                          item['variant_name']?.toString() ?? "";
                      final productImgUrl = matchedProduct?.imageUrl ?? "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7E2),
                            width: 0.8,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: productImgUrl.isNotEmpty
                                  ? Image.network(
                                      productImgUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFFF2F4F0),
                                        child: const Icon(
                                          Icons.spa_outlined,
                                          color: Color(0xFF7E807C),
                                          size: 24,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFF2F4F0),
                                      child: const Icon(
                                        Icons.spa_outlined,
                                        color: Color(0xFF7E807C),
                                        size: 24,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.ebGaramond(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF070F0A),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (variantName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Variant: $variantName',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: const Color(0xFF7E807C),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Quantity: $requiredQty',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF070F0A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: matchedProduct != null
                              ? const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Color(0xFF7E807C),
                                )
                              : null,
                          onTap: matchedProduct != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(
                                        product: matchedProduct!,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      );
                    },
                    childCount: itemsList.length,
                  ),
                ),
              ),

            // Extra spacing at the bottom
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7E2), width: 0.8),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: itemsList.isEmpty || effectiveBundlePrice == null
                  ? null
                  : () {
                      // Create a single Product representing the whole bundle
                      final bundleId =
                          'bundle_${bundle['id']?.toString() ?? title.hashCode.toString()}';
                      final bundleProduct = Product(
                        id: bundleId,
                        name: title,
                        description: description,
                        shortDescription: '${itemsList.length} items bundle',
                        price: effectiveBundlePrice,
                        imageUrl: imageUrl,
                        category: 'Bundle',
                        stockQuantity: 99,
                        rating: 5.0,
                        reviewsCount: 0,
                        skinTypes: const ['All Skintypes'],
                        ingredients: '',
                        volume: '',
                        brand: tag,
                      );

                      final added = appState.addToCart(bundleProduct);

                      showTopToast(
                        context,
                        added
                            ? '$title added to bag.'
                            : 'Only ${bundleProduct.stockQuantity} items in stock.',
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                price != null
                    ? 'ADD BUNDLE TO BAG - \$$price'
                    : 'ADD BUNDLE TO BAG',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
