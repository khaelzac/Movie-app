import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../shared/widgets/media/focusable_media_card.dart';

class FocusableMovieCard extends StatelessWidget {
  const FocusableMovieCard({
    super.key,
    required this.item,
    required this.onPressed,
    this.focusNode,
  });

  final MediaItem item;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FocusableMediaCard(
      item: item,
      onPressed: onPressed,
      focusNode: focusNode,
    );
  }
}
