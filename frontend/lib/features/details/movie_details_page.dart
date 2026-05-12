import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/catalog_providers.dart';
import '../../shared/widgets/media/details_page_content.dart';

class MovieDetailsPage extends ConsumerWidget {
  const MovieDetailsPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numericId = int.tryParse(id);
    if (numericId == null) {
      return const Scaffold(body: DetailsErrorView(message: 'Invalid movie ID.'));
    }

    final details = ref.watch(movieDetailsProvider(numericId));

    return Scaffold(
      body: details.when(
        data: (details) => DetailsPageContent(details: details),
        error: (error, _) => DetailsErrorView(message: error.toString()),
        loading: () => const DetailsLoadingView(),
      ),
    );
  }
}
