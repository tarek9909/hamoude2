import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class AppRefresh extends StatelessWidget {
  final Widget child;

  const AppRefresh({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: () =>
          Provider.of<AppState>(context, listen: false).refreshAllData(),
      notificationPredicate: (notification) => notification.depth == 0,
      child: child,
    );
  }
}
