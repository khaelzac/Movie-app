import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/focus_scroll.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../models/media_item.dart';

class MovieCard extends StatefulWidget {
  const MovieCard({
    super.key,
    required this.item,
    required this.onPressed,
    this.onFocused,
    this.focusNode,
  });

  final MediaItem item;
  final VoidCallback onPressed;
  final VoidCallback? onFocused;
  final FocusNode? focusNode;

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  Widget build(BuildContext context) {
    final width = ResponsiveLayout.posterWidth(context);
    final height = ResponsiveLayout.posterHeight(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * pixelRatio).round().clamp(180, 420).toInt();
    final cacheHeight = (height * pixelRatio).round().clamp(270, 640).toInt();
    final imageUrl = widget.item.posterUrl.isNotEmpty ? widget.item.posterUrl : widget.item.backdropUrl;

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height + 26,
        child: Align(
          alignment: Alignment.topCenter,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
            },
            child: Actions(
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    widget.onPressed();
                    return null;
                  },
                ),
              },
              child: FocusableActionDetector(
                focusNode: widget.focusNode,
                mouseCursor: SystemMouseCursors.click,
                onShowFocusHighlight: (value) => setState(() => _focused = value),
                onShowHoverHighlight: (value) => setState(() => _hovered = value),
                onFocusChange: (focused) {
                  if (!focused) return;
                  widget.onFocused?.call();
                  FocusScroll.keepVisible(context);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onPressed,
                  child: AnimatedScale(
                    scale: _active ? 1.08 : 1,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      width: width,
                      height: height,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _active ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: _active
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: AppColors.netflixRed.withValues(alpha: 0.55),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageUrl.isEmpty)
                            const ColoredBox(color: AppColors.skeletonBase)
                          else
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 120),
                              memCacheWidth: cacheWidth,
                              memCacheHeight: cacheHeight,
                              maxWidthDiskCache: 420,
                              maxHeightDiskCache: 640,
                              placeholder: (_, __) => const ColoredBox(color: AppColors.skeletonBase),
                              errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.skeletonBase),
                            ),
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: _active ? 1 : 0,
                              duration: const Duration(milliseconds: 120),
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Color(0xDD000000)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 10,
                            child: AnimatedOpacity(
                              opacity: _active ? 1 : 0,
                              duration: const Duration(milliseconds: 120),
                              child: Text(
                                widget.item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      shadows: const [Shadow(blurRadius: 8)],
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
