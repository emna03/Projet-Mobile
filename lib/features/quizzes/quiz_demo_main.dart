import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'data/memory_quiz_attempt_repository.dart';
import 'data/quiz_attempt_repository.dart';
import 'data/quiz_repository.dart';
import 'services/quiz_user_context.dart';
import 'theme/quiz_theme.dart';
import 'viewmodels/quiz_viewmodel.dart';
import 'views/quiz_list_page.dart';
import 'widgets/quiz_edge_to_edge.dart';

/// Point d'entrée de démonstration du module Quiz.
/// Ne remplace pas `lib/main.dart` (AuthGate StudyMate reste sur main/user).
///
/// Lancement :
/// `flutter run -t lib/features/quizzes/quiz_demo_main.dart -d <device>`
///
/// Gemini :
/// `--dart-define=GEMINI_PROXY_URL=...` ou démo `--dart-define=GEMINI_API_KEY=...`
///
/// OpenRouter :
/// `--dart-define=OPENROUTER_PROXY_URL=...` ou démo `--dart-define=OPENROUTER_API_KEY=...`
///
/// Mémoire pure (tests widget sans SQLite) :
/// `--dart-define=QUIZ_USE_MEMORY=true`
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuizDemoApp());
}

const bool _kUseMemory =
    bool.fromEnvironment('QUIZ_USE_MEMORY', defaultValue: false);

bool get _preferMemoryStore {
  if (_kUseMemory) return true;
  // Les tests widget Flutter définissent FLUTTER_TEST=true.
  return Platform.environment['FLUTTER_TEST'] == 'true';
}

class QuizDemoApp extends StatefulWidget {
  const QuizDemoApp({super.key});

  @override
  State<QuizDemoApp> createState() => _QuizDemoAppState();
}

class _QuizDemoAppState extends State<QuizDemoApp> {
  late final QuizViewModel viewModel = QuizViewModel(
    repository:
        _preferMemoryStore ? QuizRepository.seeded() : QuizRepository.sqlite(),
    attemptRepository: _preferMemoryStore
        ? MemoryQuizAttemptRepository()
        : QuizAttemptRepository(),
  );

  @override
  void initState() {
    super.initState();
    viewModel.bootstrap();
  }

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
        builder: (context, child) =>
            QuizEdgeToEdge(child: child ?? const SizedBox.shrink()),
        home: const QuizListPage(),
      ),
    );
  }
}

/// Widget réutilisable pour brancher le module dans l'app commune.
class QuizModuleEntry extends StatelessWidget {
  const QuizModuleEntry({super.key});

  @override
  Widget build(BuildContext context) => const QuizModuleShell();
}

/// Shell autonome avec ViewModel — à utiliser depuis Home après merge Firebase.
///
/// Important : un [Navigator] **imbriqué** sous [QuizScope] garantit que les
/// pages poussées (Détail, Play, IA, etc.) restent dans le scope. Sans cela,
/// `Navigator.of(context).push` utilise le Navigator racine StudyMate situé
/// **au-dessus** de QuizScope → assertion « QuizScope introuvable ».
class QuizModuleShell extends StatefulWidget {
  const QuizModuleShell({super.key, this.userIdProvider});

  final QuizUserIdProvider? userIdProvider;

  @override
  State<QuizModuleShell> createState() => _QuizModuleShellState();
}

class _QuizModuleShellState extends State<QuizModuleShell> {
  final GlobalKey<NavigatorState> _quizNavKey = GlobalKey<NavigatorState>();

  late final QuizViewModel _vm = QuizViewModel(
    userContext: QuizUserContext(provider: widget.userIdProvider),
    repository:
        _preferMemoryStore ? QuizRepository.seeded() : QuizRepository.sqlite(),
    attemptRepository: _preferMemoryStore
        ? MemoryQuizAttemptRepository()
        : QuizAttemptRepository(),
  );

  @override
  void initState() {
    super.initState();
    _vm.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return QuizScope(
      notifier: _vm,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final nav = _quizNavKey.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop(result);
            return;
          }
          // Sortie du module → Navigator StudyMate (Home). Sécurisé si racine.
          if (!context.mounted) return;
          final outer = Navigator.maybeOf(context);
          if (outer != null && outer.canPop()) {
            outer.pop(result);
          }
        },
        child: Navigator(
          key: _quizNavKey,
          onGenerateInitialRoutes: (navigator, initialRoute) {
            return [
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/quiz'),
                builder: (_) => const QuizListPage(),
              ),
            ];
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }
}
