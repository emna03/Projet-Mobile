import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/services/quiz_user_context.dart';

void main() {
  test('transmet l’UID fourni (simulation Firebase)', () async {
    final context = QuizUserContext(
      provider: () async => 'firebase-uid-integration',
    );
    expect(await context.currentUserId(), 'firebase-uid-integration');
  });

  test('fallback local-demo si UID absent', () async {
    final context = QuizUserContext(provider: () async => null);
    expect(await context.currentUserId(), QuizUserContext.localDemoUserId);
  });
}
