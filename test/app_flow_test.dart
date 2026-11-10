import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/core/config/gemini_config.dart';
import 'package:studymate/core/constants/session_user.dart';
import 'package:studymate/core/routes/app_routes.dart';
import 'package:studymate/core/widgets/resource_scope.dart';
import 'package:studymate/core/widgets/sm_widgets.dart';
import 'package:studymate/features/resources/models/resource.dart';
import 'package:studymate/features/resources/repositories/resource_repository.dart';
import 'package:studymate/features/resources/views/resource_detail_page.dart';
import 'package:studymate/features/resources/views/resource_form_page.dart';
import 'package:studymate/features/resources/views/resources_page.dart';
import 'package:studymate/features/resources/viewmodels/resource_viewmodel.dart';

class FakeRepository extends ResourceRepository {
  final List<Resource> _rows = [
    Resource(
      id: 1,
      title: 'Cours Java',
      subject: 'Java',
      author: 'Nacef Jouini',
      ownerName: 'Nacef Jouini',
      content: 'Java est un langage orienté objet. Une classe décrit un type.',
      visibility: ResourceVisibility.public,
      isFree: true,
      pages: 28,
      createdAt: 3,
    ),
    Resource(
      id: 2,
      title: 'Cours Spring Boot',
      subject: 'Spring Boot',
      author: 'Sarah Ben Ali',
      ownerName: 'Sarah Ben Ali',
      content: 'Spring Boot accélère la création d’API REST.',
      visibility: ResourceVisibility.public,
      isFree: false,
      price: 12,
      pages: 24,
      createdAt: 2,
    ),
    Resource(
      id: 3,
      title: 'Notes personnelles',
      subject: 'Révision',
      author: 'Nacef Jouini',
      ownerName: 'Nacef Jouini',
      content: 'Mes notes : revoir les annotations Spring.',
      visibility: ResourceVisibility.private,
      isFree: true,
      pages: 6,
      createdAt: 1,
    ),
  ];
  final Map<int, List<Flashcard>> _cards = {};
  int _nextId = 4;

  @override
  Future<List<Resource>> getAll() async => List.of(_rows.reversed);

