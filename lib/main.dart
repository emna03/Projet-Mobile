import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'theme/app_theme.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/resources.dart';
import 'screens/groups.dart';
import 'screens/sessions.dart';
import 'screens/profile.dart';

void main() => runApp(const StudyMateApp());

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'StudyMate',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Sur desktop/web : contenu centré à 390 px.
        builder: (context, child) => ColoredBox(
          color: const Color(0xFFE4E1F7),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 390), child: child)),
        ),
        home: const LoginScreen(),
      );
}

class Shell extends StatefulWidget {
  final int initial;
  const Shell({super.key, this.initial = 0});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int index = widget.initial;
  final pages = const [HomeScreen(), ResourcesScreen(), GroupsScreen(), SessionsScreen(), ProfileScreen()];
  final tabs = const [
    (LucideIcons.home, 'Accueil'),
    (LucideIcons.bookOpen, 'Ressources'),
    (LucideIcons.users, 'Groupes'),
    (LucideIcons.calendar, 'Séances'),
    (LucideIcons.user, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: SafeArea(bottom: false, child: pages[index]),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: SM.shadow),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final active = i == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => index = i),
                    child: AnimatedContainer(
                      duration: SM.anim,
                      height: 56,
                      decoration: BoxDecoration(
                        color: active ? SM.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(tabs[i].$1, size: 20, color: active ? Colors.white : SM.muted),
                        const SizedBox(height: 2),
                        Text(tabs[i].$2,
                            style: SM.b(10, color: active ? Colors.white : SM.muted, w: FontWeight.w600)),
                      ]),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
}
