import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'product_detail_screen.dart';
import '../widgets/top_toast.dart';
import '../widgets/app_shimmer.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final wishlist = appState.wishlist;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_new, color: AppTheme.primary, size: 20),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        centerTitle: true,
        title: Text(
          'MY WISHLIST',
          style: GoogleFonts.ebGaramond(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
            color: AppTheme.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: wishlist.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 64,
                        color: AppTheme.border.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your wishlist is empty',
                        style: GoogleFonts.ebGaramond(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save items that you love here to easily purchase them later.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.secondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: wishlist.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = wishlist[index];
                  final isOutOfStock = product.availableStockQuantity <= 0;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProductDetailScreen(product: product),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.border.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Product Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ShimmerImage(
                              imageUrl: product.imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                color: AppTheme.border.withValues(alpha: 0.3),
                                width: 80,
                                height: 80,
                                child: Icon(
                                  Icons.spa_outlined,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Product Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.primary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${product.price.toStringAsFixed(2)}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Actions (Add to Bag & Remove)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.favorite,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () {
                                  appState.toggleWishlist(product);
                                  showTopToast(
                                    context,
                                    'Removed from wishlist',
                                  );
                                },
                                tooltip: 'Remove',
                              ),
                              const SizedBox(height: 4),
                              if (appState.checkoutEnabled)
                                isOutOfStock
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.border,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'SOLD OUT',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.secondary,
                                          ),
                                        ),
                                      )
                                    : ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () {
                                          if (product.variants.length > 1) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ProductDetailScreen(
                                                        product: product),
                                              ),
                                            );
                                            showTopToast(context,
                                                'Select options before adding.');
                                            return;
                                          }
                                          final variant =
                                              product.variants.length == 1
                                                  ? product.variants.first
                                                  : null;
                                          final added = appState.addToCart(
                                              product,
                                              variant: variant);
                                          final stockQuantity =
                                              variant?.stockQuantity ??
                                                  product.stockQuantity;
                                          showTopToast(
                                            context,
                                            added
                                                ? '${product.name} added to bag'
                                                : 'Only $stockQuantity items in stock.',
                                          );
                                        },
                                        child: Text(
                                          'ADD TO BAG',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