  @override
  Future<Resource?> getById(int id) async {
    for (final r in _rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<int> create(Resource resource) async {
    _rows.add(Resource(
      id: _nextId,
      title: resource.title,
      subject: resource.subject,
      author: resource.author,
      ownerName: resource.ownerName,
      content: resource.content,
      visibility: resource.visibility,
      groupId: resource.groupId,
      groupName: resource.groupName,
      isFree: resource.isFree,
      price: resource.price,
      pages: resource.pages,
      summary: resource.summary,
      createdAt: resource.createdAt,
      isFavorite: resource.isFavorite,
    ));
    return _nextId++;
  }

  @override
  Future<int> update(Resource resource) async {
    final i = _rows.indexWhere((r) => r.id == resource.id);
    if (i >= 0) _rows[i] = resource;
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    _rows.removeWhere((r) => r.id == id);
    _cards.remove(id);
    return 1;
  }

  @override
  Future<String> generateSummary(Resource resource) async {
    await update(resource.copyWith(summary: 'Résumé auto de ${resource.title}.'));
    return 'Résumé auto de ${resource.title}.';
  }

  @override
  Future<List<Flashcard>> getFlashcards(int resourceId) async => _cards[resourceId] ?? const [];

  @override
  Future<List<Flashcard>> generateFlashcards(Resource resource) async {
    final id = resource.id!;
    _cards[id] = [
      Flashcard(resourceId: id, question: 'Q1', answer: 'R1'),
      Flashcard(resourceId: id, question: 'Q2', answer: 'R2'),
    ];
    return _cards[id]!;
  }
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
}

Future<void> boot(WidgetTester tester, String role) async {
  SessionUser.role = role;
  GeminiConfig.sessionApiKey = 'cle-de-test';
  final viewModel = ResourceViewModel(FakeRepository());
  await viewModel.load();
  await tester.pumpWidget(MaterialApp(
    routes: {
      AppRoutes.resourceDetail: (context) => ResourceDetailPage(
            id: ModalRoute.of(context)!.settings.arguments! as int,
          ),
      AppRoutes.resourceForm: (context) => ResourceFormPage(
            existing: ModalRoute.of(context)!.settings.arguments as Resource?,
          ),
    },
    builder: (context, child) => ResourceScope(
      notifier: viewModel,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const ResourcesPage(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Parcours CRUD complet des ressources (enseignant)', (tester) async {
    await boot(tester, 'teacher');

    expect(find.text('Ressources'), findsOneWidget);
    await scrollTo(tester, find.text('Cours Java'));
    expect(find.text('Cours Java'), findsOneWidget);
    expect(find.text('Cours Spring Boot'), findsOneWidget);

    await tester.tap(find.byTooltip('Ajouter aux favoris').first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsWidgets);

    await tester.tap(find.widgetWithText(SMChip, 'Payant'));
    await tester.pumpAndSettle();
    expect(find.text('Cours Java'), findsNothing);
    expect(find.text('Cours Spring Boot'), findsOneWidget);

    await tester.tap(find.widgetWithText(SMChip, 'Tout'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter une ressource'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle ressource'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Titre'), 'Cours Flutter');
    await tester.enterText(find.widgetWithText(TextField, 'Matière'), 'Flutter');
    await tester.tap(find.widgetWithText(SMChip, 'Privée'));
    await tester.tap(find.widgetWithText(SMChip, 'Payant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Prix (DT)'), '20');
    await scrollTo(tester, find.widgetWithText(TextField, 'Contenu du document'));
    await tester.enterText(find.widgetWithText(TextField, 'Contenu du document'),
        'Flutter construit des interfaces multiplateformes. Les widgets composent l’UI. Le hot reload accélère le développement.');
    await scrollTo(tester, find.text('Créer'));
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(find.text('Cours Flutter'), findsOneWidget);
    expect(find.widgetWithText(SMBadge, 'Payant'), findsWidgets);
    expect(find.widgetWithText(SMBadge, 'Privé'), findsWidgets);

    await tester.tap(find.text('Cours Flutter'));
    await tester.pumpAndSettle();
    expect(find.textContaining(' · 10 pages'), findsOneWidget);
    expect(find.text('Payant · 20 DT'), findsOneWidget);

    await scrollTo(tester, find.text('Résumé'));
    await tester.tap(find.text('Résumé'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.textContaining('Résumé auto de Cours Flutter'));
    expect(find.textContaining('Résumé auto de Cours Flutter'), findsOneWidget);

    await scrollTo(tester, find.text('Flashcards'));
    await tester.tap(find.text('Flashcards'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.textContaining('Flashcard 1/'));
    expect(find.textContaining('Flashcard 1/'), findsOneWidget);
    await scrollTo(tester, find.text('Réponse'));
    await tester.tap(find.text('Réponse'));
    await tester.pumpAndSettle();
    expect(find.text('R1'), findsOneWidget);
    await scrollTo(tester, find.byIcon(Icons.chevron_right));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.textContaining('Flashcard 2/'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Modifier la ressource'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Titre'), 'Cours Flutter 2');
    await scrollTo(tester, find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Cours Flutter 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Cours Flutter 2'), findsOneWidget);

    await tester.tap(find.text('Cours Flutter 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Cours Flutter 2'), findsNothing);
  });

  testWidgets('Un étudiant consulte, favori et génère mais ne gère pas', (tester) async {
    await boot(tester, 'student');

    expect(find.text('Ajouter une ressource'), findsNothing);

    await scrollTo(tester, find.text('Cours Java'));
    await tester.tap(find.text('Cours Java'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await scrollTo(tester, find.text('Résumé'));
    await tester.tap(find.text('Résumé'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Résumé auto de Cours Java'), findsOneWidget);
  });
}
