import 'package:flutter/material.dart';

/// Compact branded filter trigger; the selection sheet owns the options.
class TicketFilterChip extends StatelessWidget {
  const TicketFilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF243C91);
    return Material(
      color: active ? blue : const Color(0xFFF1F5FC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: active ? blue : const Color(0xFFDFE6F3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: active ? Colors.white : blue),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : blue,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: active ? Colors.white70 : blue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
