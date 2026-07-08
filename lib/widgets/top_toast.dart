import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

void showTopToast(BuildContext context, String message,
    {String? actionLabel, VoidCallback? onActionPressed}) {
  final overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;
  var isRemoved = false;

  void removeToast() {
    if (isRemoved) return;
    isRemoved = true;
    overlayEntry.remove();
  }

  overlayEntry = OverlayEntry(
    builder: (context) {
      return _TopToastWidget(
        message: message,
        actionLabel: actionLabel,
        onActionPressed: () {
          if (onActionPressed != null) {
            onActionPressed();
          }
          removeToast();
        },
        onDismiss: removeToast,
      );
    },
  );

  overlayState.insert(overlayEntry);
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback onActionPressed;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.message,
    this.actionLabel,
    required this.onActionPressed,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _timer;
  double _dragOffset = 0;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _yAnimation = Tween<double>(begin: -80.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _timer = Timer(const Duration(seconds: 2), _dismiss);
  }

  void _dismiss() {
    if (!mounted || _isDismissing) return;
    _isDismissing = true;
    _timer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isDismissing) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(-96.0, 0.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset < -36 || velocity < -250) {
      _dismiss();
      return;
    }

    setState(() {
      _dragOffset = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final primaryColor = AppTheme.primary;
    final accentColor = AppTheme.accent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: safeAreaTop + 16 + _yAnimation.value + _dragOffset,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: (_opacityAnimation.value * (1 - (_dragOffset.abs() / 120)))
                .clamp(0.0, 1.0),
            child: GestureDetector(
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.message,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.actionLabel != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: widget.onActionPressed,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            widget.actionLabel!.toUpperCase(),
                            style: GoogleFonts.manrope(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
