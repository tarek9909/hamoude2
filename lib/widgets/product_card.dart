import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../screens/product_detail_screen.dart';
import 'app_shimmer.dart';
import 'top_toast.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final double? discountedPrice;
  final String? discountLabel;

  const ProductCard({
    super.key,
    required this.product,
    this.discountedPrice,
    this.discountLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve dynamic subtitle/benefit
    final subtitle = product.subtitle;
    final retailPrice = product.retailPrice;

    final formattedPrice =
        product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2);
    final availableStockQuantity = product.availableStockQuantity;
    final showWholesaleOriginal = discountedPrice == null &&
        retailPrice != null &&
        retailPrice > product.price;
    final formattedRetailPrice =
        retailPrice?.toStringAsFixed(retailPrice % 1 == 0 ? 0 : 2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ProductDetailScreen(product: product),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            ),
          );
        },
        child: Container(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image Container with 4:5 Aspect Ratio
              AspectRatio(
                aspectRatio: 1.0, // Equally square
                child: Container(
                  color: const Color(
                      0xFFF2F4F0), // bg-surface-container-low matching mockup
                  child: Stack(
                    children: [
                      // Product Image without padding, covering the square box
                      product.imageUrl.isNotEmpty
                          ? ShimmerImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorWidget: const Center(
                                child: Icon(
                                  Icons.spa_outlined,
                                  size: 32,
                                  color: Color(0xFF7E807C),
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.spa_outlined,
                                size: 32,
                                color: Color(0xFF7E807C),
                              ),
                            ),
                      // Badge row: long category labels and stock pills share
                      // one bounded row so they never collide on small cards.
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 26),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: discountLabel != null &&
                                            discountLabel!.isNotEmpty
                                        ? 10
                                        : 8,
                                    vertical: discountLabel != null &&
                                            discountLabel!.isNotEmpty
                                        ? 5
                                        : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: discountLabel != null &&
                                            discountLabel!.isNotEmpty
                                        ? const Color(0xFF070F0A)
                                        : Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(
                                      discountLabel != null &&
                                              discountLabel!.isNotEmpty
                                          ? 100
                                          : 4,
                                    ),
                                    border: discountLabel != null &&
                                            discountLabel!.isNotEmpty
                                        ? null
                                        : Border.all(
                                            color: const Color(0xFFE5E7E2),
                                            width: 0.5,
                                          ),
                                  ),
                                  child: Text(
                                    (discountLabel ?? product.category)
                                        .toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: GoogleFonts.manrope(
                                      fontSize: discountLabel != null &&
                                              discountLabel!.isNotEmpty
                                          ? 9
                                          : 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: discountLabel != null &&
                                              discountLabel!.isNotEmpty
                                          ? Colors.white
                                          : const Color(0xFF070F0A),
                                      letterSpacing: discountLabel != null &&
                                              discountLabel!.isNotEmpty
                                          ? 0.7
                                          : 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (availableStockQuantity > 0 &&
                                availableStockQuantity <= 3) ...[
                              const SizedBox(width: 6),
                              Container(
                                constraints:
                                    const BoxConstraints(minHeight: 26),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFBA1A1A),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$availableStockQuantity LEFT',
                                  maxLines: 1,
                                  style: GoogleFonts.manrope(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Out of stock or low stock badge
                      if (availableStockQuantity == 0)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF070F0A),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  'SOLD OUT',
                                  style: GoogleFonts.manrope(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Add to Bag Button
                      if (availableStockQuantity > 0)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: () {
                              if (product.variants.length > 1) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      product: product,
                                    ),
                                  ),
                                );
                                showTopToast(
                                    context, 'Select options before adding.');
                                return;
                              }
                              final variant = product.variants.length == 1
                                  ? product.variants.first
                                  : null;
                              final state =
                                  Provider.of<AppState>(context, listen: false);
                              final added =
                                  state.addToCart(product, variant: variant);
                              final stockQuantity = variant?.stockQuantity ??
                                  product.stockQuantity;
                              showTopToast(
                                context,
                                added
                                    ? '${product.name} added to bag'
                                    : 'Only $stockQuantity items in stock.',
                              );
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 18,
                                color: Color(0xFF070F0A),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Text Content centered
              Text(
                product.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ebGaramond(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: const Color(0xFF070F0A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFF7E807C),
                ),
              ),
              const SizedBox(height: 6),
              if (discountedPrice != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '\$${discountedPrice!.toStringAsFixed(discountedPrice! % 1 == 0 ? 0 : 2)}',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF070F0A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$$formattedPrice',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: const Color(0xFF9E9E9E),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                )
              else if (showWholesaleOriginal)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '\$$formattedPrice',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF070F0A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$$formattedRetailPrice',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: const Color(0xFF9E9E9E),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  '\$$formattedPrice',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF070F0A),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
