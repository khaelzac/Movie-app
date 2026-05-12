import 'package:flutter/material.dart';

import '../models/media_item.dart';
import 'movie_rail.dart';
import 'skeleton_rail.dart';

class ContentRail extends StatefulWidget {
  const ContentRail({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final AsyncSnapshot<List<MediaItem>> items;

  @override
  State<ContentRail> createState() => _ContentRailState();
}

class _ContentRailState extends State<ContentRail> {
  @override
  Widget build(BuildContext context) {
    if (widget.items.connectionState == ConnectionState.waiting) {
      return SkeletonRail(title: widget.title);
    }

    final items = widget.items.data ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return MovieRail(title: widget.title, items: items);
  }
}
