import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';

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

    final formattedPrice = product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2);

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
                  color: const Color(0xFFF2F4F0), // bg-surface-container-low matching mockup
                  child: Stack(
                    children: [
                      // Product Image without padding, covering the square box
                      product.imageUrl.isNotEmpty
                          ? Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) => const Center(
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
                      // Badge (Discount or Category)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: discountLabel != null && discountLabel!.isNotEmpty ? 10 : 6,
                              vertical: discountLabel != null && discountLabel!.isNotEmpty ? 5 : 3),
                          decoration: BoxDecoration(
                            color: discountLabel != null && discountLabel!.isNotEmpty
                                ? const Color(0xFF070F0A)
                                : Colors.white.withValues(alpha: 0.8),
                            borderRadius: discountLabel != null && discountLabel!.isNotEmpty
                                ? BorderRadius.circular(100)
                                : BorderRadius.circular(2),
                            border: discountLabel != null && discountLabel!.isNotEmpty
                                ? null
                                : Border.all(color: const Color(0xFFE5E7E2), width: 0.5),
                          ),
                          child: Text(
                            (discountLabel ?? product.category).toUpperCase(),
                            style: GoogleFonts.manrope(
                              fontSize: discountLabel != null && discountLabel!.isNotEmpty ? 9 : 8,
                              fontWeight: FontWeight.bold,
                              color: discountLabel != null && discountLabel!.isNotEmpty
                                  ? Colors.white
                                  : const Color(0xFF070F0A),
                              letterSpacing: discountLabel != null && discountLabel!.isNotEmpty ? 1.0 : 0.5,
                            ),
                          ),
                        ),
                      ),
                      // Out of stock or low stock badge
                      if (product.stockQuantity == 0)
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
                        )
                      else if (product.stockQuantity <= 3)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBA1A1A),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              'ONLY ${product.stockQuantity} LEFT',
                              style: GoogleFonts.manrope(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
