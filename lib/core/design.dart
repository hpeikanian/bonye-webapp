import 'package:flutter/material.dart';
import 'language.dart';
import 'widgets.dart';

const cream = Color(0xFFF5F0E7);
const sage = Color(0xFFE4EBDF);
const peach = Color(0xFFFAE8D3);
const sky = Color(0xFFE3EAF0);
const rose = Color(0xFFF7E4DF);

class SoftIcon extends StatelessWidget {
  const SoftIcon(this.icon, {super.key, this.color = sage, this.size = 48});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(size * .32)),
        child: Icon(icon, size: size * .46, color: brand),
      );
}

class CareHero extends StatelessWidget {
  const CareHero(
      {super.key, required this.title, required this.subtitle, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 235,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/images/care-hero.png',
                fit: BoxFit.cover, excludeFromSemantics: true),
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x662B4935)]))),
            if (action != null)
              PositionedDirectional(
                  start: 28,
                  end: 28,
                  bottom: 14,
                  child: Center(child: action!)),
          ]),
        ),
      );
}

class QuickAction extends StatelessWidget {
  const QuickAction(
      {super.key,
      required this.title,
      required this.icon,
      required this.onTap,
      this.color = sage});
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
            child: Column(children: [
              SoftIcon(icon, color: color),
              const SizedBox(height: 8),
              AppText(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))
            ])),
      );
}

class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = MediaQuery.textScalerOf(context).scale(12) > 16 ||
                constraints.maxWidth < 300
            ? 2
            : 4;
        return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children
                .map((child) => SizedBox(
                    width: (constraints.maxWidth - 8 * (columns - 1)) / columns,
                    child: child))
                .toList());
      });
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader(
      {super.key,
      required this.name,
      required this.subtitle,
      this.icon = Icons.person_outline});
  final String name, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          SoftIcon(icon, size: 64),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                AppText(name,
                    translate: false,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                AppText(subtitle,
                    translate: false,
                    style: const TextStyle(color: Color(0xFF627365))),
              ])),
        ]),
      ));
}
