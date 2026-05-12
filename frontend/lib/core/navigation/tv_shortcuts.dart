import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvShortcuts extends StatelessWidget {
  const TvShortcuts({
    super.key,
    required this.child,
    this.onBack,
  });

  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
      },
      child: Actions(
        actions: {
          if (onBack != null)
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                onBack?.call();
                return null;
              },
            ),
        },
        child: child,
      ),
    );
  }
}
