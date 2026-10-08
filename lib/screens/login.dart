import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _enter(BuildContext c) =>
      Navigator.of(c).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            Container(
              height: 280,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: SM.primary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Stack(children: [
                Positioned(top: -40, right: -30, child: _circle(160)),
                Positioned(bottom: 20, left: -40, child: _circle(120)),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const Icon(LucideIcons.graduationCap, color: SM.primary, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text('StudyMate', style: SM.h(28).copyWith(color: Colors.white)),
                    Text('Révise mieux, ensemble.', style: SM.b(15, color: Colors.white70)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Connexion', style: SM.h(22)),
                const SizedBox(height: 16),
                const TextField(decoration: InputDecoration(hintText: 'Email', prefixIcon: Icon(LucideIcons.mail))),
                const SizedBox(height: 12),
                const TextField(
                    obscureText: true,
                    decoration: InputDecoration(hintText: 'Mot de passe', prefixIcon: Icon(LucideIcons.lock))),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => _enter(context), child: const Text('Se connecter')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _enter(context), icon: const Icon(Icons.web, size: 18), label: const Text('Google'))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _enter(context), icon: const Icon(LucideIcons.scanFace, size: 18), label: const Text('Face ID'))),
                ]),
                const SizedBox(height: 16),
                TextButton(onPressed: () {}, child: Text('Créer un compte', style: SM.b(15, color: SM.primary, w: FontWeight.w600))),
              ]),
            ),
          ]),
        ),
      );

  Widget _circle(double s) => Container(
      width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)));
}
