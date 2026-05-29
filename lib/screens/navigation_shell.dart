import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'catalog_screen.dart';
import 'orders_list_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  List<_NavDestination> _getDestinations(AppState appState) {
    return [
      const _NavDestination(
        screen: HomeScreen(),
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'HOME',
      ),
      const _NavDestination(
        screen: ShopCatalogScreen(),
        icon: Icons.search,
        activeIcon: Icons.search,
        label: 'SEARCH',
      ),
      const _NavDestination(
        screen: CartScreen(),
        icon: Icons.add,
        activeIcon: Icons.add,
        label: 'CART',
      ),
      const _NavDestination(
        screen: TrackOrdersListScreen(),
        icon: Icons.shopping_bag_outlined,
        activeIcon: Icons.shopping_bag,
        label: 'SHOP',
      ),
      const _NavDestination(
        screen: ProfileScreen(),
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'ME',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final destinations = _getDestinations(appState);

    // Safeguard index selection
    final currentIndex = appState.currentTabIndex >= destinations.length
        ? 0 // Default to Home if index overflows
        : appState.currentTabIndex;

    return Scaffold(
      body: Stack(
        children: [
          // Active Page Screen
          Positioned.fill(
            child: IndexedStack(
              index: currentIndex,
              children: destinations.map((dest) => dest.screen).toList(),
            ),
          ),

          // Custom Sticky Notch Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFloatingBottomBar(context, appState, currentIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomBar(
      BuildContext context, AppState appState, int currentIndex) {
    final destinations = _getDestinations(appState);
    const double baseBarHeight = 72.0;
    final double safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final double totalBarHeight = baseBarHeight + safeAreaBottom;

    // Hydrate backend primary and secondary colors dynamically
    final colors = Theme.of(context).colorScheme;
    final primaryColor = colors.primary;
    final secondaryColor = colors.secondary;

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Beautiful Custom Notched Background Bar taking the full screen width and extending to bottom
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, totalBarHeight),
            painter: CustomNotchedPainter(color: primaryColor),
          ),

          // 2. Row of Navigation Icons (aligned precisely above the safe area)
          Positioned(
            bottom: safeAreaBottom,
            left: 0,
            right: 0,
            height: baseBarHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, destinations[0], currentIndex, appState),
                _buildNavItem(1, destinations[1], currentIndex, appState),
                const SizedBox(width: 76), // Spacer for central plus notch
                _buildNavItem(3, destinations[3], currentIndex, appState),
                _buildNavItem(4, destinations[4], currentIndex, appState),
              ],
            ),
          ),

          // 3. Central Vibrant Circular Plus Action Floating Button
          Positioned(
            bottom: totalBarHeight - 48, // Floating slightly above the notch cutout
            child: GestureDetector(
              onTap: () {
                appState.setTabIndex(2); // Set active tab index to 2 (Cart screen)
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentIndex == 2
                      ? secondaryColor // Backend secondary color for active Plus button
                      : secondaryColor.withValues(alpha: 0.75), // Soft secondary color inactive
                  boxShadow: [
                    BoxShadow(
                      color: secondaryColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: _buildFabIcon(appState, currentIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabIcon(AppState appState, int currentIndex) {
    final cartCount = appState.cart.fold(0, (sum, item) => sum + item.quantity);
    Widget plusIcon = const Icon(
      Icons.add,
      color: Colors.white,
      size: 32,
    );

    if (cartCount > 0) {
      return Badge(
        label: Text(
          cartCount.toString(),
          style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFBA1A1A),
        child: plusIcon,
      );
    }
    return plusIcon;
  }

  Widget _buildNavItem(
      int index, _NavDestination dest, int currentIndex, AppState appState) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? AppTheme.accent // Gold/coral accent highlight matching premium theme tokens from backend
        : Colors.white.withValues(alpha: 0.55); // Soft white for inactive tabs

    return GestureDetector(
      onTap: () {
        appState.setTabIndex(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? dest.activeIcon : dest.icon,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 5),
            // Sleek highlight dot under active icon instead of textual labels
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter to draw a flat sticky bottom bar with a deep, smooth notch cutout in the center
class CustomNotchedPainter extends CustomPainter {
  final Color color;
  CustomNotchedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const double notchWidth = 84.0;
    const double notchDepth = 52.0;
    const double cpX = 56.0;
    final double middle = size.width / 2;

    // Start at top-left corner (0, 0) - completely flat, NO left radius
    path.moveTo(0, 0);

    // Top edge to start of notch curve
    path.lineTo(middle - notchWidth, 0);

    // Left half of the notch: smooth cubic bezier to the bottom middle
    path.cubicTo(
      middle - notchWidth + cpX,
      0,
      middle - cpX,
      notchDepth,
      middle,
      notchDepth,
    );

    // Right half of the notch: smooth cubic bezier rising out of the notch
    path.cubicTo(
      middle + cpX,
      notchDepth,
      middle + notchWidth - cpX,
      0,
      middle + notchWidth,
      0,
    );

    // Top edge to top-right corner - flat, NO right radius
    path.lineTo(size.width, 0);

    // Right edge straight down to bottom-right corner
    path.lineTo(size.width, size.height);

    // Bottom edge flat left to bottom-left corner
    path.lineTo(0, size.height);

    // Left edge straight up to top-left corner
    path.lineTo(0, 0);

    path.close();

    // Fill the path cleanly with no simulated top border shadow
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomNotchedPainter oldDelegate) => false;
}

class _NavDestination {
  final Widget screen;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavDestination({
    required this.screen,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
