import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/core/theme/app_theme.dart';
import 'package:studymate/features/groups/viewmodels/group_viewmodel.dart';
import 'package:studymate/features/groups/views/create_group_page.dart';
import '../mocks/fake_group_repository.dart';

void main() {
  testWidgets('CreateGroupPage does NOT submit when title and description are empty',
      (WidgetTester tester) async {
    final fakeRepo = FakeGroupRepository();
    final viewModel = GroupViewModel(repository: fakeRepo);
    await viewModel.loadData();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CreateGroupPage(viewModel: viewModel),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial group count in repo
    final initialCount = (await fakeRepo.getGroups()).length;

    // Scroll down the SingleChildScrollView to reveal the submit button
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();

    final submitButton = find.text('Créer le groupe');
    expect(submitButton, findsOneWidget);

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Check that error messages are shown (both on TextFormField and in SnackBar)
    expect(find.text('Veuillez saisir le nom du groupe.'), findsAtLeastNWidgets(1));

    // Verify NO group was created!
    final afterCount = (await fakeRepo.getGroups()).length;
    expect(afterCount, equals(initialCount));
  });
}
