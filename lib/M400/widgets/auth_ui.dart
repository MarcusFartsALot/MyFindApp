import 'package:flutter/material.dart';

/// Shared presentation for the M400 authentication flow.
///
/// These values mirror the Tourist module's navy, slate, and white card
/// language without importing or modifying the teammate-owned module.
abstract final class M400AuthColors {
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const primary = Color(0xFF1E3A8A);
  static const primarySoft = Color(0xFFEFF6FF);
  static const heading = Color(0xFF0F172A);
  static const body = Color(0xFF475569);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFF0FDF4);
  static const error = Color(0xFFDC2626);
}

class M400AuthPage extends StatelessWidget {
  const M400AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.showBackButton = false,
    this.onBack,
    this.maxWidth = 520,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: M400AuthColors.background,
      appBar: showBackButton
          ? AppBar(
              leading: onBack == null
                  ? null
                  : IconButton(
                      tooltip: 'Back to home',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: onBack,
                    ),
              backgroundColor: M400AuthColors.surface,
              elevation: 1,
              scrolledUnderElevation: 1,
              iconTheme: const IconThemeData(color: M400AuthColors.heading),
              title: const Text(
                'MyFind',
                style: TextStyle(
                  color: M400AuthColors.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, showBackButton ? 28 : 48, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthHeader(icon: icon, title: title, subtitle: subtitle),
                  const SizedBox(height: 28),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: M400AuthColors.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x241E3A8A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: M400AuthColors.heading,
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: M400AuthColors.muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class M400AuthCard extends StatelessWidget {
  const M400AuthCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: M400AuthColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: M400AuthColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class M400SectionTitle extends StatelessWidget {
  const M400SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: M400AuthColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: M400AuthColors.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: M400AuthColors.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: M400AuthColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

InputDecoration m400InputDecoration({
  required String label,
  String? hint,
  String? helper,
  IconData? prefixIcon,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: M400AuthColors.border),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, color: M400AuthColors.muted, size: 21),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: M400AuthColors.background,
    labelStyle: const TextStyle(color: M400AuthColors.muted),
    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: M400AuthColors.primary, width: 1.5),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: M400AuthColors.error),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: M400AuthColors.error, width: 1.5),
    ),
  );
}

class M400PrimaryButton extends StatelessWidget {
  const M400PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: M400AuthColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: M400AuthColors.primary.withValues(
            alpha: 0.55,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19),
                    const SizedBox(width: 9),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
