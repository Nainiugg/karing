import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  static const String assetPath = 'assets/background/app_background.jpg';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ExcludeSemantics(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: const Alignment(0.42, 0),
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
                  return const ColoredBox(color: Color(0xFFE8F3EE));
                },
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xB8FFFFFF),
                Color(0x9EF2F8F4),
                Color(0x88E4F2EB),
              ],
              stops: <double>[0, 0.52, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
