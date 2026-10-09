import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate/features/seances/seances_page.dart';
import 'package:studymate/features/seances/seances_store.dart';
import 'package:studymate/features/seances/widgets/study_bottom_nav.dart';
import 'package:studymate/features/seances/widgets/study_header.dart';
import 'package:studymate/theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const StudyMateApp());
}

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.backgroundTop,
        splashFactory: InkRipple.splashFactory,
      ),
      home: const StudyShell(),
    );
  }
}

/// Temporary shell so the séances screen matches the mock.
/// Accueil, Resources, Groupes and Profil stay empty for the other members.
class StudyShell extends StatefulWidget {
  const StudyShell({super.key});

  @override
  State<StudyShell> createState() => _StudyShellState();
}

class _StudyShellState extends State<StudyShell> {
  final _store = SeancesStore();
  int _index = 3;

  static const _placeholders = <int, String>{
    0: 'Accueil',
    1: 'Resources',
    2: 'Groupes',
    4: 'Profil',
  };

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = _placeholders[_index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.backgroundTop,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: placeholder == null
                      ? SeancesPage(store: _store)
                      : _ComingSoon(title: placeholder),
                ),
                StudyBottomNav(
                  currentIndex: _index,
                  onSelected: (index) => setState(() => _index = index),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        const StudyHeader(),
        const SizedBox(height: 80),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cette partie sera ajoutée par un autre membre.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
