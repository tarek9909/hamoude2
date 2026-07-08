import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/app_refresh.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/product_card.dart';

class ShopCatalogScreen extends StatefulWidget {
  /// When non-null, the screen filters to only show products of this brand
  /// and hides category filter chips.
  final String? brandFilter;
  final String? categoryFilter;

  const ShopCatalogScreen({super.key, this.brandFilter, this.categoryFilter});

  @override
  State<ShopCatalogScreen> createState() => _ShopCatalogScreenState();
}

class _ShopCatalogScreenState extends State<ShopCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;
  String? _selectedBrand;
  String _sortBy = 'alpha'; // 'alpha', 'price_asc', 'price_desc'

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _searchController.text = appState.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    if (_searchController.text != appState.searchQuery) {
      _searchController.text = appState.searchQuery;
    }
    final categories = appState.categories;
    final colors = Theme.of(context).colorScheme;
    final isBrandMode =
        widget.brandFilter != null && widget.brandFilter!.isNotEmpty;
    final isCategoryMode =
        widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty;
    final isFilteredMode = isBrandMode || isCategoryMode;

    // Filter products: by brand/category if in filtered mode, otherwise use the existing filters
    final List<Product> products;
    if (isBrandMode) {
      products = appState.products
          .where(
              (p) => p.brand.toLowerCase() == widget.brandFilter!.toLowerCase())
          .toList();
    } else if (isCategoryMode) {
      products = appState.products
          .where((p) =>
              p.category.toLowerCase() == widget.categoryFilter!.toLowerCase())
          .toList();
    } else {
      var list = appState.filteredProducts;
      if (appState.brandsEnabled &&
          _selectedBrand != null &&
          _selectedBrand != 'All') {
        list = list
            .where(
                (p) => p.brand.toLowerCase() == _selectedBrand!.toLowerCase())
            .toList();
      }
      if (_sortBy == 'alpha') {
        list.sort((a, b) => a.name.compareTo(b.name));
      } else if (_sortBy == 'price_asc') {
        list.sort((a, b) => a.price.compareTo(b.price));
      } else if (_sortBy == 'price_desc') {
        list.sort((a, b) => b.price.compareTo(a.price));
      }
      products = list;
    }

    if ((isBrandMode && !appState.brandsEnabled) ||
        (isCategoryMode && !appState.categoriesEnabled)) {
      return _buildUnavailableCollection(
          context, isBrandMode ? 'Brands' : 'Categories');
    }

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
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 8, right: 24, top: 12, bottom: 8),
                    child: Row(
                      children: [
                        // Show back button in filtered mode, otherwise show app name
                        if (isFilteredMode)
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new,
                                color: colors.primary, size: 20),
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Back',
                          )
                        else
                          const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: isFilteredMode
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isFilteredMode) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    appState.appName.toUpperCase(),
                                    style: GoogleFonts.ebGaramond(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4.0,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 8, top: 4),
                                  child: Text(
                                    "SHOP APOTHECARY",
                                    style: GoogleFonts.manrope(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondary,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  (widget.brandFilter ?? widget.categoryFilter)!
                                      .toUpperCase(),
                                  style: GoogleFonts.ebGaramond(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${products.length} ${products.length == 1 ? 'PRODUCT' : 'PRODUCTS'}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.secondary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Divider
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Divider(height: 24, thickness: 0.8),
                        if (isFilteredMode) const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                if (!appState.catalogEnabled)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Card(
                        color: Color(0xFFF2F4F0),
                        elevation: 0,
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(Icons.lock_outline,
                                  size: 32, color: Color(0xFF7E807C)),
                              SizedBox(height: 12),
                              Text(
                                'Catalog is unavailable',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'This store has disabled customer catalog browsing.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  if (!isFilteredMode)
                    SliverToBoxAdapter(
                      child: Builder(builder: (context) {
                        final Set<String> brandNames = appState.products
                            .map((p) => p.brand)
                            .where((b) => b.isNotEmpty)
                            .toSet();
                        final brands = ['All', ...brandNames];
                        final categories = [
                          'All',
                          ...appState.categories.where((c) => c != 'All')
                        ];

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search Input Row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7E2),
                                          width: 1,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.search,
                                              color: colors.primary, size: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchController,
                                              style: GoogleFonts.manrope(
                                                fontSize: 14,
                                                color: const Color(0xFF070F0A),
                                              ),
                                              decoration: InputDecoration(
                                                hintText: appState.brandsEnabled
                                                    ? 'Search products or brands...'
                                                    : 'Search products...',
                                                hintStyle: GoogleFonts.manrope(
                                                  fontSize: 14,
                                                  color:
                                                      const Color(0xFF7E807C),
                                                ),
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                errorBorder: InputBorder.none,
                                                focusedErrorBorder:
                                                    InputBorder.none,
                                                filled: true,
                                                fillColor: Colors.transparent,
                                                contentPadding: EdgeInsets.zero,
                                                isDense: true,
                                              ),
                                              onChanged: (val) {
                                                appState.setSearchQuery(val);
                                              },
                                            ),
                                          ),
                                          if (appState.searchQuery.isNotEmpty)
                                            GestureDetector(
                                              onTap: () {
                                                _searchController.clear();
                                                appState.setSearchQuery('');
                                              },
                                              child: const Icon(Icons.close,
                                                  color: Color(0xFF7E807C),
                                                  size: 18),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Filter Toggle Button
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showFilters = !_showFilters;
                                      });
                                    },
                                    child: Container(
                                      height: 48,
                                      width: 48,
                                      decoration: BoxDecoration(
                                        color: _showFilters
                                            ? colors.primary
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _showFilters
                                              ? colors.primary
                                              : const Color(0xFFE5E7E2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        _showFilters
                                            ? Icons.filter_list_off
                                            : Icons.filter_list,
                                        color: _showFilters
                                            ? Colors.white
                                            : colors.primary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Sliding Filters Drawer
                            AnimatedCrossFade(
                              firstChild: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 0, 24, 16),
                                  color: AppTheme.background,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Divider(
                                          color: Color(0xFFE5E7E2),
                                          thickness: 0.8),
                                      const SizedBox(height: 12),

                                      if (appState.categoriesEnabled) ...[
                                        // Categories Selector
                                        Text(
                                          'CATEGORY',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF7E807C),
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 36,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: categories.length,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            itemBuilder: (context, idx) {
                                              final cat = categories[idx];
                                              final isSelected = (appState
                                                          .selectedCategory ==
                                                      cat) ||
                                                  (appState.selectedCategory ==
                                                          'All' &&
                                                      cat == 'All');
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 8),
                                                child: ChoiceChip(
                                                  label: Text(
                                                    cat.toUpperCase(),
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF070F0A),
                                                    ),
                                                  ),
                                                  selected: isSelected,
                                                  selectedColor: colors.primary,
                                                  backgroundColor: Colors.white,
                                                  side: BorderSide(
                                                    color: isSelected
                                                        ? colors.primary
                                                        : const Color(
                                                            0xFFE5E7E2),
                                                    width: 1,
                                                  ),
                                                  showCheckmark: false,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12),
                                                  onSelected: (selected) {
                                                    appState.setCategory(cat);
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],

                                      if (appState.brandsEnabled) ...[
                                        // Brands Selector
                                        Text(
                                          'BRAND',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF7E807C),
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 36,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: brands.length,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            itemBuilder: (context, idx) {
                                              final brnd = brands[idx];
                                              final isSelected =
                                                  (_selectedBrand == brnd) ||
                                                      (_selectedBrand == null &&
                                                          brnd == 'All');
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 8),
                                                child: ChoiceChip(
                                                  label: Text(
                                                    brnd.toUpperCase(),
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF070F0A),
                                                    ),
                                                  ),
                                                  selected: isSelected,
                                                  selectedColor: colors.primary,
                                                  backgroundColor: Colors.white,
                                                  side: BorderSide(
                                                    color: isSelected
                                                        ? colors.primary
                                                        : const Color(
                                                            0xFFE5E7E2),
                                                    width: 1,
                                                  ),
                                                  showCheckmark: false,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12),
                                                  onSelected: (selected) {
                                                    setState(() {
                                                      _selectedBrand =
                                                          brnd == 'All'
                                                              ? null
                                                              : brnd;
                                                    });
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],

                                      // Sorting Selector
                                      Text(
                                        'SORT BY',
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF7E807C),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildSortButton('Alphabetical',
                                              'alpha', colors.primary),
                                          _buildSortButton('Price: Low to High',
                                              'price_asc', colors.primary),
                                          _buildSortButton('Price: High to Low',
                                              'price_desc', colors.primary),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              secondChild: const SizedBox.shrink(),
                              crossFadeState: _showFilters
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              duration: const Duration(milliseconds: 250),
                            ),

                            // Dynamic Results Count & Reset Row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Showing ${products.length} ${products.length == 1 ? "result" : "results"}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      color: const Color(0xFF7E807C),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (appState.searchQuery.isNotEmpty ||
                                      (appState.categoriesEnabled &&
                                          appState.selectedCategory != 'All') ||
                                      _selectedBrand != null ||
                                      _sortBy != 'alpha')
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedBrand = null;
                                          _sortBy = 'alpha';
                                        });
                                        _searchController.clear();
                                        appState.setSearchQuery('');
                                        appState.setCategory('All');
                                      },
                                      child: Text(
                                        'RESET ALL',
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFBA1A1A),
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  // Only show filter chips when NOT in filtered mode
                  if (!isFilteredMode && appState.categoriesEnabled) ...[
                    // Categories Section Filter
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COLLECTIONS',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 48,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: categories.length,
                                itemBuilder: (context, index) {
                                  final cat = categories[index];
                                  final isSelected =
                                      appState.selectedCategory == cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ChoiceChip(
                                      label: Text(cat),
                                      selected: isSelected,
                                      onSelected: (_) =>
                                          appState.setCategory(cat),
                                      backgroundColor: Colors.transparent,
                                      selectedColor: const Color(0xFFEBECE8),
                                      showCheckmark: false,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      labelPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 2),
                                      padding: const EdgeInsets.all(4),
                                      labelStyle: GoogleFonts.manrope(
                                        color: isSelected
                                            ? const Color(0xFF070F0A)
                                            : const Color(0xFF7E807C),
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isSelected
                                              ? const Color(0xFF070F0A)
                                              : const Color(0xFFD2D7D4),
                                          width: 1.0,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Dynamic Product Grid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: appState.isLoadingConfig &&
                            appState.products.isEmpty
                        ? const SliverToBoxAdapter(
                            child: SizedBox(
                              height: 620,
                              child: ProductGridShimmer(
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          )
                        : products.isEmpty
                            ? SliverToBoxAdapter(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 60),
                                  child: Column(
                                    children: [
                                      Icon(Icons.spa_outlined,
                                          size: 40, color: AppTheme.border),
                                      const SizedBox(height: 12),
                                      Text(
                                        isBrandMode
                                            ? 'No products found for this brand.'
                                            : isCategoryMode
                                                ? 'No products found for this category.'
                                                : 'No matching formulas found.',
                                        style: GoogleFonts.ebGaramond(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isFilteredMode
                                            ? 'Check back soon for new arrivals.'
                                            : 'Try resetting your skin filters.',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: AppTheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.63,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final product = products[index];
                                    final promoInfo = appState
                                        .getPromotionForProduct(product);
                                    return ProductCard(
                                      product: product,
                                      discountedPrice:
                                          promoInfo?['discountedPrice']
                                              as double?,
                                      discountLabel: promoInfo?['discountLabel']
                                          as String?,
                                    );
                                  },
                                  childCount: products.length,
                                ),
                              ),
                  ),
                ],

                // Add bottom spacing to prevent products from being hidden behind the floating bottom bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ),
          )),
    );
  }

  Widget _buildSortButton(String label, String value, Color primaryColor) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFE5E7E2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF070F0A),
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailableCollection(BuildContext context, String label) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 36, color: AppTheme.secondary),
              const SizedBox(height: 16),
              Text(
                '$label unavailable',
                style: GoogleFonts.ebGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This store has disabled this browsing option.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppTheme.secondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
