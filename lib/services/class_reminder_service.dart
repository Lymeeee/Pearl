import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '/services/provider.dart';
import '/types/courses.dart';
import '/types/preferences.dart';

class ClassReminderService {
  static final ClassReminderService instance = ClassReminderService._();
  ClassReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Timer? _midnightTimer;
  int _nextNotificationId = 0;
  bool _initialized = false;

  bool get isRunning => _midnightTimer != null && _midnightTimer!.isActive;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(const InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    ));
    _initialized = true;

    final prefs = ServiceProvider.instance.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    if (prefs?.classReminderEnabled == true) {
      start();
    }
  }

  Future<void> requestPermission() async {
    if (!_initialized) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );
  }

  void start() {
    stop();
    _scheduleAllNotifications();
    _scheduleMidnightRefresh();
  }

  void stop() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
    _plugin.cancelAll();
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final midnight =
        DateTime(now.year, now.month, now.day + 1, 0, 1, 0);
    _midnightTimer = Timer(midnight.difference(now), () {
      _scheduleAllNotifications();
      _scheduleMidnightRefresh();
    });
  }

  void _scheduleAllNotifications() async {
    await _plugin.cancelAll();
    _nextNotificationId = 0;

    final store = ServiceProvider.instance.storeService;
    final data = store.getConfig<CurriculumIntegratedData>(
      'curriculum_data',
      CurriculumIntegratedData.fromJson,
    );
    if (data == null) return;

    // Merge custom courses
    final customKey =
        'custom_courses_${data.currentTerm.year}_${data.currentTerm.season}';
    final customData = store.getPref<CustomCoursesList>(
      customKey,
      CustomCoursesList.fromJson,
    );
    final customCourses = customData?.courses ?? [];

    final allClasses = [...data.allClasses, ...customCourses];

    // Schedule notifications for today and tomorrow
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (int dayOffset = 0; dayOffset < 2; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      final weekIndex = _getWeekIndexForDate(data, targetDate);
      if (weekIndex == null) continue;

      final weekday = data.currentTerm.season >= 3 &&
              (data.calendarDays == null || data.calendarDays!.isEmpty)
          ? 1
          : targetDate.weekday;

      for (final cls in allClasses) {
        if (cls.day != weekday) continue;
        if (!cls.weeks.contains(weekIndex)) continue;

        final startTime = cls.getMinStartTime(data.allPeriods);
        if (startTime == null) continue;

        final classDateTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          startTime.hour,
          startTime.minute,
        );

        final notifyTime = classDateTime.subtract(const Duration(minutes: 25));
        if (notifyTime.isBefore(now)) continue;

        final timeStr =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

        await _plugin.zonedSchedule(
          _nextNotificationId++,
          '距离下节课还有25分钟',
          '${cls.className}  $timeStr  ${cls.locationName}',
          tz.TZDateTime.from(notifyTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'class_reminder',
              '课程提醒',
              channelDescription: '课前25分钟提醒',
              importance: Importance.high,
              priority: Priority.high,
              showWhen: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: false,
              presentSound: true,
            ),
            macOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: false,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  int? _getWeekIndexForDate(CurriculumIntegratedData data, DateTime date) {
    // First try exact match from calendarDays
    if (data.calendarDays != null) {
      for (final cd in data.calendarDays!) {
        if (cd.year == date.year &&
            cd.month == date.month &&
            cd.day == date.day) {
          return cd.weekIndex;
        }
      }
    }

    // Summer term: every day is week 1
    if (data.currentTerm.season >= 3) return 1;

    if (data.calendarDays == null || data.calendarDays!.isEmpty) return null;

    // Extrapolate: find the closest calendar day and compute weeks from it
    int? baseWeek;
    DateTime? baseDate;
    int minDiff = 999999;

    for (final cd in data.calendarDays!) {
      final cdDate = DateTime(cd.year, cd.month, cd.day);
      final diff = date.difference(cdDate).inDays.abs();
      if (diff < minDiff) {
        minDiff = diff;
        baseWeek = cd.weekIndex;
        baseDate = cdDate;
      }
    }

    if (baseWeek == null || baseDate == null) return null;

    final daysDiff = date.difference(baseDate).inDays;
    final weeksDiff = (daysDiff / 7).round();
    final estimated = baseWeek + weeksDiff;
    final maxWeek = data.getMaxValidWeekIndex();
    return estimated.clamp(1, maxWeek);
  }

  void dispose() {
    stop();
  }
}
