import '/types/courses.dart';

extension UserInfoUstbByytExtension on UserInfo {
  static UserInfo parse(Map<String, dynamic> data) {
    return UserInfo(
      userName: data['xm'] as String,
      userNameAlt: data['xm_en'] as String? ?? '',
      userSchool: data['bmmc'] as String? ?? '',
      userSchoolAlt: data['bmmc_en'] as String? ?? '',
      userId: data['yhdm'] as String? ?? '',
    );
  }
}

extension CourseGradeItemUstbByytExtension on CourseGradeItem {
  static CourseGradeItem parse(Map<String, dynamic> data) {
    return CourseGradeItem(
      courseId: data['kcdm'] as String? ?? '',
      courseName: data['kcmc'] as String? ?? '',
      courseNameAlt: data['kcmc_en'] as String?,
      termId: data['xnxq'] as String? ?? '',
      termName: data['xnxqmc'] as String? ?? '',
      termNameAlt: data['xnxqmcen'] as String? ?? '',
      type: data['kcxz'] as String? ?? '',
      category: data['kclb'] as String? ?? '',
      schoolName: data['yxmc'] as String?,
      schoolNameAlt: data['yxmc_en'] as String?,
      makeupStatus: data['bkcx'] as String?,
      makeupStatusAlt: data['bkcx_en'] as String?,
      examType: data['khfs'] as String?,
      hours: double.tryParse(data['xs']?.toString() ?? '0') ?? 0,
      credit: double.tryParse(data['xf']?.toString() ?? '0') ?? 0,
      score: double.tryParse(data['zpzscj']?.toString() ?? '0') ?? 0,
      rwid: (data['rwid'] ?? data['RWID'] ?? data['rw_id'])?.toString() ?? '',
      cjid: (data['id'] ?? data['ID'] ?? data['cjid'] ?? data['xh'])?.toString() ?? '',
      rank: int.tryParse(data['pm']?.toString() ?? ''),
      totalStudents: int.tryParse(data['zrs']?.toString() ?? ''),
    );
  }
}

extension ClassItemUstbByytExtension on ClassItem {
  static ClassItem? parse(Map<String, dynamic> data) {
    try {
      final key = data['key'] as String?;
      final kbxx = data['kbxx'] as String?;
      if (key == null || kbxx == null || key == 'bz') {
        // 跳过非正常课程格式或不排课课程
        return null;
      }

      // 从 key 解析 day 和 period
      final keyMatch = RegExp(r'xq(\d+)_jc(\d+)').firstMatch(key);
      if (keyMatch == null) {
        return null;
      }

      final day = int.parse(keyMatch.group(1)!);
      final period = int.parse(keyMatch.group(2)!);

      // 解析 kbxx 内容
      final lines = kbxx.split('\n');
      if (lines.length < 3) {
        return null;
      }

      String className = '';
      String teacherName = '';
      String weeksText = '';
      String locationName = '';
      String periodName = '';

      if (3 <= lines.length && lines.length <= 4) {
        className = lines[0].trim();
        teacherName = lines[1].trim();
        weeksText = lines[2].trim();
      } else if (lines.length == 5) {
        className = lines[0].trim();
        teacherName = lines[1].trim();
        weeksText = lines[2].trim();
        locationName = lines[3].trim();
        periodName = lines[4].trim();
      } else if (lines.length == 6) {
        className = "${lines[0]}\n${lines[1]}".trim();
        teacherName = lines[2].trim();
        weeksText = lines[3].trim();
        locationName = lines[4].trim();
        periodName = lines[5].trim();
      } else {
        return null;
      }

      // 解析周次
      final weeks = _parseWeeks(weeksText);

      // 从课程名称生成颜色ID（简单哈希）
      final colorId = className.hashCode % 10;

      return ClassItem(
        day: day,
        period: period,
        weeks: weeks,
        weeksText: weeksText,
        className: className,
        classNameAlt: '',
        teacherName: teacherName,
        teacherNameAlt: '',
        locationName: locationName,
        locationNameAlt: '',
        periodName: periodName,
        periodNameAlt: '',
        colorId: colorId,
      );
    } catch (e) {
      return null;
    }
  }

