import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppShimmer extends StatefulWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width == 0 ? 1.0 : bounds.width;
            final shimmerPosition = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.border.withValues(alpha: 0.35),
                AppTheme.background,
                AppTheme.border.withValues(alpha: 0.35),
              ],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(shimmerPosition * width),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double offset;

  const _SlidingGradientTransform(this.offset);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(offset, 0, 0);
  }
}

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE9ECE6),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class ShimmerImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const ShimmerImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? const _ImageFallback();
    }

    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return ShimmerBox(
          width: width,
          height: height,
          borderRadius: BorderRadius.zero,
        );
      },
      errorBuilder: (_, __, ___) => errorWidget ?? const _ImageFallback(),
    );
  }
}

class ProductGridShimmer extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const ProductGridShimmer({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 120),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.63,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        return const Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ShimmerBox(borderRadius: BorderRadius.zero),
            ),
            SizedBox(height: 10),
            ShimmerBox(width: 110, height: 14),
            SizedBox(height: 8),
            ShimmerBox(width: 80, height: 12),
            SizedBox(height: 8),
            ShimmerBox(width: 48, height: 12),
          ],
        );
      },
    );
  }
}

class AppLoadingScaffold extends StatelessWidget {
  const AppLoadingScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              ShimmerBox(width: 150, height: 22),
              SizedBox(height: 28),
              ShimmerBox(
                  height: 180,
                  borderRadius: BorderRadius.all(Radius.circular(16))),
              SizedBox(height: 24),
              ShimmerBox(width: 180, height: 20),
              SizedBox(height: 16),
              Expanded(child: ProductGridShimmer(padding: EdgeInsets.zero)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.spa_outlined,
        size: 32,
        color: Color(0xFF7E807C),
      ),
    );
  }
}
