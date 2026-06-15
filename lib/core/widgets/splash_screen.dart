import 'package:flutter/material.dart';

import 'animated_logo_loader.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: AnimatedLogoLoader(label: 'Preparing your workspace...'),
      ),
    );
  }
}
