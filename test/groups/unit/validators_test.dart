import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/core/utils/validators.dart';

void main() {
  group('FormValidators Unit Tests', () {
    test('validateGroupName checks', () {
      expect(FormValidators.validateGroupName(null), isNotNull);
      expect(FormValidators.validateGroupName(''), isNotNull);
      expect(FormValidators.validateGroupName('   '), isNotNull);
      expect(FormValidators.validateGroupName('ab'), contains('au moins 3'));
      expect(FormValidators.validateGroupName('   ab   '), contains('au moins 3'));
      expect(FormValidators.validateGroupName('---?!'), contains('lettres ou des chiffres'));
      expect(FormValidators.validateGroupName('a' * 51), contains('50 caractères'));

      // Valid names
      expect(FormValidators.validateGroupName('Algo & Structures'), isNull);
      expect(FormValidators.validateGroupName('Spring Boot 3'), isNull);
      expect(FormValidators.validateGroupName('Développement Mobile'), isNull);
    });

    test('validateGroupDescription checks', () {
      expect(FormValidators.validateGroupDescription(null), isNotNull);
      expect(FormValidators.validateGroupDescription(''), isNotNull);
      expect(FormValidators.validateGroupDescription('   '), isNotNull);
      expect(FormValidators.validateGroupDescription('Court'), contains('au moins 10'));
      expect(FormValidators.validateGroupDescription('a' * 301), contains('300 caractères'));

      // Valid description
      expect(
        FormValidators.validateGroupDescription('Groupe d\'entraide pour les TP et projets.'),
        isNull,
      );
    });

    test('validateLevel checks', () {
      const allowed = ['Licence 2', 'Licence 3', 'Master 1'];
      expect(FormValidators.validateLevel(null, allowed), isNotNull);
      expect(FormValidators.validateLevel('', allowed), isNotNull);
      expect(FormValidators.validateLevel('Doctorat', allowed), isNotNull);
      expect(FormValidators.validateLevel('Licence 3', allowed), isNull);
    });

    test('validateCapacity checks', () {
      expect(FormValidators.validateCapacity(maxMembers: 1, selectedCount: 1), contains('minimale est de 2'));
      expect(FormValidators.validateCapacity(maxMembers: 51, selectedCount: 1), contains('ne peut pas dépasser 50'));
      expect(FormValidators.validateCapacity(maxMembers: 4, selectedCount: 5), contains('ne peut pas être inférieure'));
      expect(FormValidators.validateCapacity(maxMembers: 10, selectedCount: 3), isNull);
      expect(FormValidators.validateCapacity(maxMembers: 5, selectedCount: 5), isNull);
    });
  });
}
