import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileSelectionPage extends StatelessWidget {
  const ProfileSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Who is watching?', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            FilledButton(
              autofocus: true,
              onPressed: () => context.go('/home'),
              child: const Text('Living Room'),
            ),
          ],
        ),
      ),
    );
  }
}