  static List<int> _parseWeeks(String weeksText) {
    final weeks = <int>[];

    // 替换中文逗号，移除"周"字符
    final cleanText = weeksText.replaceAll('，', ',').replaceAll('周', '').trim();

    // 按逗号分割不同的周期段
    final segments = cleanText.split(',');

    for (final segment in segments) {
      final trimmedSegment = segment.trim();
      if (trimmedSegment.isEmpty) continue;

      // 检测单/双周标记
      bool? oddOnly;
      if (trimmedSegment.contains('单')) {
        oddOnly = true;
      } else if (trimmedSegment.contains('双')) {
        oddOnly = false;
      }

      // 移除单/双标记以便解析数字
      final numberSegment = trimmedSegment
          .replaceAll('单', '')
          .replaceAll('双', '')
          .trim();

      if (numberSegment.contains('-')) {
        // 处理范围，如 "1-8" 或 "9-16单"
        final parts = numberSegment.split('-');
        if (parts.length == 2) {
          final start = int.tryParse(parts[0].trim());
          final end = int.tryParse(parts[1].trim());
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              if (oddOnly == null) {
                weeks.add(i);
              } else if (oddOnly == true && i.isOdd) {
                weeks.add(i);
              } else if (oddOnly == false && i.isEven) {
                weeks.add(i);
              }
            }
          }
        }
      } else {
        // 处理单个周次，如 "1" 或 "3"
        final week = int.tryParse(numberSegment);
        if (week != null) {
          weeks.add(week);
        }
      }
    }

    // 去重并排序
    return weeks.toSet().toList()..sort();
  }
}

extension ClassPeriodUstbByytExtension on ClassPeriod {
  static ClassPeriod parse(Map<String, dynamic> data) {
    return ClassPeriod(
      termYear: data['xn'] as String? ?? '',
      termSeason: int.tryParse(data['xq']?.toString() ?? '1') ?? 1,
      majorId: int.tryParse(data['dj']?.toString() ?? '1') ?? 1,
      minorId: int.tryParse(data['xj']?.toString() ?? '1') ?? 1,
      majorName: data['djms'] as String? ?? '',
      minorName: data['xjms'] as String? ?? '',
      majorStartTime: data['kskssj'] as String?,
      majorEndTime: data['ksjssj'] as String?,
      minorStartTime: data['kssj'] as String? ?? '',
      minorEndTime: data['jssj'] as String? ?? '',
    );
  }
}

extension CalendarDayUstbByytExtension on CalendarDay {
  static CalendarDay parse(Map<String, dynamic> data) {
    final dateParts = (data['RQ'] as String).split('-');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);

    int weekday = 7;
    if (data['MON'] != null) {
      weekday = 1;
    } else if (data['TUE'] != null || data['TUES'] != null) {
      weekday = 2;
    } else if (data['WED'] != null) {
      weekday = 3;
    } else if (data['THU'] != null || data['THUR'] != null) {
      weekday = 4;
    } else if (data['FRI'] != null) {
      weekday = 5;
    } else if (data['SAT'] != null) {
      weekday = 6;
    }

    final rawWeekIndex = data['ZC'] as int? ?? -1;
    final weekIndex = (rawWeekIndex >= 99 || rawWeekIndex <= 0)
        ? -1
        : rawWeekIndex;

    return CalendarDay(
      year: year,
      month: month,
      day: day,
      weekday: weekday,
      weekIndex: weekIndex,
    );
  }
}

extension TermInfoUstbByytExtension on TermInfo {
  static TermInfo parse(Map<String, dynamic> data) {
    return TermInfo(
      year: data['xn'] as String,
      season: int.parse(data['xq'].toString()),
    );
  }
}

extension ExamInfoUstbByytExtension on ExamInfo {
  static ExamInfo parse(Map<String, dynamic> data) {
    // Parse KSRQ datetime string (ISO format)
    DateTime examDate = DateTime.now();
    try {
      final ksrq = data['KSRQ'] as String?;
      if (ksrq != null) {
        examDate = DateTime.parse(ksrq);
      }
    } catch (e) {
      // If parsing fails, use current datetime
    }

    return ExamInfo(
      courseId: data['KCDM'] as String? ?? '',
      examRange: data['KSSJDMC'] as String? ?? '',
      examRangeAlt: data['KSSJDMC_EN'] as String?,
      courseName: data['KCMC'] as String? ?? '',
      courseNameAlt: data['KCMC_EN'] as String?,
      termYear: data['XN'] as String? ?? '',
      termSeason: int.tryParse(data['XQ']?.toString() ?? '0') ?? 0,
      examRoom: data['CDMC'] as String? ?? '',
      examRoomAlt: data['CDMC_EN'] as String?,
      examBuilding: data['JXLMC'] as String?,
      examBuildingAlt: data['JXLMC_EN'] as String?,
      examWeek: data['DJZ'] as int,
      examDate: examDate,
      examDateDisplay: data['KSRQ2'] as String? ?? '',
      examDateDisplayAlt: data['KSRQ_EN'] as String?,
      examDayName: data['XQJMC'] as String? ?? '',
      examDayNameAlt: data['XQJMC_EN'] as String?,
      examTime: data['KSJTSJ'] as String? ?? '',
      minorId: int.tryParse(data['KSJC']?.toString() ?? '0') ?? 0,
    );
  }
}
