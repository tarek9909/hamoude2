import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'product_detail_screen.dart';

class PromotionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> promotion;

  const PromotionDetailScreen({super.key, required this.promotion});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    final title = promotion['name']?.toString() ??
        promotion['title']?.toString() ??
        "Weekly Deal";

    final tag = promotion['discount_label']?.toString() ??
        promotion['badge']?.toString() ??
        "SPECIAL PROMOTION";

    final description = promotion['description']?.toString() ??
        "Exclusive promotional offer for targeted botanical results.";

    final imageUrl = promotion['image_url']?.toString() ??
        promotion['media_url']?.toString() ??
        "https://images.unsplash.com/photo-1556228578-0d85b1a4d571?q=80&w=400&auto=format&fit=crop";

    final price = promotion['price']?.toString() ?? "38";
    final originalPrice = promotion['original_price']?.toString() ??
        promotion['compare_at_price']?.toString() ??
        "48";

    final discountType = promotion['discount_type']?.toString() ?? "percentage";
    final discountVal = (promotion['discount_value'] as num?)?.toDouble() ?? 20.0;

    // Resolve matching products
    final rawItems = promotion['product_links'] as List? ?? [];
    final matchingProducts = <Product>[];
    if (rawItems.isNotEmpty) {
      for (final link in rawItems) {
        final prodId = link['product_id']?.toString();
        try {
          final p = appState.products.firstWhere((prod) => prod.id == prodId);
          matchingProducts.add(p);
        } catch (_) {}
      }
    }
    if (matchingProducts.isEmpty) {
      try {
        final p = appState.products.firstWhere(
          (prod) => prod.name.toLowerCase() == title.toLowerCase(),
        );
        matchingProducts.add(p);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF5),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Elegant Header with Hero Promotion Image
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

          // Promotion Information
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag & Promotion type badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070F0A),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          tag.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Text(
                        discountType == 'percentage'
                            ? '${discountVal.toStringAsFixed(0)}% OFF'
                            : 'FIXED DISCOUNT',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7E807C),
                          letterSpacing: 1.0,
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

                  // Pricing Row (if it's a specific product promo, show price comparison)
                  if (matchingProducts.length == 1) ...[
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
                  ],
                  const Divider(color: Color(0xFFE5E7E2), thickness: 0.8),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'THE OFFER',
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

                  // Applicable Formulas Section
                  Text(
                    'APPLICABLE FORMULAS',
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
          if (matchingProducts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Applies to all products in catalog.',
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
                    final product = matchingProducts[index];

                    // Calculate individual discounted price
                    double discPrice = product.price;
                    if (matchingProducts.length == 1) {
                      discPrice = double.tryParse(price) ?? product.price;
                    } else {
                      if (discountType == 'percentage') {
                        discPrice = product.price * (1 - discountVal / 100);
                      } else {
                        discPrice = (product.price - discountVal).clamp(0.0, double.infinity);
                      }
                    }

                    final formattedPrice = discPrice.toStringAsFixed(discPrice % 1 == 0 ? 0 : 2);
                    final formattedOriginalPrice = product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2);

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
                            child: product.imageUrl.isNotEmpty
                                ? Image.network(
                                    product.imageUrl,
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
                          product.name,
                          style: GoogleFonts.ebGaramond(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF070F0A),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              '${product.category} - ${product.volume}',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: const Color(0xFF7E807C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '\$$formattedPrice',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF070F0A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '\$$formattedOriginalPrice',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: const Color(0xFF9E9E9E),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Color(0xFF7E807C),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                product: product,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: matchingProducts.length,
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
              onPressed: matchingProducts.isEmpty
                  ? null
                  : () {
                      for (final product in matchingProducts) {
                        appState.addToCart(product);
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Offer items added to bag.'),
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
                matchingProducts.length == 1
                    ? 'ADD TO BAG – \$$price'
                    : 'ADD ALL FORMULAS TO BAG',
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
