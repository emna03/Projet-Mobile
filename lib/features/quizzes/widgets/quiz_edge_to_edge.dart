import 'package:flutter/material.dart';

/// Sur Android 15+, `MediaQuery.padding` peut rester à 0 (edge-to-edge)
/// alors que les insets sont dans `viewPadding`. Sans cette copie,
/// SafeArea et ListView ignorent les barres système : le contenu
/// passe trop haut et le défilement ne s'active pas.
class QuizEdgeToEdge extends StatelessWidget {
  const QuizEdgeToEdge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final padding = EdgeInsets.only(
      left: media.padding.left > 0 ? media.padding.left : media.viewPadding.left,
      top: media.padding.top > 0 ? media.padding.top : media.viewPadding.top,
      right: media.padding.right > 0 ? media.padding.right : media.viewPadding.right,
      bottom: media.padding.bottom > 0 ? media.padding.bottom : media.viewPadding.bottom,
    );
    return MediaQuery(
      data: media.copyWith(padding: padding),
      child: child,
    );
  }
}
