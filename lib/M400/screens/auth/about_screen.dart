import 'package:flutter/material.dart';
import '../../widgets/auth_ui.dart';
import 'login_screen.dart';

/// Public welcome page. Account access remains in the existing login flow.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void login() => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));

    return Scaffold(
      backgroundColor: M400AuthColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF17366C)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: _PageWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.explore_rounded,
                            color: Color(0xFF93C5FD),
                            size: 30,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'MyFind',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: login,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              side: const BorderSide(color: Color(0xFF526A8F)),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Log in'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 42),
                      const _Eyebrow('WELCOME TO MYFIND', light: true),
                      const SizedBox(height: 16),
                      const Text(
                        'Your next chapter\nin Malaysia.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Make room for the experience. Keep your stay in view, '
                        'and stay connected to the community around you.',
                        style: TextStyle(
                          color: Color(0xFFCBDCF2),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _LoginButton(onPressed: login, light: true),
                      const SizedBox(height: 30),
                      const _MalaysiaScene(),
                    ],
                  ),
                ),
              ),
            ),
            _PageWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const _Eyebrow('HERE FOR YOUR EVERYDAY'),
                  const SizedBox(height: 12),
                  const Text(
                    'Less wondering.\nMore living.',
                    style: TextStyle(
                      color: M400AuthColors.heading,
                      fontSize: 29,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Whether Malaysia is your next destination or the place '
                    'you call home, find what matters to you in MyFind.',
                    style: TextStyle(
                      color: M400AuthColors.body,
                      fontSize: 15,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _BenefitCard(
                    icon: Icons.luggage_outlined,
                    label: 'VISITING MALAYSIA',
                    title: 'Enjoy the journey.\nKnow where you stand.',
                    description:
                        'Keep your visa information and important stay '
                        'dates together, with a clearer view of what comes next.',
                    benefits: [
                      'Check your application progress',
                      'Keep track of your stay',
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _BenefitCard(
                    icon: Icons.diversity_1_outlined,
                    label: 'CALLING MALAYSIA HOME',
                    title: 'Your community.\nYour voice.',
                    description:
                        'Make a concern heard. Share the details that '
                        'matter and follow your report without losing the thread.',
                    benefits: [
                      'Submit a community concern',
                      'Follow your report updates',
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FA),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Eyebrow('WHY MYFIND'),
                        SizedBox(height: 12),
                        Text(
                          'A little more clarity.\nA stronger connection.',
                          style: TextStyle(
                            color: M400AuthColors.heading,
                            fontSize: 23,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'We believe feeling informed is part of feeling at '
                          'home. MyFind brings stay information and community '
                          'reporting into one place, so your next step is easier '
                          'to find.',
                          style: TextStyle(
                            color: M400AuthColors.body,
                            fontSize: 15,
                            height: 1.65,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Your MyFind starts here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: M400AuthColors.heading,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Log in to continue, or register from the login screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: M400AuthColors.body, height: 1.6),
                  ),
                  const SizedBox(height: 22),
                  _LoginButton(onPressed: login),
                  const SizedBox(height: 30),
                  const Divider(color: M400AuthColors.border),
                  const SizedBox(height: 16),
                  const Text(
                    'MyFind · A place to feel connected.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: M400AuthColors.body,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'MyFind is not an official immigration service.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: M400AuthColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.light = false});

  final String text;
  final bool light;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: light ? const Color(0xFF93C5FD) : M400AuthColors.primary,
      fontSize: 11,
      height: 1.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
    ),
  );
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onPressed, this.light = false});

  final VoidCallback onPressed;
  final bool light;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: light ? Colors.white : M400AuthColors.primary,
      foregroundColor: light ? M400AuthColors.heading : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Log in to MyFind',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: 12),
        Icon(Icons.arrow_forward_rounded, size: 20),
      ],
    ),
  );
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.label,
    required this.title,
    required this.description,
    required this.benefits,
  });

  final IconData icon;
  final String label;
  final String title;
  final String description;
  final List<String> benefits;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: M400AuthColors.border),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: M400AuthColors.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: M400AuthColors.primary, size: 27),
        ),
        const SizedBox(height: 20),
        _Eyebrow(label),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: M400AuthColors.heading,
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          description,
          style: const TextStyle(
            color: M400AuthColors.body,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
        for (final benefit in benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: M400AuthColors.primary,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    benefit,
                    style: const TextStyle(
                      color: M400AuthColors.heading,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _MalaysiaScene extends StatelessWidget {
  const _MalaysiaScene();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: Container(
      color: const Color(0xFF244F83),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(
            child: SizedBox(
              height: 155,
              child: CustomPaint(painter: _SkylinePainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFFBFDBFE),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A place to explore.\nA community to belong to.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Decorative, code-native skyline; no network images are needed at startup.
class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final width = size.width;
    canvas.drawCircle(
      Offset(width * 0.77, 44),
      25,
      paint..color = const Color(0xFFBFD9EC),
    );
    final hills = Path()
      ..moveTo(0, 113)
      ..quadraticBezierTo(width * 0.18, 42, width * 0.48, 111)
      ..quadraticBezierTo(width * 0.75, 50, width, 89)
      ..lineTo(width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hills, paint..color = const Color(0xFF376695));
    paint.color = const Color(0xFF163C66);
    for (final building in [
      (0.07, 30.0, 90.0),
      (0.17, 22.0, 103.0),
      (0.58, 23.0, 87.0),
      (0.69, 26.0, 104.0),
      (0.84, 32.0, 94.0),
    ]) {
      canvas.drawRect(
        Rect.fromLTWH(width * building.$1, building.$3, building.$2, 65),
        paint,
      );
    }
    // Paired stepped towers and a skybridge recall Kuala Lumpur's skyline.
    paint.color = const Color(0xFF95B7D6);
    for (final x in [width * 0.34, width * 0.46]) {
      canvas.drawRect(Rect.fromLTWH(x, 63, 18, 88), paint);
      canvas.drawRect(Rect.fromLTWH(x + 3, 51, 12, 12), paint);
      canvas.drawRect(Rect.fromLTWH(x + 6, 41, 6, 10), paint);
      canvas.drawLine(
        Offset(x + 9, 26),
        Offset(x + 9, 41),
        paint..strokeWidth = 2,
      );
      for (var y = 70.0; y < 151; y += 9) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 18, y),
          Paint()
            ..color = const Color(0xFF4B7198)
            ..strokeWidth = 2,
        );
      }
    }
    canvas.drawRect(
      Rect.fromLTRB(width * 0.34 + 18, 96, width * 0.46, 101),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 146, width, 9),
      paint..color = const Color(0xFF244F83),
    );
  }

  @override
  bool shouldRepaint(_SkylinePainter oldDelegate) => false;
}
