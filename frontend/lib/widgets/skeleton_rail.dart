import 'package:flutter/material.dart';

import '../core/responsive/responsive_layout.dart';
import '../shared/widgets/loading/shimmer_box.dart';

class SkeletonRail extends StatelessWidget {
  const SkeletonRail({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ResponsiveLayout.horizontalPadding(context)),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: ResponsiveLayout.posterHeight(context) + 20,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: ResponsiveLayout.horizontalPadding(context)),
              scrollDirection: Axis.horizontal,
              itemCount: 8,
              itemBuilder: (_, __) => ShimmerBox(
                width: ResponsiveLayout.posterWidth(context),
                height: ResponsiveLayout.posterHeight(context),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 14),
            ),
          ),
        ],
      ),
    );
  }
}
