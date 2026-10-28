import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_migrations.dart';
import '../../users/models/user.dart';
import '../models/group.dart';
import '../models/join_request.dart';

/// Repository for all group-related data access.
///
/// Every public method is `async` and operates on the SQLite database via
/// [AppDatabase].  No business logic lives here – only data mapping and
/// persistence.
class GroupRepository {
  GroupRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<Database> get _conn => _db.database;

  static const _tg = DatabaseMigrations.tGroups;
  static const _tu = DatabaseMigrations.tUsers;
  static const _tm = DatabaseMigrations.tGroupMembers;
  static const _tr = DatabaseMigrations.tGroupJoinRequests;

  // ── User mapping ────────────────────────────────────────────────────────────

  User _mapUser(Map<String, dynamic> row) {
    return User(
      id: row['id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      role: row['role'] as String? ?? 'Étudiant',
      avatarColorIndex: row['avatar_color'] as int? ?? 0,
    );
  }

  // ── Group mapping ────────────────────────────────────────────────────────────

  /// Builds a [Group] from a raw row + eagerly-loaded members list.
  Group _mapGroup(Map<String, dynamic> row, List<User> members) {
    return Group(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      level: row['level'] as String,
      isPublic: (row['is_public'] as int? ?? 1) == 1,
      maxMembers: row['max_members'] as int? ?? 10,
      ownerId: row['owner_id'] as String,
      members: members,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  // ─── Users ────────────────────────────────────────────────────────────────

  Future<List<User>> getAllUsers() async {
    final db = await _conn;
    final rows = await db.query(_tu);
    return rows.map(_mapUser).toList();
  }

  Future<User?> getUserById(String id) async {
    final db = await _conn;
    final rows = await db.query(_tu, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _mapUser(rows.first);
  }

  // ─── Members for a group ─────────────────────────────────────────────────

  Future<List<User>> getMembersOfGroup(String groupId) async {
    final db = await _conn;
    final rows = await db.rawQuery('''
      SELECT u.*
      FROM $_tu u
      INNER JOIN $_tm m ON m.user_id = u.id
      WHERE m.group_id = ?
      ORDER BY m.joined_at ASC
    ''', [groupId]);
    return rows.map(_mapUser).toList();
  }

  // ─── Groups ───────────────────────────────────────────────────────────────

  Future<List<Group>> getGroups() async {
    final db = await _conn;
    final rows = await db.query(_tg, orderBy: 'created_at DESC');
    final groups = <Group>[];
    for (final row in rows) {
      final members = await getMembersOfGroup(row['id'] as String);
      groups.add(_mapGroup(row, members));
    }
    return groups;
  }

  Future<Group?> getGroupById(String id) async {
    final db = await _conn;
    final rows = await db.query(_tg, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final members = await getMembersOfGroup(id);
    return _mapGroup(rows.first, members);
  }

  Future<Group> addGroup(Group group) async {
    final db = await _conn;
    await db.insert(
      _tg,
      {
        'id': group.id,
        'name': group.name,
        'description': group.description,
        'level': group.level,
        'is_public': group.isPublic ? 1 : 0,
        'max_members': group.maxMembers,
        'owner_id': group.ownerId,
        'created_at': group.createdAt.toIso8601String(),
      },
    );
    // Persist initial members supplied during creation
    final now = DateTime.now().toIso8601String();
    for (final m in group.members) {
      await _insertMember(db, group.id, m.id, now);
    }
    return (await getGroupById(group.id))!;
  }

  Future<Group> updateGroup(Group group) async {
    final db = await _conn;
    await db.update(
      _tg,
      {
        'name': group.name,
        'description': group.description,
        'level': group.level,
        'is_public': group.isPublic ? 1 : 0,
        'max_members': group.maxMembers,
      },
      where: 'id = ?',
      whereArgs: [group.id],
    );

    // Replace membership list when the edit form changed members
    await db.delete(_tm, where: 'group_id = ?', whereArgs: [group.id]);
    final now = DateTime.now().toIso8601String();
    for (final m in group.members) {
      await _insertMember(db, group.id, m.id, now);
    }
    return (await getGroupById(group.id))!;
  }

  Future<bool> deleteGroup(String id) async {
    final db = await _conn;
    // ON DELETE CASCADE removes members + requests
    final deleted =
        await db.delete(_tg, where: 'id = ?', whereArgs: [id]);
    return deleted > 0;
  }

  // ─── Membership ──────────────────────────────────────────────────────────

  Future<bool> isMember(String groupId, String userId) async {
    final db = await _conn;
    final rows = await db.query(
      _tm,
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
    return rows.isNotEmpty;
  }

  /// Joins a public group.
  ///
  /// Returns `null` on success, or an error string describing why it failed.
  Future<String?> joinGroup(String groupId, String userId) async {
    final db = await _conn;

    return db.transaction<String?>((txn) async {
      // Guard: already a member?
      final alreadyMember = await txn.query(
        _tm,
        where: 'group_id = ? AND user_id = ?',
        whereArgs: [groupId, userId],
      );
      if (alreadyMember.isNotEmpty) return 'Vous êtes déjà membre du groupe.';

      // Guard: capacity?
      final memberCount = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COUNT(*) FROM $_tm WHERE group_id = ?',
        [groupId],
      ))!;
      final groupRow = await txn.query(_tg,
          columns: ['max_members'], where: 'id = ?', whereArgs: [groupId]);
      if (groupRow.isEmpty) return 'Groupe introuvable.';
      final maxMembers = groupRow.first['max_members'] as int;
      if (memberCount >= maxMembers) return 'Le groupe est complet.';

      await txn.insert(_tm, {
        'group_id': groupId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
      });
      return null;
    });
  }

  /// Leaves a group.
  ///
  /// The owner cannot leave — they must delete or transfer ownership first.
  Future<String?> leaveGroup(String groupId, String userId) async {
    final db = await _conn;

    return db.transaction<String?>((txn) async {
      final groupRow = await txn.query(_tg,
          columns: ['owner_id'], where: 'id = ?', whereArgs: [groupId]);
      if (groupRow.isEmpty) return 'Groupe introuvable.';
      if (groupRow.first['owner_id'] == userId) {
        return 'Le créateur ne peut pas quitter son propre groupe.';
      }

      await txn.delete(
        _tm,
        where: 'group_id = ? AND user_id = ?',
        whereArgs: [groupId, userId],
      );
      return null;
    });
  }

  Future<void> _insertMember(
      DatabaseExecutor db, String groupId, String userId, String joinedAt) async {
    await db.insert(
      _tm,
      {'group_id': groupId, 'user_id': userId, 'joined_at': joinedAt},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ─── Join requests ───────────────────────────────────────────────────────

  /// Sends a join request for a private group.
  ///
  /// Returns `null` on success, error string on failure.
  Future<String?> sendJoinRequest(String groupId, String userId) async {
    final db = await _conn;

    return db.transaction<String?>((txn) async {
      // Already a member?
      final memberRows = await txn.query(_tm,
          where: 'group_id = ? AND user_id = ?', whereArgs: [groupId, userId]);
      if (memberRows.isNotEmpty) return 'Vous êtes déjà membre du groupe.';

      // Pending request already exists?
      final existing = await txn.query(
        _tr,
        where: "group_id = ? AND user_id = ? AND status = 'pending'",
        whereArgs: [groupId, userId],
      );
      if (existing.isNotEmpty) return 'Une demande est déjà en attente.';

      await txn.insert(_tr, {
        'id': 'req_${DateTime.now().millisecondsSinceEpoch}',
        'group_id': groupId,
        'user_id': userId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      return null;
    });
  }

  /// Cancels a pending join request.
  Future<bool> cancelJoinRequest(String groupId, String userId) async {
    final db = await _conn;
    final deleted = await db.delete(
      _tr,
      where:
          "group_id = ? AND user_id = ? AND status = 'pending'",
      whereArgs: [groupId, userId],
    );
    return deleted > 0;
  }

  /// Returns pending requests for a given group (for the owner).
  Future<List<JoinRequest>> getPendingRequests(String groupId) async {
    final db = await _conn;
    final rows = await db.rawQuery('''
      SELECT r.*, u.name AS user_name
      FROM $_tr r
      JOIN $_tu u ON u.id = r.user_id
      WHERE r.group_id = ? AND r.status = 'pending'
      ORDER BY r.created_at ASC
    ''', [groupId]);

    return rows.map((r) {
      return JoinRequest(
        id: r['id'] as String,
        groupId: r['group_id'] as String,
        userId: r['user_id'] as String,
        status: JoinRequestStatus.pending,
        createdAt: DateTime.parse(r['created_at'] as String),
        userName: r['user_name'] as String?,
      );
    }).toList();
  }

  /// Returns the pending request for a specific user/group, or `null`.
  Future<JoinRequest?> getPendingRequest(
      String groupId, String userId) async {
    final db = await _conn;
    final rows = await db.query(
      _tr,
      where: "group_id = ? AND user_id = ? AND status = 'pending'",
      whereArgs: [groupId, userId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return JoinRequest(
      id: r['id'] as String,
      groupId: r['group_id'] as String,
      userId: r['user_id'] as String,
      status: JoinRequestStatus.pending,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }

  /// Returns all pending join requests sent by a specific user across all groups.
  Future<List<JoinRequest>> getPendingRequestsForUser(String userId) async {
    final db = await _conn;
    final rows = await db.query(
      _tr,
      where: "user_id = ? AND status = 'pending'",
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) {
      return JoinRequest(
        id: r['id'] as String,
        groupId: r['group_id'] as String,
        userId: r['user_id'] as String,
        status: JoinRequestStatus.pending,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();
  }

  /// Accepts a pending join request (owner action).
  ///
  /// Returns `null` on success, error string on failure.
  Future<String?> acceptJoinRequest(
      String requestId, String groupId, String userId) async {
    final db = await _conn;

    return db.transaction<String?>((txn) async {
      // Capacity check
      final memberCount = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COUNT(*) FROM $_tm WHERE group_id = ?',
        [groupId],
      ))!;
      final groupRow = await txn.query(_tg,
          columns: ['max_members'], where: 'id = ?', whereArgs: [groupId]);
      if (groupRow.isEmpty) return 'Groupe introuvable.';
      if (memberCount >= (groupRow.first['max_members'] as int)) {
        return 'Le groupe est complet. Impossible d\'accepter cette demande.';
      }

      await txn.update(
        _tr,
        {
          'status': 'accepted',
          'reviewed_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [requestId],
      );

      await txn.insert(
        _tm,
        {
          'group_id': groupId,
          'user_id': userId,
          'joined_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return null;
    });
  }

  /// Rejects a pending join request (owner action).
  Future<bool> rejectJoinRequest(String requestId) async {
    final db = await _conn;
    final updated = await db.update(
      _tr,
      {
        'status': 'rejected',
        'reviewed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [requestId],
    );
    return updated > 0;
  }

  /// Removes a member from a group (owner action).
  ///
  /// Returns `null` on success, error string on failure.
  Future<String?> removeMember(String groupId, String userId) async {
    final db = await _conn;
    // Owner cannot be removed
    final groupRow = await db
        .query(_tg, columns: ['owner_id'], where: 'id = ?', whereArgs: [groupId]);
    if (groupRow.isNotEmpty && groupRow.first['owner_id'] == userId) {
      return 'Le créateur du groupe ne peut pas être retiré.';
    }
    await db.delete(
      _tm,
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
    return null;
  }
}
