import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedLogoLoader extends StatefulWidget {
  const AnimatedLogoLoader({
    super.key,
    this.size = 120,
    this.label,
    this.compact = false,
  });

  final double size;
  final String? label;
  final bool compact;

  @override
  State<AnimatedLogoLoader> createState() => _AnimatedLogoLoaderState();
}

class _AnimatedLogoLoaderState extends State<AnimatedLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value * math.pi * 2;
        final scale = 0.96 + math.sin(phase) * 0.04;
        final lift = math.sin(phase) * (widget.compact ? 1.5 : 5);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, lift),
              child: Transform.scale(
                scale: scale,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: phase,
                        child: Container(
                          width: widget.size * 0.82,
                          height: widget.size * 0.82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.18),
                              width: widget.compact ? 1.5 : 3,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.engineering_outlined,
                        size: widget.size * 0.48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.label != null) ...[
              SizedBox(height: widget.compact ? 3 : 12),
              Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
