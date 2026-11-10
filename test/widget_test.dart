import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/core/constants/session_user.dart';

void main() {
  tearDown(() => SessionUser.role = '');

  test('unresolved role is not teacher', () {
    SessionUser.role = '';
    expect(SessionUser.isTeacher, isFalse);
  });

  test('student role cannot manage resources', () {
    SessionUser.role = 'student';
    expect(SessionUser.isTeacher, isFalse);
  });

  test('teacher role can manage resources', () {
    SessionUser.role = 'teacher';
    expect(SessionUser.isTeacher, isTrue);
  });
}