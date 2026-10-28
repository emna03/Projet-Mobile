import 'package:sqflite/sqflite.dart';

/// Contains the DDL statements and initial seed data for the StudyMate
/// SQLite database.  All methods are static so they can be called from
/// [AppDatabase] without an instance.
class DatabaseMigrations {
  DatabaseMigrations._();

  // ─── Table names ────────────────────────────────────────────────────────────

  static const String tUsers = 'users';
  static const String tGroups = 'groups';
  static const String tGroupMembers = 'group_members';
  static const String tGroupJoinRequests = 'group_join_requests';

  // ── Chat tables (added in DB version 2) ─────────────────────────────────────
  static const String tGroupMessages = 'group_messages';
  static const String tGroupAttachments = 'group_attachments';
  static const String tMessageReactions = 'message_reactions';
  static const String tPinnedMessages = 'pinned_messages';
  static const String tGroupPolls = 'group_polls';
  static const String tPollOptions = 'poll_options';
  static const String tPollVotes = 'poll_votes';

  // ─── Schema creation ────────────────────────────────────────────────────────

  static Future<void> createSchema(Database db) async {
    // ── Core tables (V1) ──────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tUsers (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        email          TEXT NOT NULL UNIQUE,
        role           TEXT NOT NULL DEFAULT "Étudiant",
        avatar_color   INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tGroups (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        description  TEXT NOT NULL DEFAULT "",
        level        TEXT NOT NULL,
        is_public    INTEGER NOT NULL DEFAULT 1,
        max_members  INTEGER NOT NULL DEFAULT 10,
        owner_id     TEXT NOT NULL,
        created_at   TEXT NOT NULL,
        FOREIGN KEY (owner_id) REFERENCES $tUsers(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tGroupMembers (
        group_id   TEXT NOT NULL,
        user_id    TEXT NOT NULL,
        joined_at  TEXT NOT NULL,
        PRIMARY KEY (group_id, user_id),
        FOREIGN KEY (group_id) REFERENCES $tGroups(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id)  REFERENCES $tUsers(id)  ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tGroupJoinRequests (
        id          TEXT PRIMARY KEY,
        group_id    TEXT NOT NULL,
        user_id     TEXT NOT NULL,
        status      TEXT NOT NULL DEFAULT "pending",
        created_at  TEXT NOT NULL,
        reviewed_at TEXT,
        FOREIGN KEY (group_id) REFERENCES $tGroups(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id)  REFERENCES $tUsers(id)  ON DELETE CASCADE
      )
    ''');

    // Indexes for frequent look-ups
    await db.execute(
        'CREATE INDEX idx_members_group ON $tGroupMembers(group_id)');
    await db.execute(
        'CREATE INDEX idx_members_user  ON $tGroupMembers(user_id)');
    await db.execute(
        'CREATE INDEX idx_requests_group  ON $tGroupJoinRequests(group_id)');
    await db.execute(
        'CREATE INDEX idx_requests_user   ON $tGroupJoinRequests(user_id)');
    await db.execute(
        'CREATE INDEX idx_requests_status ON $tGroupJoinRequests(status)');

    // ── Chat tables (V2) ──────────────────────────────────────────────────────
    await _createChatTables(db);
  }

  // ─── Chat schema (extracted so it can be called in migration too) ───────────

  static Future<void> _createChatTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tGroupMessages (
        id                   TEXT PRIMARY KEY,
        group_id             TEXT NOT NULL,
        sender_id            TEXT NOT NULL,
        message_type         TEXT NOT NULL DEFAULT "text",
        content              TEXT NOT NULL DEFAULT "",
        reply_to_message_id  TEXT,
        created_at           TEXT NOT NULL,
        updated_at           TEXT,
        deleted_at           TEXT,
        FOREIGN KEY (group_id)            REFERENCES $tGroups(id)         ON DELETE CASCADE,
        FOREIGN KEY (sender_id)           REFERENCES $tUsers(id)          ON DELETE CASCADE,
        FOREIGN KEY (reply_to_message_id) REFERENCES $tGroupMessages(id)  ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tGroupAttachments (
        id                TEXT PRIMARY KEY,
        message_id        TEXT NOT NULL,
        original_filename TEXT NOT NULL,
        local_path        TEXT NOT NULL,
        mime_type         TEXT NOT NULL DEFAULT "application/octet-stream",
        file_size         INTEGER NOT NULL DEFAULT 0,
        created_at        TEXT NOT NULL,
        FOREIGN KEY (message_id) REFERENCES $tGroupMessages(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tMessageReactions (
        message_id  TEXT NOT NULL,
        user_id     TEXT NOT NULL,
        emoji       TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        PRIMARY KEY (message_id, user_id, emoji),
        FOREIGN KEY (message_id) REFERENCES $tGroupMessages(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id)    REFERENCES $tUsers(id)         ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tPinnedMessages (
        group_id    TEXT NOT NULL,
        message_id  TEXT NOT NULL,
        pinned_by   TEXT NOT NULL,
        pinned_at   TEXT NOT NULL,
        PRIMARY KEY (group_id, message_id),
        FOREIGN KEY (group_id)   REFERENCES $tGroups(id)        ON DELETE CASCADE,
        FOREIGN KEY (message_id) REFERENCES $tGroupMessages(id) ON DELETE CASCADE,
        FOREIGN KEY (pinned_by)  REFERENCES $tUsers(id)         ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tGroupPolls (
        id          TEXT PRIMARY KEY,
        group_id    TEXT NOT NULL,
        message_id  TEXT NOT NULL,
        question    TEXT NOT NULL,
        created_by  TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        closed_at   TEXT,
        FOREIGN KEY (group_id)   REFERENCES $tGroups(id)        ON DELETE CASCADE,
        FOREIGN KEY (message_id) REFERENCES $tGroupMessages(id) ON DELETE CASCADE,
        FOREIGN KEY (created_by) REFERENCES $tUsers(id)         ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tPollOptions (
        id            TEXT PRIMARY KEY,
        poll_id       TEXT NOT NULL,
        option_text   TEXT NOT NULL,
        display_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (poll_id) REFERENCES $tGroupPolls(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tPollVotes (
        poll_id    TEXT NOT NULL,
        option_id  TEXT NOT NULL,
        user_id    TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (poll_id, user_id),
        FOREIGN KEY (poll_id)   REFERENCES $tGroupPolls(id)   ON DELETE CASCADE,
        FOREIGN KEY (option_id) REFERENCES $tPollOptions(id)  ON DELETE CASCADE,
        FOREIGN KEY (user_id)   REFERENCES $tUsers(id)        ON DELETE CASCADE
      )
    ''');

    // Indexes for chat
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_group ON $tGroupMessages(group_id, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_sender ON $tGroupMessages(sender_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reactions_message ON $tMessageReactions(message_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pinned_group ON $tPinnedMessages(group_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_polls_group ON $tGroupPolls(group_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_votes_poll ON $tPollVotes(poll_id)');
  }

  // ─── Migration V1 → V2 ──────────────────────────────────────────────────────

  static Future<void> migrateV1toV2(Database db) async {
    await _createChatTables(db);
  }

  // ─── Seed data (run only on first DB creation) ──────────────────────────────

  static Future<void> seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // ── Users ──────────────────────────────────────────────────────────────────
    final users = [
      {
        'id': 'u0', // current (logged-in) user
        'name': 'Ilyes Étudiant',
        'email': 'ilyes@studymate.tn',
        'role': 'Étudiant',
        'avatar_color': 0,
      },
      {
        'id': 'u1',
        'name': 'Sarah Ben Ali',
        'email': 'sarah.benali@example.com',
        'role': 'Déléguée',
        'avatar_color': 1,
      },
      {
        'id': 'u2',
        'name': 'Yassine Trabelsi',
        'email': 'yassine.t@example.com',
        'role': 'Étudiant',
        'avatar_color': 2,
      },
      {
        'id': 'u3',
        'name': 'Ines Haddad',
        'email': 'ines.haddad@example.com',
        'role': 'Étudiante',
        'avatar_color': 3,
      },
      {
        'id': 'u4',
        'name': 'Karim Mansour',
        'email': 'karim.m@example.com',
        'role': 'Étudiant',
        'avatar_color': 4,
      },
      {
        'id': 'u5',
        'name': 'Nacef Jouini',
        'email': 'nacef.j@example.com',
        'role': 'Étudiant',
        'avatar_color': 5,
      },
      {
        'id': 'u6',
        'name': 'Lina Gharbi',
        'email': 'lina.g@example.com',
        'role': 'Étudiante',
        'avatar_color': 0,
      },
      {
        'id': 'u7',
        'name': 'Ahmed Khemir',
        'email': 'ahmed.k@example.com',
        'role': 'Étudiant',
        'avatar_color': 1,
      },
      {
        'id': 'u8',
        'name': 'Meriem Louati',
        'email': 'meriem.l@example.com',
        'role': 'Étudiante',
        'avatar_color': 2,
      },
    ];

    final batch = db.batch();
    for (final u in users) {
      batch.insert(tUsers, u, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // ── Groups (owned by u1 for demo) ─────────────────────────────────────────
    final groups = [
      {
        'id': 'g1',
        'name': 'Spring Boot Masters',
        'description':
            "Groupe d'entraide pour la maîtrise de Spring Boot, REST APIs, et JPA Hibernate.",
        'level': 'Licence 3',
        'is_public': 1,
        'max_members': 10,
        'owner_id': 'u1',
        'created_at': DateTime.now()
            .subtract(const Duration(days: 12))
            .toIso8601String(),
      },
      {
        'id': 'g2',
        'name': 'Docker & DevOps',
        'description':
            "Apprentissage des conteneurs Docker, pipelines CI/CD et déploiements conteneurisés.",
        'level': 'Master 1',
        'is_public': 1,
        'max_members': 10,
        'owner_id': 'u2',
        'created_at':
            DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
      },
      {
        'id': 'g3',
        'name': 'API REST Avancées',
        'description':
            "Conception avancée d'APIs RESTful, validation DTO, et documentation Swagger/OpenAPI.",
        'level': 'Licence 2',
        'is_public': 0,
        'max_members': 8,
        'owner_id': 'u1',
        'created_at':
            DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        'id': 'g4',
        'name': 'Architecture Microservices',
        'description':
            "Étude des architectures distribuées, Service Discovery, Spring Cloud Gateway et Kafka.",
        'level': 'Master 1',
        'is_public': 1,
        'max_members': 12,
        'owner_id': 'u3',
        'created_at':
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
    ];

    for (final g in groups) {
      batch.insert(tGroups, g, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // ── Initial memberships ───────────────────────────────────────────────────
    final members = [
      {'group_id': 'g1', 'user_id': 'u1', 'joined_at': now},
      {'group_id': 'g1', 'user_id': 'u2', 'joined_at': now},
      {'group_id': 'g1', 'user_id': 'u3', 'joined_at': now},
      {'group_id': 'g1', 'user_id': 'u4', 'joined_at': now},
      {'group_id': 'g1', 'user_id': 'u5', 'joined_at': now},
      {'group_id': 'g1', 'user_id': 'u6', 'joined_at': now},
      {'group_id': 'g2', 'user_id': 'u2', 'joined_at': now},
      {'group_id': 'g2', 'user_id': 'u4', 'joined_at': now},
      {'group_id': 'g2', 'user_id': 'u7', 'joined_at': now},
      {'group_id': 'g2', 'user_id': 'u8', 'joined_at': now},
      {'group_id': 'g3', 'user_id': 'u1', 'joined_at': now},
      {'group_id': 'g3', 'user_id': 'u3', 'joined_at': now},
      {'group_id': 'g3', 'user_id': 'u6', 'joined_at': now},
      {'group_id': 'g4', 'user_id': 'u3', 'joined_at': now},
      {'group_id': 'g4', 'user_id': 'u1', 'joined_at': now},
      {'group_id': 'g4', 'user_id': 'u5', 'joined_at': now},
      {'group_id': 'g4', 'user_id': 'u7', 'joined_at': now},
      {'group_id': 'g4', 'user_id': 'u8', 'joined_at': now},
    ];

    for (final m in members) {
      batch.insert(tGroupMembers, m,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
  }
}
