import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import 'movie_rail.dart';

class MediaRail extends StatefulWidget {
  const MediaRail({
    super.key,
    required this.title,
    required this.items,
    this.isLoading = false,
  });

  final String title;
  final List<MediaItem> items;
  final bool isLoading;

  @override
  State<MediaRail> createState() => _MediaRailState();
}

class _MediaRailState extends State<MediaRail> {
  @override
  Widget build(BuildContext context) {
    return MovieRail(
      title: widget.title,
      items: widget.items,
      isLoading: widget.isLoading,
    );
  }
}
