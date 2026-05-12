import 'package:flutter/material.dart';

class FocusScroll {
  const FocusScroll._();

  static void keepVisible(
    BuildContext context, {
    Duration duration = const Duration(milliseconds: 180),
  }) {
    Scrollable.ensureVisible(
      context,
      duration: duration,
      curve: Curves.easeOut,
      alignment: 0.12,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }
}
