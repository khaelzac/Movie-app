import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  PaintingBinding.instance.imageCache
    ..maximumSize = 120
    ..maximumSizeBytes = 80 << 20;

  runApp(const ProviderScope(child: OcampoFlixApp()));
}
