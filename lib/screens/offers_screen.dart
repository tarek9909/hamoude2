import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/app_refresh.dart';
import '../widgets/product_card.dart';

class OffersScreen extends StatelessWidget {
  final String? selectedPromoId;

  const OffersScreen({super.key, this.selectedPromoId});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    if (!appState.promotionsEnabled) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: AppTheme.background, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'Promotions are unavailable for this store.',
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

    // Resolve unique promoted products with their discounted prices
    final List<Map<String, dynamic>> promoProducts = [];
    String headerTitle = 'OFFERS';
    String description = '';

    final List<Map<String, dynamic>> activePromos = [];
    if (appState.promotions.isNotEmpty) {
      if (selectedPromoId != null) {
        final match = appState.promotions
            .where((p) =>
                p['id']?.toString() == selectedPromoId ||
                p['name']?.toString() == selectedPromoId)
            .toList();
        if (match.isNotEmpty) {
          activePromos.add(match.first);
        }
      } else {
        activePromos.addAll(appState.promotions);
      }
    }

    if (activePromos.isNotEmpty) {
      if (selectedPromoId != null) {
        final promo = activePromos.first;
        headerTitle = promo['name']?.toString() ??
            promo['title']?.toString() ??
            'SPECIAL DEAL';
        description = promo['description']?.toString() ??
            promo['subtitle']?.toString() ??
            '';
      }

      for (final promo in activePromos) {
        final title =
            promo['name']?.toString() ?? promo['title']?.toString() ?? '';
        final discountType = promo['discount_type']?.toString() ?? 'percentage';
        final discountVal =
            (promo['discount_value'] as num?)?.toDouble() ?? 20.0;
        final discountLabel = promo['discount_label']?.toString() ??
            promo['badge']?.toString() ??
            (discountType == 'percentage'
                ? '-${discountVal.toStringAsFixed(0)}% OFF'
                : 'SPECIAL OFFER');

        final rawItems = promo['product_links'] as List? ?? [];
        final matchingProducts = <Product>[];
        if (rawItems.isNotEmpty) {
          for (final link in rawItems) {
            final prodId = link['product_id']?.toString();
            try {
              final p = appState.products
                  .firstWhere((prod) => Product.compareIds(prod.id, prodId));
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
          double discPrice = product.price;
          final promoPriceStr = promo['price']?.toString();
          if (matchingProducts.length == 1 &&
              promoPriceStr != null &&
              double.tryParse(promoPriceStr) != null) {
            discPrice = double.parse(promoPriceStr);
          } else {
            if (discountType == 'percentage') {
              discPrice = product.price * (1 - discountVal / 100);
            } else {
              discPrice =
                  (product.price - discountVal).clamp(0.0, double.infinity);
            }
          }

          final exists =
              promoProducts.any((item) => item['product'].id == product.id);
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        centerTitle: true,
        title: Text(
          headerTitle.toUpperCase(),
          style: GoogleFonts.ebGaramond(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: colors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    color: colors.primary, size: 22),
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
                              .fold(0, (sum, item) => sum + item.quantity)
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
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            tooltip: 'Cart',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AppRefresh(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              if (promoProducts.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty) ...[
                          Text(
                            description,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: const Color(0xFF5E5E5B),
                            ),
                          ),
                        ],
                        const Divider(height: 24, thickness: 0.8),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.63,
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
              ],
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
