import 'package:flutter/widgets.dart';

enum DeviceFormFactor { phone, tablet, tv }

class ResponsiveLayout {
  const ResponsiveLayout._();

  static DeviceFormFactor formFactor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortestSide = size.shortestSide;
    final isLandscape = size.width > size.height;

    if (isLandscape && size.width >= 960) return DeviceFormFactor.tv;
    if (shortestSide >= 600) return DeviceFormFactor.tablet;
    return DeviceFormFactor.phone;
  }

  static bool isTv(BuildContext context) =>
      formFactor(context) == DeviceFormFactor.tv;

  static double horizontalPadding(BuildContext context) {
    return isTv(context) ? 40 : 16;
  }

  static double homeHeroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final factor = isTv(context) ? 0.72 : 0.64;
    final minHeight = isTv(context) ? 520.0 : 420.0;
    final maxHeight = isTv(context) ? 760.0 : 560.0;
    return (size.height * factor).clamp(minHeight, maxHeight).toDouble();
  }

  static double detailsHeroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final factor = isTv(context) ? 0.78 : 0.72;
    final minHeight = isTv(context) ? 560.0 : 500.0;
    final maxHeight = isTv(context) ? 820.0 : 680.0;
    return (size.height * factor).clamp(minHeight, maxHeight).toDouble();
  }

  static double posterWidth(BuildContext context) {
    return isTv(context) ? 150 : 124;
  }

  static double posterHeight(BuildContext context) {
    return posterWidth(context) * 1.5;
  }
}
