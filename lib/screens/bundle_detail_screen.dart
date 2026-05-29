import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'product_detail_screen.dart';

class BundleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> bundle;

  const BundleDetailScreen({super.key, required this.bundle});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    final title = bundle['name']?.toString() ??
        bundle['title']?.toString() ??
        "The Glow Essentials";

    final tag = bundle['subtitle']?.toString() ??
        bundle['tag']?.toString() ??
        "COLLECTION";

    final description = bundle['description']?.toString() ??
        bundle['summary']?.toString() ??
        "Our signature ritual meticulously crafted to deliver radiant, deeply hydrated skin through Alpine botanicals.";

    final imageUrl = bundle['image_url']?.toString() ??
        bundle['media_url']?.toString() ??
        "https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?q=80&w=600&auto=format&fit=crop";

    // Extract list of items
    final rawItems = bundle['items'] as List? ?? [];
    final itemsList = rawItems.whereType<Map<String, dynamic>>().toList();
    
    double computedOriginalPrice = 0.0;
    for (final item in itemsList) {
      final prodId = item['product_id']?.toString() ?? '';
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      Product? p;
      try {
        p = appState.products.firstWhere((entry) => entry.id == prodId);
      } catch (_) {}
      final itemPrice = p?.price ?? (item['unit_price_snapshot'] as num?)?.toDouble() ?? 0.0;
      computedOriginalPrice += itemPrice * qty;
    }

    final bundlePriceVal = (bundle['bundle_price'] as num?)?.toDouble() ?? 
        double.tryParse(bundle['price']?.toString() ?? '') ?? 120.0;
    
    final price = bundlePriceVal.toStringAsFixed(bundlePriceVal % 1 == 0 ? 0 : 2);
    final originalPrice = computedOriginalPrice > 0 
        ? computedOriginalPrice.toStringAsFixed(computedOriginalPrice % 1 == 0 ? 0 : 2)
        : "148";

    final bundleType = bundle['bundle_type']?.toString() ?? "fixed_price";



    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF5),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Elegant Header with Hero Bundle Image
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: const Color(0xFFF8FAF5),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.border.withValues(alpha: 0.35),
                  child: Icon(Icons.spa_outlined,
                      size: 48, color: AppTheme.secondary),
                ),
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
                            bundleType == 'buy_x_get_y' ? "BUY X GET Y" : "SPECIAL DEAL",
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

                  // Pricing Row
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
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE5E7E2), thickness: 0.8),
                  const SizedBox(height: 16),

                  // Description
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
                    final requiredQty = (item['quantity'] as num?)?.toInt() ?? 1;

                    // Attempt to lookup product from AppState to get images/pricing
                    Product? matchedProduct;
                    try {
                      matchedProduct = appState.products.firstWhere(
                        (p) => p.id == productId,
                      );
                    } catch (_) {
                      matchedProduct = null;
                    }

                    final name = matchedProduct?.name ??
                        item['product_name']?.toString() ??
                        "Product";
                    final variantName = item['variant_name']?.toString() ?? "";
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
              onPressed: itemsList.isEmpty
                  ? null
                  : () {
                      int itemsAdded = 0;
                      for (final item in itemsList) {
                        final productId = item['product_id']?.toString() ?? '';
                        final requiredQty = (item['quantity'] as num?)?.toInt() ?? 1;

                        Product? matchedProduct;
                        try {
                          matchedProduct = appState.products.firstWhere(
                            (p) => p.id == productId,
                          );
                        } catch (_) {
                          matchedProduct = null;
                        }

                        if (matchedProduct != null) {
                          // Find existing quantity in the cart
                          final existingIndex = appState.cart.indexWhere(
                            (cartItem) => cartItem.product.id == matchedProduct!.id,
                          );
                          final currentQty = existingIndex >= 0
                              ? appState.cart[existingIndex].quantity
                              : 0;

                          appState.updateQuantity(
                            matchedProduct,
                            currentQty + requiredQty,
                          );
                          itemsAdded++;
                        }
                      }

                      if (itemsAdded > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$title items added to bag.'),
                            backgroundColor: const Color(0xFF070F0A),
                            duration: const Duration(seconds: 3),
                            action: SnackBarAction(
                              label: 'VIEW BAG',
                              textColor: const Color(0xFFE9E2D0),
                              onPressed: () {
                                appState.goToCartTab();
                              },
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not find bundle products in catalog.'),
                            backgroundColor: Color(0xFFBA1A1A),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF070F0A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'ADD BUNDLE TO BAG – \$$price',
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
