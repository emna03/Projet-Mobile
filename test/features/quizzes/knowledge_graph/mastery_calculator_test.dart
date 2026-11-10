import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/mastery_level.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/mastery_calculator.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';

void main() {
  const calc = MasteryCalculator();

  test('sans preuve → non évalué', () {
    final m = calc.compute(userId: 'u', conceptId: 'c', evidence: const []);
    expect(m.level, MasteryLevel.unevalue);
  });

  test('une seule bonne réponse ne donne pas excellente', () {
    final m = calc.compute(
      userId: 'u',
      conceptId: 'c',
      evidence: [
        ConceptEvidence(
          questionId: 'q1',
          correct: true,
          difficulty: QuizDifficulty.difficile,
          completedAt: DateTime.now(),
        ),
      ],
    );
    expect(m.level, isNot(MasteryLevel.excellente));
    expect(m.level, isNot(MasteryLevel.bonne));
  });

  test('plusieurs questions réussies → bonne ou excellente', () {
    final now = DateTime.now();
    final m = calc.compute(
      userId: 'u',
      conceptId: 'c',
      evidence: [
        for (var i = 0; i < 3; i++)
          ConceptEvidence(
            questionId: 'q$i',
            correct: true,
            difficulty: QuizDifficulty.moyen,
            completedAt: now,
          ),
      ],
    );
    expect(
      m.level == MasteryLevel.bonne || m.level == MasteryLevel.excellente,
      isTrue,
    );
  });

  test('échecs majoritaires → faible', () {
    final now = DateTime.now();
    final m = calc.compute(
      userId: 'u',
      conceptId: 'c',
      evidence: [
        for (var i = 0; i < 4; i++)
          ConceptEvidence(
            questionId: 'q$i',
            correct: i == 0,
            difficulty: QuizDifficulty.moyen,
            completedAt: now,
          ),
      ],
    );
    expect(m.level, MasteryLevel.faible);
  });
}
