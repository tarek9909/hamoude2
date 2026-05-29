import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import 'bundle_detail_screen.dart';

class BundlesScreen extends StatelessWidget {
  const BundlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

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
          'BUNDLES',
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
            if (appState.bundlesEnabled && appState.bundles.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exclusive Bundles',
                        style: GoogleFonts.ebGaramond(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF070F0A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: const Color(0xFF5E5E5B),
                        ),
                      ),
                      const Divider(height: 24, thickness: 0.8),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final bundle = appState.bundles[index];
                      final imageUrl = bundle['image_url']?.toString() ??
                          bundle['media_url']?.toString() ??
                          "https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?q=80&w=600&auto=format&fit=crop";

                      final tag = bundle['subtitle']?.toString() ??
                          bundle['tag']?.toString() ??
                          (index % 2 == 0 ? "SIGNATURE COLLECTION" : "SEASONAL RECOVERY");

                      final title = bundle['name']?.toString() ??
                          bundle['title']?.toString() ??
                          "The Glow Essentials";

                      final description = bundle['description']?.toString() ??
                          bundle['summary']?.toString() ??
                          "Our signature 3-step ritual meticulously crafted to deliver radiant, deeply hydrated skin through Alpine botanicals.";

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

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.white,
                                      child: Icon(
                                        Icons.spa_outlined,
                                        color: AppTheme.secondary,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tag.toUpperCase(),
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF7E807C),
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF070F0A),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  color: const Color(0xFF4A554A),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    '\$$price',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF070F0A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$$originalPrice',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: const Color(0xFF9E9E9E),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BundleDetailScreen(bundle: bundle),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFF070F0A),
                                            width: 1.0,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'EXPLORE',
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                              color: const Color(0xFF070F0A),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.arrow_forward,
                                            size: 11,
                                            color: Color(0xFF070F0A),
                                          ),
                                        ],
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
                    childCount: appState.bundles.length,
                  ),
                ),
              ),
            ] else ...[
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No active bundles available.',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF5E5E5B),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(
              child: SizedBox(height: 60),
            ),
          ],
        ),
      ),
    );
  }
}
