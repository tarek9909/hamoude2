import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    // Resolve unique promoted products with their discounted prices
    final List<Map<String, dynamic>> promoProducts = [];
    if (appState.promotionsEnabled && appState.promotions.isNotEmpty) {
      for (final promo in appState.promotions) {
        final title = promo['name']?.toString() ?? promo['title']?.toString() ?? '';
        final discountType = promo['discount_type']?.toString() ?? 'percentage';
        final discountVal = (promo['discount_value'] as num?)?.toDouble() ?? 20.0;
        final discountLabel = promo['discount_label']?.toString() ?? 
            promo['badge']?.toString() ?? 
            (discountType == 'percentage' ? '-${discountVal.toStringAsFixed(0)}% OFF' : 'SPECIAL OFFER');

        final rawItems = promo['product_links'] as List? ?? [];
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

        for (final product in matchingProducts) {
          // Calculate discounted price
          double discPrice = product.price;
          final promoPriceStr = promo['price']?.toString();
          if (matchingProducts.length == 1 && promoPriceStr != null && double.tryParse(promoPriceStr) != null) {
            discPrice = double.parse(promoPriceStr);
          } else {
            if (discountType == 'percentage') {
              discPrice = product.price * (1 - discountVal / 100);
            } else {
              discPrice = (product.price - discountVal).clamp(0.0, double.infinity);
            }
          }

          // Check if product is already added (e.g. from another promotion)
          final exists = promoProducts.any((item) => item['product'].id == product.id);
          if (!exists) {
            promoProducts.add({
              'product': product,
              'discountedPrice': discPrice,
              'discountLabel': discountLabel,
              'promotion': promo,
            });
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAF5),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        centerTitle: true,
        title: Text(
          'WEEKLY DEALS',
          style: GoogleFonts.ebGaramond(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
            color: colors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Weekly Deals Section
            if (appState.promotionsEnabled && promoProducts.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Deals',
                        style: GoogleFonts.ebGaramond(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF070F0A),
                        ),
                      ),
                      const SizedBox(height: 6),
                    
                      const Divider(height: 24, thickness: 0.8),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = promoProducts[index];
                      final product = item['product'] as Product;
                      final discPrice = item['discountedPrice'] as double;
                      final discount = item['discountLabel'] as String;
                      return ProductCard(
                        product: product,
                        discountedPrice: discPrice,
                        discountLabel: discount,
                      );
                    },
                    childCount: promoProducts.length,
                  ),
                ),
              ),
            ] else ...[
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.spa_outlined, size: 40, color: AppTheme.border),
                      const SizedBox(height: 12),
                      Text(
                        'No promotions active.',
                        style: GoogleFonts.ebGaramond(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Safe bottom margin for notches
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }
}
