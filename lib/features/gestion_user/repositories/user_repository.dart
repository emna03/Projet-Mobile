
import '../models/user.dart';
import 'local_database.dart';

class UserRepository {
  final LocalDatabase _localDatabase;

  UserRepository({LocalDatabase? localDatabase})
      : _localDatabase = localDatabase ?? LocalDatabase.instance;

  // CREATE : ajouter un utilisateur
  Future<int> insertUser(AppUser user) async {
    final db = await _localDatabase.database;

    return await db.insert(
      'users',
      user.toMap(),
    );
  }

  // READ : récupérer tous les utilisateurs
  Future<List<AppUser>> getUsers() async {
    final db = await _localDatabase.database;

    final maps = await db.query(
      'users',
      orderBy: 'id DESC',
    );

    return maps.map((map) => AppUser.fromMap(map)).toList();
  }

  // READ : récupérer un utilisateur par son email
  Future<AppUser?> getUserByEmail(String email) async {
    final db = await _localDatabase.database;

    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return AppUser.fromMap(maps.first);
  }

  // UPDATE : modifier un utilisateur
  Future<int> updateUser(AppUser user) async {
    if (user.id == null) {
      throw ArgumentError('L’utilisateur doit posséder un identifiant.');
    }

    final db = await _localDatabase.database;

    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // DELETE : supprimer un utilisateur
  Future<int> deleteUser(int id) async {
    final db = await _localDatabase.database;

    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
