import 'package:flutter/material.dart';

import 'theme/quiz_theme.dart';
import 'viewmodels/quiz_viewmodel.dart';
import 'views/quiz_list_page.dart';
import 'widgets/quiz_edge_to_edge.dart';

/// Point d'entrée de démonstration du module Quiz.
/// Ne remplace pas `lib/main.dart`.
///
/// Lancement :
/// `flutter run -t lib/features/quizzes/quiz_demo_main.dart -d emulator-5554`
void main() {
  runApp(const QuizDemoApp());
}

class QuizDemoApp extends StatefulWidget {
  const QuizDemoApp({super.key});

  @override
  State<QuizDemoApp> createState() => _QuizDemoAppState();
}

class _QuizDemoAppState extends State<QuizDemoApp> {
  late final QuizViewModel viewModel = QuizViewModel();

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuizScope(
      notifier: viewModel,
      child: MaterialApp(
        title: 'StudyMate Quiz',
        debugShowCheckedModeBanner: false,
        theme: buildQuizTheme(),
        builder: (context, child) => QuizEdgeToEdge(child: child ?? const SizedBox.shrink()),
        home: const QuizListPage(),
      ),
    );
  }
}

/// Widget réutilisable pour brancher plus tard le module dans l'app commune.
class QuizModuleEntry extends StatelessWidget {
  const QuizModuleEntry({super.key});

  @override
  Widget build(BuildContext context) => const QuizListPage();
}
