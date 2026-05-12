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

  static bool isTv(BuildContext context) => formFactor(context) == DeviceFormFactor.tv;

  static double horizontalPadding(BuildContext context) {
    return isTv(context) ? 40 : 16;
  }

  static double posterWidth(BuildContext context) {
    return isTv(context) ? 150 : 124;
  }

  static double posterHeight(BuildContext context) {
    return posterWidth(context) * 1.5;
  }
}
