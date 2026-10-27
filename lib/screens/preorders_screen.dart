import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';

class PreordersScreen extends StatelessWidget {
  const PreordersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final products = appState.products
        .where((product) => product.isPreorder)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'PREORDERS',
          style: GoogleFonts.ebGaramond(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: appState.refreshAllData,
        child: products.isEmpty && appState.isCatalogLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                children: [
                  const SizedBox(height: 160),
                  Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              )
            : products.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.inventory_2_outlined,
                      size: 52, color: AppTheme.secondary),
                  const SizedBox(height: 16),
                  Text(
                    'No preorder items are available right now.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(color: AppTheme.secondary),
                  ),
                ],
              )
            : GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.63,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) =>
                    ProductCard(product: products[index]),
              ),
      ),
    );
  }
}
