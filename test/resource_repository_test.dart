import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/resources/models/resource.dart';
import 'package:studymate/features/resources/repositories/resource_repository.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('studymate_test');
    await databaseFactoryFfi.setDatabasesPath(dir.path);
  });

  test('CRUD ressources + flashcards via sqflite', () async {
    final repo = ResourceRepository();

    final seeded = await repo.getAll();
    expect(seeded.length, 5);

    final id = await repo.create(Resource(
      title: 'Cours Flutter',
      subject: 'Flutter',
      author: 'Moi',
      ownerName: 'Moi',
      content: 'Flutter construit des interfaces multiplateformes. Les widgets composent l’UI. Le hot reload accélère le développement.',
      visibility: ResourceVisibility.private,
      isFree: true,
      pages: 12,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    expect(await repo.getById(id), isNotNull);

    final created = (await repo.getById(id))!;
    expect(created.visibility, ResourceVisibility.private);
    expect(created.pricing, ResourcePricing.free);

    await repo.update(created.copyWith(title: 'Cours Flutter avancé', isFree: false, price: 15));
    final updated = await repo.getById(id);
    expect(updated?.title, 'Cours Flutter avancé');
    expect(updated?.pricing, ResourcePricing.paid);
    expect(updated?.price, 15);

    await repo.update(updated!.copyWith(isFavorite: true));
    expect((await repo.getById(id))?.isFavorite, isTrue);

    await repo.delete(id);
    expect(await repo.getById(id), isNull);
    expect(await repo.getFlashcards(id), isEmpty);
  });
}
