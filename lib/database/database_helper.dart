import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/child_profile.dart';
import '../models/usage_record.dart';
import '../utils/time_utils.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tvpca.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE child_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        avatarColor INTEGER NOT NULL,
        dailyLimitMinutes INTEGER NOT NULL DEFAULT 120,
        mondayAllowed INTEGER NOT NULL DEFAULT 1,
        tuesdayAllowed INTEGER NOT NULL DEFAULT 1,
        wednesdayAllowed INTEGER NOT NULL DEFAULT 1,
        thursdayAllowed INTEGER NOT NULL DEFAULT 1,
        fridayAllowed INTEGER NOT NULL DEFAULT 1,
        saturdayAllowed INTEGER NOT NULL DEFAULT 1,
        sundayAllowed INTEGER NOT NULL DEFAULT 1,
        allowedStartHour INTEGER NOT NULL DEFAULT 8,
        allowedStartMinute INTEGER NOT NULL DEFAULT 0,
        allowedEndHour INTEGER NOT NULL DEFAULT 20,
        allowedEndMinute INTEGER NOT NULL DEFAULT 0,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE usage_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER NOT NULL,
        date TEXT NOT NULL,
        usedMinutes INTEGER NOT NULL,
        sessionCount INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (childId) REFERENCES child_profiles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_usage_child ON usage_records (childId)');
    await db.execute(
        'CREATE INDEX idx_usage_date ON usage_records (date)');

    await _createBlockedAppsTable(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createBlockedAppsTable(db);
    }
  }

  Future<void> _createBlockedAppsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS blocked_apps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER NOT NULL,
        packageName TEXT NOT NULL,
        appLabel TEXT NOT NULL,
        FOREIGN KEY (childId) REFERENCES child_profiles (id) ON DELETE CASCADE,
        UNIQUE(childId, packageName)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_blocked_child ON blocked_apps (childId)');
  }

  // Child Profile operations
  Future<int> insertChild(ChildProfile child) async {
    final db = await database;
    return await db.insert('child_profiles', child.toMap());
  }

  Future<List<ChildProfile>> getActiveChildren() async {
    final db = await database;
    final maps = await db.query(
      'child_profiles',
      where: 'isActive = 1',
      orderBy: 'name ASC',
    );
    return maps.map((map) => ChildProfile.fromMap(map)).toList();
  }

  Future<ChildProfile?> getChild(int id) async {
    final db = await database;
    final maps = await db.query(
      'child_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ChildProfile.fromMap(maps.first);
  }

  Future<int> updateChild(ChildProfile child) async {
    final db = await database;
    return await db.update(
      'child_profiles',
      child.toMap(),
      where: 'id = ?',
      whereArgs: [child.id],
    );
  }

  Future<int> deactivateChild(int id) async {
    final db = await database;
    return await db.update(
      'child_profiles',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Usage Record operations
  Future<UsageRecord?> getUsageForDate(int childId, String date) async {
    final db = await database;
    final maps = await db.query(
      'usage_records',
      where: 'childId = ? AND date = ?',
      whereArgs: [childId, date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UsageRecord.fromMap(maps.first);
  }

  Future<int> getTotalMinutesForDate(int childId, String date) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(usedMinutes), 0) as total FROM usage_records WHERE childId = ? AND date = ?',
      [childId, date],
    );
    return result.first['total'] as int;
  }

  Future<List<UsageRecord>> getRecentUsage(int childId, {int days = 7}) async {
    final db = await database;
    final maps = await db.query(
      'usage_records',
      where: 'childId = ?',
      whereArgs: [childId],
      orderBy: 'date DESC',
      limit: days,
    );
    return maps.map((map) => UsageRecord.fromMap(map)).toList();
  }

  Future<void> recordUsage(int childId, int minutes) async {
    final db = await database;
    final today = TimeUtils.todayString();
    final existing = await getUsageForDate(childId, today);

    if (existing != null) {
      await db.update(
        'usage_records',
        {
          'usedMinutes': existing.usedMinutes + minutes,
          'sessionCount': existing.sessionCount + 1,
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      await db.insert('usage_records', UsageRecord(
        childId: childId,
        date: today,
        usedMinutes: minutes,
      ).toMap());
    }
  }

  // Blocked App operations
  Future<void> setBlockedApps(int childId, List<Map<String, String>> apps) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('blocked_apps', where: 'childId = ?', whereArgs: [childId]);
      for (final app in apps) {
        await txn.insert('blocked_apps', {
          'childId': childId,
          'packageName': app['packageName'],
          'appLabel': app['appLabel'],
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getBlockedApps(int childId) async {
    final db = await database;
    return await db.query(
      'blocked_apps',
      where: 'childId = ?',
      whereArgs: [childId],
      orderBy: 'appLabel ASC',
    );
  }

  Future<int> getBlockedAppCount(int childId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM blocked_apps WHERE childId = ?',
      [childId],
    );
    return result.first['count'] as int;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
