import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import '../models/health_entry.dart';

class LocalDbService {
  static Database? _db;

  static Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'health_tracker.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE health_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            heartRate INTEGER NOT NULL,
            minHeartRate INTEGER NOT NULL,
            maxHeartRate INTEGER NOT NULL,
            spo2 INTEGER NOT NULL,
            stepCount INTEGER NOT NULL,
            battery INTEGER NOT NULL,
            chargingState INTEGER NOT NULL,
            sleepHours INTEGER NOT NULL,
            sportsTime INTEGER NOT NULL,
            screenStatus INTEGER NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }

  static Future<void> saveHealthEntry(HealthEntry entry) async {
    if (_db == null) await init();

    await _db!.insert('health_entries', {
      'userId': entry.userId,
      'heartRate': entry.heartRate,
      'minHeartRate': entry.minHeartRate,
      'maxHeartRate': entry.maxHeartRate,
      'spo2': entry.spo2,
      'stepCount': entry.stepCount,
      'battery': entry.battery,
      'chargingState': entry.chargingState,
      'sleepHours': entry.sleepHours,
      'sportsTime': entry.sportsTime,
      'screenStatus': entry.screenStatus,
      'timestamp': entry.timestamp.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateHealthEntry(HealthEntry entry) async {
    if (_db == null) await init();

    await _db!.update(
      'health_entries',
      {
        'userId': entry.userId,
        'heartRate': entry.heartRate,
        'minHeartRate': entry.minHeartRate,
        'maxHeartRate': entry.maxHeartRate,
        'spo2': entry.spo2,
        'stepCount': entry.stepCount,
        'battery': entry.battery,
        'chargingState': entry.chargingState,
        'sleepHours': entry.sleepHours,
        'sportsTime': entry.sportsTime,
        'screenStatus': entry.screenStatus,
        'timestamp': entry.timestamp.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  static Future<List<HealthEntry>> getHealthEntries({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_db == null) await init();

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause += 'userId = ?';
      whereArgs.add(userId);
    }

    if (startDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final List<Map<String, dynamic>> maps = await _db!.query(
      'health_entries',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return HealthEntry.fromMap(maps[i]);
    });
  }

  static Future<void> deleteHealthEntries({
    String? userId,
    DateTime? before,
  }) async {
    if (_db == null) await init();

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause += 'userId = ?';
      whereArgs.add(userId);
    }

    if (before != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp < ?';
      whereArgs.add(before.toIso8601String());
    }

    await _db!.delete(
      'health_entries',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
    );
  }

  static Future<HealthEntry?> getLatestEntry() async {
    if (_db == null) await init();
    final List<Map<String, dynamic>> maps = await _db!.query(
      'health_entries',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return maps.isEmpty ? null : HealthEntry.fromMap(maps.first);
  }

  static Future<List<HealthEntry>> getEntriesForToday() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = todayStart.add(const Duration(days: 1));
    return getEntriesForRange(todayStart, tomorrow);
  }

  static Future<List<HealthEntry>> getEntriesForRange(
    DateTime start,
    DateTime end,
  ) async {
    return getHealthEntries(startDate: start, endDate: end);
  }

  static Future<HealthEntry?> getEntryForHour(DateTime hourlyTimestamp) async {
    if (_db == null) await init();

    final List<Map<String, dynamic>> maps = await _db!.query(
      'health_entries',
      where: 'timestamp = ?',
      whereArgs: [hourlyTimestamp.toIso8601String()],
      limit: 1,
    );

    return maps.isEmpty ? null : HealthEntry.fromMap(maps.first);
  }

  /// 네이티브 SQLite 데이터베이스에서 데이터를 가져와서 동기화
  static Future<void> syncNativeHealthData({String? userId}) async {
    try {
      const platform = MethodChannel(
        'com.example.rabbithole_health_tracker_new/health',
      );

      // 네이티브 데이터 조회
      final List<dynamic> nativeData = await platform.invokeMethod(
        'getNativeHealthData',
        {'limit': 1000},
      );

      if (nativeData.isEmpty) {
        print('동기화할 네이티브 데이터가 없습니다.');
        return;
      }

      int syncedCount = 0;

      for (final Map<String, dynamic> nativeEntry in nativeData) {
        try {
          // 네이티브 데이터를 HealthEntry로 변환
          final healthEntry = HealthEntry.create(
            userId: userId ?? 'background_user',
            heartRate: nativeEntry['heartRate'] as int,
            minHeartRate: nativeEntry['heartRate'] as int,
            maxHeartRate: nativeEntry['heartRate'] as int,
            spo2: nativeEntry['spo2'] as int,
            stepCount: nativeEntry['stepCount'] as int,
            battery: nativeEntry['battery'] as int,
            chargingState: nativeEntry['chargingState'] as int,
            sleepHours: 0.0,
            sportsTime: 0,
            screenStatus: 0,
            timestamp: DateTime.parse(nativeEntry['timestamp'] as String),
          );

          // 중복 확인 후 저장
          final existingEntry = await getEntryForHour(healthEntry.timestamp);
          if (existingEntry == null) {
            await saveHealthEntry(healthEntry);
            syncedCount++;
          }
        } catch (e) {
          print('네이티브 데이터 변환 오류: $e');
        }
      }

      print('✅ 네이티브 데이터 동기화 완료: $syncedCount개 항목 추가');
    } catch (e) {
      print('❌ 네이티브 데이터 동기화 실패: $e');
    }
  }
}
