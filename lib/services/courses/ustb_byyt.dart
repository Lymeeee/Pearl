import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '/types/courses.dart';
import '/services/base.dart';
import '/services/courses/base.dart';
import '/services/courses/exceptions.dart';
import 'convert.dart';

class UstbByytService extends BaseCoursesService {
  late final Dio _dio;
  late final CookieJar _cookieJar;

  UstbByytService() {
    _cookieJar = CookieJar();
    _dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  @override
  String get defaultBaseUrl => 'https://byyt.ustb.edu.cn';

  @override
  set baseUrl(String url) {
    super.baseUrl = url;
    _dio.options.baseUrl = url;
  }

  @override
  Future<void> doLogin(String cookie) async {
    try {
      final uri = Uri.parse(baseUrl);
      final cookies = cookie
          .split(';')
          .map((c) {
            final parts = c.trim().split('=');
            if (parts.length >= 2) {
              return Cookie(parts[0], parts.sublist(1).join('='));
            }
            return null;
          })
          .whereType<Cookie>()
          .toList();

      await _cookieJar.saveFromResponse(uri, cookies);

      // Validate cookie by trying to get user info
      await getUserInfo();
    } catch (e) {
      await _cookieJar.deleteAll();
      if (e is CourseServiceException) rethrow;
      throw CourseServiceException(
        'Failed to login with cookie (unexpected exception)',
        e,
      );
    }
  }

  @override
  Future<void> doLogout() async {
    await _cookieJar.deleteAll();
  }

  @override
  Future<bool> doSendHeartbeat() async {
    if (status == ServiceStatus.offline) {
      return false;
    }

    try {
      final response = await _dio.post('/component/online');

      if (response.statusCode == 200) {
        final data = response.data;

        final success = data['code'] == 0;

        if (!success) {
          setError('Heartbeat failed: ${data['msg'] ?? 'No msg'}');
        }

        return success;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Future<UserInfo> getUserInfo() async {
    Response response;
    try {
      response = await _dio.post('/user/me');
    } catch (e) {
      throw CourseServiceNetworkError('Failed to to get user info', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, () {
      setError();
    });

    try {
      return UserInfoUstbByytExtension.parse(response.data);
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse user info response', e);
    }
  }

  @override
  Future<List<CourseGradeItem>> getGrades() async {
    Response response;
    try {
      response = await _dio.post(
        '/cjgl/grcjcx/grcjcx',
        data: {
          'xn': null,
          'xq': null,
          'kcmc': null,
          'pylx': '1',
          'current': 1,
          'pageSize': 1000,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get grades', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['code'] != 200) {
        throw CourseServiceBadRequest(
          'API returned error: ${data['msg'] ?? 'No msg'}',
          data['code'] as int?,
        );
      }
      if (data['content'] == null) {
        throw CourseServiceBadResponse('Response content is null');
      }
      if (data['content']['list'] == null) {
        return [];
      }

      // Try to extract grgpa from various possible locations in response
      Map<String, dynamic>? grgpa;
      final content = data['content'];
      if (content is Map<String, dynamic>) {
        grgpa = content['grgpa'] ?? content['grGpa'] ?? content['gpa'];
        if (grgpa == null) {
          // Search all keys in content for grgpa-like data
          for (final k in content.keys) {
            if (k.toString().toLowerCase().contains('grgpa') ||
                k.toString().toLowerCase().contains('gpa')) {
              grgpa = content[k];
              break;
            }
          }
        }
      }
      // Also try top-level
      grgpa ??= data['grgpa'] ?? data['grGpa'];
      // Also try to find PM/ZRS anywhere in response
      if (grgpa == null && content is Map<String, dynamic>) {
        if (content.containsKey('PM') || content.containsKey('ZRS')) {
          grgpa = content;
        }
      }
      if (grgpa != null) {
        _cachedGpaOverview = GpaOverview.fromJson(grgpa);
      }

      final gradeList = data['content']['list'] as List<dynamic>;

      return gradeList
          .map(
            (item) => CourseGradeItemUstbByytExtension.parse(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse grades response', e);
    }
  }

  GpaOverview? _cachedGpaOverview;

  @override
  GpaOverview? getCachedGpaOverview() => _cachedGpaOverview;

  @override
  Future<GpaOverview?> fetchGpaOverview() async {
    // Try multiple possible API endpoints
    final endpoints = [
      '/cjgl/grcjcx/getgpa',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _dio.post(
          endpoint,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          Map<String, dynamic>? grgpa;

          if (data is Map<String, dynamic>) {
            grgpa = data['grgpa'] ?? data['data']?['grgpa'];
            grgpa ??= data.containsKey('PM') ? data : null;
          }

          if (grgpa != null) {
            _cachedGpaOverview = GpaOverview.fromJson(grgpa);
            return _cachedGpaOverview;
          }
        }
      } catch (_) {
        // Try next endpoint
      }
    }

    return null;
  }

  Future<List<ScoreDetail>> fetchScoreDetails(String rwid, String cjid) async {
    Response response;
    try {
      response = await _dio.post(
        '/cjgl/grcjcx/seeFx',
        data: {'rwid': rwid, 'cjid': cjid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to fetch score details', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;
      if (data is List) {
        return data
            .map((item) => ScoreDetail.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse score details response',
        e,
      );
    }
  }

  @override
  Future<List<ExamInfo>> getExams(TermInfo termInfo) async {
    Response response;
    try {
      response = await _dio.post(
        '/kscxtj/queryXsksByxhList',
        data: {
          'ppylx': '1',
          'pkkyx': '',
          'pxn': termInfo.year,
          'pxq': termInfo.season.toString(),
          'pageNum': '1',
          'pageSize': '40',
        },
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get exams', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['code'] != null && data['code'] != 200) {
        throw CourseServiceBadRequest(
          'API returned error: ${data['msg'] ?? 'No msg'}',
          data['code'] as int?,
        );
      }
      if (data['list'] == null) {
        return [];
      }

      final examList = data['list'] as List<dynamic>;

      return examList
          .map(
            (item) =>
                ExamInfoUstbByytExtension.parse(item as Map<String, dynamic>),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse exams response', e);
    }
  }

  @override
  Future<List<ClassItem>> getCurriculum(TermInfo termInfo) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      response = await _dio.post(
        '/Xskbcx/queryXskbcxList',
        data: {
          'bs': '2',
          'xn': termInfo.year,
          'xq': termInfo.season.toString(),
        },
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get curriculum', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      // Handle different response formats
      List<dynamic> curriculumList;

      if (data is List) {
        // Direct array response
        curriculumList = data;
      } else if (data is Map<String, dynamic>) {
        if (data['code'] != 200) {
          throw CourseServiceBadRequest(
            'API returned error: ${data['msg'] ?? 'No msg'}',
            data['code'] as int?,
          );
        }
        if (data['content'] == null) {
          throw CourseServiceBadResponse('Response content is null');
        }

        curriculumList = data['content'] as List<dynamic>? ?? [];
      } else {
        throw CourseServiceBadResponse(
          'Unexpected response format (neither List nor Map)',
        );
      }

      // Parse curriculum items
      final classList = <ClassItem>[];
      for (final item in curriculumList) {
        final classItem = ClassItemUstbByytExtension.parse(
          item as Map<String, dynamic>,
        );
        if (classItem != null) {
          classList.add(classItem);
        }
      }

      return classList;
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse curriculum response', e);
    }
  }

  @override
  Future<List<ClassPeriod>> getCoursePeriods(TermInfo termInfo) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      response = await _dio.post(
        '/component/queryKbjg',
        data: {
          'xn': termInfo.year,
          'xq': termInfo.season.toString(),
          'nodataqx': '1',
        },
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get course periods', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['code'] != 200) {
        throw CourseServiceBadRequest(
          'API returned error: ${data['msg'] ?? 'No msg'}',
          data['code'] as int?,
        );
      }
      if (data['content'] == null) {
        throw CourseServiceBadResponse('Response content is null');
      }

      final periodsList = data['content'] as List<dynamic>? ?? [];

      return periodsList
          .map(
            (item) => ClassPeriodUstbByytExtension.parse(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse course periods response',
        e,
      );
    }
  }

  @override
  Future<List<CalendarDay>> getCalendarDays(TermInfo termInfo) async {
    Response response;

    try {
      response = await _dio.post(
        '/Xiaoli/queryMonthList',
        data: {'xn': termInfo.year, 'xq': termInfo.season.toString()},
        options: Options(headers: {'Rolecode': '01'}),
      );
    } catch (e) {
      throw CourseServiceNetworkError(
        'Failed to send calendar days request',
        e,
      );
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;
      final List<dynamic> xlListJson = data['xlList'] as List<dynamic>;
      final List<CalendarDay> calendarDays = xlListJson
          .map(
            (item) => CalendarDayUstbByytExtension.parse(
              item as Map<String, dynamic>,
            ),
          )
          .toList();

      return calendarDays;
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse calendar days response',
        e,
      );
    }
  }

  @override
  Future<List<TermInfo>> getTerms() async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      response = await _dio.post(
        '/component/queryXnxq',
        data: {'data': 'cTnrJ54+H2bKCT5c1Gq1+w=='},
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get terms', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['code'] != 200) {
        throw CourseServiceBadRequest(
          'API returned error: ${data['msg'] ?? 'No msg'}',
          data['code'] as int?,
        );
      }
      if (data['content'] == null) {
        throw CourseServiceBadResponse('Response content is null');
      }

      final termsList = data['content'] as List<dynamic>;

      return termsList
          .map(
            (item) =>
                TermInfoUstbByytExtension.parse(item as Map<String, dynamic>),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse terms response', e);
    }
  }
}
