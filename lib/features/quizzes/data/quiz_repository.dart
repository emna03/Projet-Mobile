import '../models/quiz.dart';
import '../models/quiz_result.dart';
import 'quiz_mock_data.dart';

/// CRUD in-memory du module Quiz (Feature-First).
/// Les données sont initialisées avec les quiz de démonstration.
class QuizRepository {
  QuizRepository({
    List<Quiz>? quizzes,
    List<QuizResult>? history,
  })  : _quizzes = List<Quiz>.from(quizzes ?? mockQuizzes),
        _history = List<QuizResult>.from(history ?? mockHistory);

  factory QuizRepository.seeded() => QuizRepository();

  final List<Quiz> _quizzes;
  final List<QuizResult> _history;
  int _nextId = 1;

  List<Quiz> getAll() => List.unmodifiable(_quizzes);

  Quiz? getById(String id) {
    for (final quiz in _quizzes) {
      if (quiz.id == id) return quiz;
    }
    return null;
  }

  List<QuizResult> getHistory() => List.unmodifiable(_history);

  List<String> get subjects {
    final values = {for (final quiz in _quizzes) quiz.subject};
    return ['Toutes', ...values];
  }

  Quiz create(Quiz quiz) {
    final created = quiz.id.isEmpty ? quiz.copyWith(id: _newId()) : quiz;
    if (getById(created.id) != null) {
      final withId = created.copyWith(id: _newId());
      _quizzes.insert(0, withId);
      return withId;
    }
    _quizzes.insert(0, created);
    return created;
  }

  Quiz update(Quiz quiz) {
    final index = _quizzes.indexWhere((item) => item.id == quiz.id);
    if (index < 0) {
      throw StateError('Quiz introuvable : ${quiz.id}');
    }
    _quizzes[index] = quiz;
    return quiz;
  }

  bool delete(String id) {
    final removed = _quizzes.where((quiz) => quiz.id == id).isNotEmpty;
    _quizzes.removeWhere((quiz) => quiz.id == id);
    _history.removeWhere((result) => result.quizId == id);
    return removed;
  }

  void addResult(QuizResult result) {
    _history.insert(0, result);
  }

  String _newId() {
    final id = 'quiz-user-$_nextId-${DateTime.now().millisecondsSinceEpoch}';
    _nextId++;
    return id;
  }
}
