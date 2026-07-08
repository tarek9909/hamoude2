import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'cart_screen.dart';
import 'catalog_screen.dart';
import 'profile_screen.dart';
import 'orders_list_screen.dart';

class SmoothCircularNotchedRectangle extends NotchedShape {
  const SmoothCircularNotchedRectangle();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !host.overlaps(guest)) {
      return Path()..addRect(host);
    }

    final double r = guest.width / 2.0;
    final notchRadius = Radius.circular(r);

    // We increase s1 (horizontal transition length) to 36.0 to give
    // the entry curves a much softer, more rounded and premium look.
    const double s1 = 36.0;
    const double s2 = 12.0;

    final double a = -r - s2;
    final double b = host.top - guest.center.dy;

    final double n2 = math.sqrt(b * b * r * r * (a * a + b * b - r * r));
    final double p2xA = ((a * r * r) - n2) / (a * a + b * b);
    final double p2xB = ((a * r * r) + n2) / (a * a + b * b);
    final double p2yA = math.sqrt(r * r - p2xA * p2xA);
    final double p2yB = math.sqrt(r * r - p2xB * p2xB);

    final p = List<Offset>.filled(6, Offset.zero);

    p[0] = Offset(a - s1, b);
    p[1] = Offset(a, b);
    final cmp = b < 0 ? -1.0 : 1.0;
    p[2] = cmp * p2yA > cmp * p2yB ? Offset(p2xA, p2yA) : Offset(p2xB, p2yB);

    p[3] = Offset(-1.0 * p[2].dx, p[2].dy);
    p[4] = Offset(-1.0 * p[1].dx, p[1].dy);
    p[5] = Offset(-1.0 * p[0].dx, p[0].dy);

    for (var i = 0; i < p.length; i += 1) {
      p[i] += guest.center;
    }

    final path = Path()
      ..moveTo(host.left, host.top)
      ..lineTo(p[0].dx, p[0].dy)
      ..quadraticBezierTo(p[1].dx, p[1].dy, p[2].dx, p[2].dy)
      ..arcToPoint(p[3], radius: notchRadius, clockwise: false)
      ..quadraticBezierTo(p[4].dx, p[4].dy, p[5].dx, p[5].dy)
      ..lineTo(host.right, host.top)
      ..lineTo(host.right, host.bottom)
      ..lineTo(host.left, host.bottom)
      ..close();

    return path;
  }
}

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const ShopCatalogScreen(),
    const CartScreen(),
    const TrackOrdersListScreen(),
    const ProfileScreen(),
  ];

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required AppState appState,
  }) {
    final isSelected = appState.currentTabIndex == index;
    // Gold active color matching mockup exactly, muted translucent white for inactive
    final color = isSelected
        ? const Color(0xFFECC152)
        : Colors.white.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => appState.setTabIndex(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 54,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFFECC152),
                  shape: BoxShape.circle,
                ),
              ),
            ] else ...[
              const SizedBox(
                  height: 9), // Stable height placeholder to avoid jitter
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final cartCount = appState.cart.fold(0, (sum, item) => sum + item.quantity);
    final currentIndex = appState.isTabEnabled(appState.currentTabIndex)
        ? appState.currentTabIndex
        : appState.firstEnabledTabIndex;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      floatingActionButton: appState.checkoutEnabled
          ? Container(
              margin: const EdgeInsets.only(
                  top:
                      12), // Nestles the FAB beautifully deep inside the notch matching the picture exactly
              child: SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: FloatingActionButton(
                        onPressed: () =>
                            appState.setTabIndex(2), // CartScreen is index 2
                        backgroundColor: const Color(
                            0xFF818E82), // Soft sage grey/green matching mockup exactly
                        shape: const CircleBorder(),
                        elevation:
                            0, // Matte, clean look with zero harsh shadows matching the picture exactly
                        child: const Icon(Icons.shopping_cart_outlined,
                            color: Colors.white,
                            size: 28), // Sleek larger icon matching larger FAB
                      ),
                    ),
                    if (cartCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(
                                  0xFFBA1A1A), // Brand-standard error red badge
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Center(
                              child: Text(
                                cartCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.primaryContainer, // Dark forest green Color(0xFF1B261D)
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: appState.checkoutEnabled
            ? const SmoothCircularNotchedRectangle()
            : null,
        notchMargin:
            12.0, // Make the edges around the middle button more rounded and spacious
        padding: EdgeInsets.zero,
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Group: Home & Search
              Row(
                children: [
                  _buildTabItem(
                      index: 0,
                      icon: Icons.home,
                      activeIcon: Icons.home,
                      appState: appState),
                  if (appState.productsEnabled) ...[
                    const SizedBox(width: 12),
                    _buildTabItem(
                        index: 1,
                        icon: Icons.search,
                        activeIcon: Icons.search,
                        appState: appState),
                  ],
                  const SizedBox(width: 20),
                ],
              ),
              // Right Group: Bag/Browse & Profile
              Row(
                children: [
                  const SizedBox(width: 20),
                  if (appState.ordersEnabled)
                    _buildTabItem(
                        index: 3,
                        icon: Icons.shopping_bag_outlined,
                        activeIcon: Icons.shopping_bag,
                        appState: appState),
                  if (appState.ordersEnabled && appState.profileEnabled)
                    const SizedBox(width: 12),
                  if (appState.profileEnabled)
                    _buildTabItem(
                        index: 4,
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        appState: appState),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
