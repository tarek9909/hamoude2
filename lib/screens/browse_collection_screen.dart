import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_refresh.dart';
import '../widgets/app_shimmer.dart';
import 'catalog_screen.dart';

/// Enum to distinguish between browsing brands or categories.
enum BrowseMode { brands, categories }

/// A premium full-page screen that dynamically displays either all brands
/// or all categories in a beautiful grid layout. Tapping an item filters
/// the catalog and navigates back to the Shop tab.
class BrowseCollectionScreen extends StatelessWidget {
  final BrowseMode mode;

  const BrowseCollectionScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    final isBrands = mode == BrowseMode.brands;
    final isEnabled =
        isBrands ? appState.brandsEnabled : appState.categoriesEnabled;
    final title = isBrands ? 'Shop by Brand' : 'Shop by Category';
    final subtitle = isBrands
        ? 'Explore our curated selection of premium botanical brands.'
        : 'Browse collections tailored to your skincare ritual.';

    // Build display items from AppState data
    final List<Map<String, String>> items = isBrands
        ? appState.brands.map((b) {
            final rawImageUrl = b['logo_url']?.toString() ??
                b['image_url']?.toString() ??
                b['image']?.toString() ??
                '';
            return {
              'id': b['id']?.toString() ?? '',
              'name': b['name']?.toString() ?? 'Brand',
              'image': appState.api.resolveMediaUrl(rawImageUrl),
            };
          }).toList()
        : appState.categoryRecords.map((category) {
            final rawImageUrl = category['image_url']?.toString() ??
                category['image']?.toString() ??
                '';
            return {
              'id': category['id']?.toString() ?? '',
              'name': category['name']?.toString() ?? '',
              'image': appState.api.resolveMediaUrl(rawImageUrl),
            };
          }).where((category) {
            return (category['name'] ?? '').isNotEmpty;
          }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: AppRefresh(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Premium Header with Back Button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 8, right: 24, top: 12, bottom: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new,
                            color: colors.primary, size: 20),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Back',
                      ),
                      const Spacer(),
                      Text(
                        appState.appName.toUpperCase(),
                        style: GoogleFonts.ebGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.0,
                          color: colors.primary,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(
                          width: 48), // Balance the back button width
                    ],
                  ),
                ),
              ),

              // Title and Subtitle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 24, right: 24, top: 20, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.ebGaramond(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF070F0A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          color: const Color(0xFF5E5E5B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(thickness: 0.6, height: 24),
                    ],
                  ),
                ),
              ),

              // Item Count Badge
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${items.length} ${isBrands ? 'BRANDS' : 'CATEGORIES'}',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              if (!isEnabled)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 80, horizontal: 32),
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 48, color: AppTheme.border),
                        const SizedBox(height: 16),
                        Text(
                          '${isBrands ? 'Brands' : 'Categories'} unavailable',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ebGaramond(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This browsing option is disabled for this store.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
              // Empty State
              if (items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 80),
                    child: Column(
                      children: [
                        Icon(
                          isBrands
                              ? Icons.business_outlined
                              : Icons.category_outlined,
                          size: 48,
                          color: AppTheme.border,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isBrands
                              ? 'No brands available yet.'
                              : 'No categories available yet.',
                          style: GoogleFonts.ebGaramond(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Check back soon for updates.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Dynamic Grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isBrands ? 3 : 2,
                      childAspectRatio: isBrands ? 0.78 : 0.72,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 18,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        return _CollectionItemCard(
                          name: item['name'] ?? '',
                          imageUrl: item['image'] ?? '',
                          isBrand: isBrands,
                          onTap: () {
                            final itemName = item['name'] ?? '';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShopCatalogScreen(
                                  brandFilter: isBrands ? itemName : null,
                                  categoryFilter: isBrands ? null : itemName,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),

              // Bottom safe spacing for floating nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A premium card widget for displaying a single brand or category item.
class _CollectionItemCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final bool isBrand;
  final VoidCallback onTap;

  const _CollectionItemCard({
    required this.name,
    required this.imageUrl,
    required this.isBrand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment:
            isBrand ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // Image Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEBECE8),
                borderRadius: BorderRadius.circular(isBrand ? 18 : 14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isBrand ? 18 : 14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ShimmerImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: Container(
                        color: const Color(0xFFEBECE8),
                        child: Icon(
                          isBrand ? Icons.business : Icons.spa_outlined,
                          color: const Color(0xFF7E807C),
                          size: 36,
                        ),
                      ),
                    ),
                    // Subtle bottom gradient for category text readability
                    if (!isBrand)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    // Category name overlaid on image bottom
                    if (!isBrand)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ebGaramond(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    // Subtle hover/pressed overlay
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onTap,
                          borderRadius:
                              BorderRadius.circular(isBrand ? 18 : 14),
                          splashColor: colors.primary.withValues(alpha: 0.08),
                          highlightColor:
                              colors.primary.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Brand label below the image
          if (isBrand) ...[
            const SizedBox(height: 10),
            Text(
              name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF070F0A),
                letterSpacing: 1.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
