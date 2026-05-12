import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import 'movie_card.dart';

class FocusableMediaCard extends StatefulWidget {
  const FocusableMediaCard({
    super.key,
    required this.item,
    required this.onPressed,
    this.focusNode,
  });

  final MediaItem item;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  State<FocusableMediaCard> createState() => _FocusableMediaCardState();
}

class _FocusableMediaCardState extends State<FocusableMediaCard> {
  @override
  Widget build(BuildContext context) {
    return MovieCard(
      item: widget.item,
      onPressed: widget.onPressed,
      focusNode: widget.focusNode,
    );
  }
}
