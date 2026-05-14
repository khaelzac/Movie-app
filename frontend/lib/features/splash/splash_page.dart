import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/navigation/app_routes.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _beamProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.52, curve: Curves.easeOutCubic),
    );
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.28, end: 0.95)
            .chain(CurveTween(curve: Curves.easeOutExpo)),
        weight: 62,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 38,
      ),
    ]).animate(_controller);
    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 32),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0.2), weight: 68),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _beamProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
    );

    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) context.go(AppRoutes.home);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _IntroBeamPainter(
                  progress: _beamProgress.value,
                  opacity: _glowOpacity.value,
                ),
              ),
              Center(
                child: Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.netflixRed
                                .withValues(alpha: 0.45 * _glowOpacity.value),
                            blurRadius: 42,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: AppColors.netflixRed,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IntroBeamPainter extends CustomPainter {
  const _IntroBeamPainter({
    required this.progress,
    required this.opacity,
  });

  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || opacity <= 0) return;

    final center = size.center(Offset.zero);
    final maxRadius = size.longestSide * 0.72 * progress;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = RadialGradient(
        colors: [
          AppColors.netflixRed.withValues(alpha: 0),
          AppColors.netflixRed.withValues(alpha: 0.36 * opacity),
          AppColors.netflixRed.withValues(alpha: 0),
        ],
        stops: const [0.45, 0.52, 0.72],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: maxRadius.clamp(1, size.longestSide).toDouble(),
        ),
      );

    canvas.drawCircle(center, maxRadius, ringPaint);

    final beamWidth = size.width * 0.08;
    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.netflixRed.withValues(alpha: 0),
          AppColors.netflixRed.withValues(alpha: 0.2 * opacity),
          AppColors.netflixRed.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, beamWidth, size.height));

    for (final offset in const [-0.18, 0.0, 0.18]) {
      final x = size.width * (0.5 + offset * progress) - beamWidth / 2;
      canvas.drawRect(Rect.fromLTWH(x, 0, beamWidth, size.height), beamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntroBeamPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
