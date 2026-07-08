import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/app_refresh.dart';
import 'bundle_detail_screen.dart';

Color _parseHexColor(String? hexString, Color defaultColor) {
  if (hexString == null || hexString.isEmpty) return defaultColor;
  var hex = hexString.replaceFirst('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  final value = int.tryParse(hex, radix: 16);
  if (value != null) {
    return Color(value);
  }
  return defaultColor;
}

double? _parseAmount(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _formatAmount(double value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
}

class BundlesScreen extends StatelessWidget {
  const BundlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

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
        child: !appState.bundlesEnabled
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Bundles are unavailable for this store.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.secondary,
                      height: 1.5,
                    ),
                  ),
                ),
              )
            : AppRefresh(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  slivers: [
                    if (appState.bundlesEnabled &&
                        appState.bundles.isNotEmpty) ...[
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
                              final imageUrl =
                                  bundle['image_url']?.toString() ??
                                      bundle['media_url']?.toString() ??
                                      "";

                              final tag = bundle['subtitle']?.toString() ??
                                  bundle['tag']?.toString() ??
                                  "";

                              final title = bundle['name']?.toString() ??
                                  bundle['title']?.toString() ??
                                  "Bundle";

                              final description =
                                  bundle['description']?.toString() ??
                                      bundle['summary']?.toString() ??
                                      "";

                              final rawItems = bundle['items'] as List? ?? [];
                              final itemsList = rawItems
                                  .whereType<Map<String, dynamic>>()
                                  .toList();

                              double computedOriginalPrice = 0.0;
                              for (final item in itemsList) {
                                final prodId =
                                    item['product_id']?.toString() ?? '';
                                final qty =
                                    (item['quantity'] as num?)?.toDouble() ??
                                        1.0;
                                Product? p;
                                try {
                                  p = appState.products.firstWhere((entry) =>
                                      Product.compareIds(entry.id, prodId));
                                } catch (_) {}
                                final itemPrice = p?.price ??
                                    (item['unit_price_snapshot'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                computedOriginalPrice += itemPrice * qty;
                              }

                              final explicitBundlePrice =
                                  _parseAmount(bundle['bundle_price']) ??
                                      _parseAmount(bundle['price']);
                              final effectiveBundlePrice =
                                  explicitBundlePrice ??
                                      (computedOriginalPrice > 0
                                          ? computedOriginalPrice
                                          : null);
                              final price = effectiveBundlePrice != null
                                  ? _formatAmount(effectiveBundlePrice)
                                  : null;
                              final originalPrice =
                                  explicitBundlePrice != null &&
                                          computedOriginalPrice >
                                              explicitBundlePrice
                                      ? _formatAmount(computedOriginalPrice)
                                      : null;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _parseHexColor(
                                      bundle['background_color']?.toString(),
                                      const Color(0xFFF2F4F0),
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AspectRatio(
                                          aspectRatio: 1.0,
                                          child: imageUrl.isNotEmpty
                                              ? Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Container(
                                                    color: Colors.white,
                                                    child: Icon(
                                                      Icons.spa_outlined,
                                                      color: AppTheme.secondary,
                                                      size: 48,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.white,
                                                  child: Icon(
                                                    Icons.spa_outlined,
                                                    color: AppTheme.secondary,
                                                    size: 48,
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
                                          if (price != null) ...[
                                            Text(
                                              '\$$price',
                                              style: GoogleFonts.manrope(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF070F0A),
                                              ),
                                            ),
                                            if (originalPrice != null) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                '\$$originalPrice',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 13,
                                                  color:
                                                      const Color(0xFF9E9E9E),
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                            ],
                                          ],
                                          const Spacer(),
                                          InkWell(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      BundleDetailScreen(
                                                          bundle: bundle),
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
                                              padding: const EdgeInsets.only(
                                                  bottom: 2),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'EXPLORE',
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1.5,
                                                      color: const Color(
                                                          0xFF070F0A),
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
      ),
    );
  }
}
