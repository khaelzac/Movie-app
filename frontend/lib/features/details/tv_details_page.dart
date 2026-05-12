import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/catalog_providers.dart';
import '../../shared/widgets/media/details_page_content.dart';

class TvDetailsPage extends ConsumerWidget {
  const TvDetailsPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numericId = int.tryParse(id);
    if (numericId == null) {
      return const Scaffold(body: DetailsErrorView(message: 'Invalid TV show ID.'));
    }

    final details = ref.watch(tvDetailsProvider(numericId));

    return Scaffold(
      body: details.when(
        data: (details) => DetailsPageContent(details: details),
        error: (error, _) => DetailsErrorView(message: error.toString()),
        loading: () => const DetailsLoadingView(),
      ),
    );
  }
}
