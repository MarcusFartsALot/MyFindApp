import 'package:flutter/material.dart';

/// Keeps two panels readable on narrow screens and at larger text sizes.
class AdaptivePair extends StatelessWidget {
  final Widget first, second;
  const AdaptivePair({super.key, required this.first, required this.second});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final stack =
          size.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      return stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 12), second],
            )
          : Row(
              children: [
                Expanded(child: first),
                const SizedBox(width: 12),
                Expanded(child: second),
              ],
            );
    },
  );
}
