import 'dart:async';
import 'package:flutter/foundation.dart';

import '/types/courses.dart';
import '/services/base.dart';

abstract class BaseCoursesService extends ChangeNotifier with BaseService {
  static const int heartbeatInterval = 300;
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeatTime;

  // Account Methods

  Future<void> doLogin(String cookie);

  Future<void> doLogout();

  Future<bool> doSendHeartbeat();

  Future<UserInfo> getUserInfo();

  Future<void> login(String cookie) async {
    await runLogin(() async {
      await doLogin(cookie);
      startHeartbeat();
    });
  }

  Future<void> logout() async {
    await runLogout(() async {
      stopHeartbeat();
      if (kDebugMode) {
        print('Courses service logout called at base class');
      }
      await doLogout();
    });
  }

  // Data Methods

  Future<List<CourseGradeItem>> getGrades();

  GpaOverview? getCachedGpaOverview();

  Future<GpaOverview?> fetchGpaOverview();

  Future<List<ScoreDetail>> fetchScoreDetails(String rwid, String cjid);

  Future<List<ExamInfo>> getExams(TermInfo termInfo);

  Future<List<ClassItem>> getCurriculum(TermInfo termInfo);

  Future<List<ClassPeriod>> getCoursePeriods(TermInfo termInfo);

  Future<List<CalendarDay>> getCalendarDays(TermInfo termInfo);

  Future<List<TermInfo>> getTerms();

  DateTime? getLastHeartbeatTime() => _lastHeartbeatTime;

  void startHeartbeat() {
    stopHeartbeat();
    sendHeartbeat();

    _heartbeatTimer = Timer.periodic(
      Duration(seconds: heartbeatInterval),
      (timer) => sendHeartbeat(),
    );
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> sendHeartbeat() async {
    try {
      if (isOnline) {
        final success = await doSendHeartbeat();
        if (success) {
          _lastHeartbeatTime = DateTime.now();
        }
        if (kDebugMode) {
          print('Course service heartbeat sent, success: $success');
        }
      }
    } catch (e) {
      // Ignored
    }
  }
}
