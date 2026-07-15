// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'courses.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserInfo _$UserInfoFromJson(Map<String, dynamic> json) =>
    UserInfo(
        userName: json['userName'] as String,
        userNameAlt: json['userNameAlt'] as String,
        userSchool: json['userSchool'] as String,
        userSchoolAlt: json['userSchoolAlt'] as String,
        userId: json['userId'] as String,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$UserInfoToJson(UserInfo instance) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'userName': instance.userName,
  'userNameAlt': instance.userNameAlt,
  'userSchool': instance.userSchool,
  'userSchoolAlt': instance.userSchoolAlt,
  'userId': instance.userId,
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

UserLoginIntegratedData _$UserLoginIntegratedDataFromJson(
  Map<String, dynamic> json,
) =>
    UserLoginIntegratedData(
        user: json['user'] == null
            ? null
            : UserInfo.fromJson(json['user'] as Map<String, dynamic>),
        method: json['method'] as String?,
        cookie: json['cookie'] as String?,
        lastSmsPhone: json['lastSmsPhone'] as String?,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$UserLoginIntegratedDataToJson(
  UserLoginIntegratedData instance,
) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'user': instance.user,
  'method': instance.method,
  'cookie': instance.cookie,
  'lastSmsPhone': instance.lastSmsPhone,
};

CourseGradeItem _$CourseGradeItemFromJson(Map<String, dynamic> json) =>
    CourseGradeItem(
        courseId: json['courseId'] as String,
        courseName: json['courseName'] as String,
        courseNameAlt: json['courseNameAlt'] as String?,
        termId: json['termId'] as String,
        termName: json['termName'] as String,
        termNameAlt: json['termNameAlt'] as String,
        type: json['type'] as String,
        category: json['category'] as String,
        schoolName: json['schoolName'] as String?,
        schoolNameAlt: json['schoolNameAlt'] as String?,
        makeupStatus: json['makeupStatus'] as String?,
        makeupStatusAlt: json['makeupStatusAlt'] as String?,
        examType: json['examType'] as String?,
        hours: (json['hours'] as num).toDouble(),
        credit: (json['credit'] as num).toDouble(),
        score: (json['score'] as num).toDouble(),
        rwid: json['rwid'] as String? ?? '',
        cjid: json['cjid'] as String? ?? '',
        rank: (json['rank'] as num?)?.toInt(),
        totalStudents: (json['totalStudents'] as num?)?.toInt(),
        scoreDetails: (json['scoreDetails'] as List<dynamic>?)
            ?.map((e) => ScoreDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$CourseGradeItemToJson(CourseGradeItem instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'courseId': instance.courseId,
      'courseName': instance.courseName,
      'courseNameAlt': instance.courseNameAlt,
      'termId': instance.termId,
      'termName': instance.termName,
      'termNameAlt': instance.termNameAlt,
      'type': instance.type,
      'category': instance.category,
      'schoolName': instance.schoolName,
      'schoolNameAlt': instance.schoolNameAlt,
      'makeupStatus': instance.makeupStatus,
      'makeupStatusAlt': instance.makeupStatusAlt,
      'examType': instance.examType,
      'hours': instance.hours,
      'credit': instance.credit,
      'score': instance.score,
      'rwid': instance.rwid,
      'cjid': instance.cjid,
      'rank': instance.rank,
      'totalStudents': instance.totalStudents,
      'scoreDetails': instance.scoreDetails,
    };

ClassItem _$ClassItemFromJson(Map<String, dynamic> json) =>
    ClassItem(
        day: (json['day'] as num).toInt(),
        period: (json['period'] as num).toInt(),
        weeks: (json['weeks'] as List<dynamic>)
            .map((e) => (e as num).toInt())
            .toList(),
        weeksText: json['weeksText'] as String,
        className: json['className'] as String,
        classNameAlt: json['classNameAlt'] as String?,
        teacherName: json['teacherName'] as String,
        teacherNameAlt: json['teacherNameAlt'] as String?,
        locationName: json['locationName'] as String,
        locationNameAlt: json['locationNameAlt'] as String?,
        periodName: json['periodName'] as String,
        periodNameAlt: json['periodNameAlt'] as String?,
        colorId: (json['colorId'] as num?)?.toInt(),
        isCustom: json['isCustom'] as bool? ?? false,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$ClassItemToJson(ClassItem instance) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'day': instance.day,
  'period': instance.period,
  'weeks': instance.weeks,
  'weeksText': instance.weeksText,
  'className': instance.className,
  'classNameAlt': instance.classNameAlt,
  'teacherName': instance.teacherName,
  'teacherNameAlt': instance.teacherNameAlt,
  'locationName': instance.locationName,
  'locationNameAlt': instance.locationNameAlt,
  'periodName': instance.periodName,
  'periodNameAlt': instance.periodNameAlt,
  'colorId': instance.colorId,
  'isCustom': instance.isCustom,
};

ClassPeriod _$ClassPeriodFromJson(Map<String, dynamic> json) =>
    ClassPeriod(
        termYear: json['termYear'] as String,
        termSeason: (json['termSeason'] as num).toInt(),
        majorId: (json['majorId'] as num).toInt(),
        minorId: (json['minorId'] as num).toInt(),
        majorName: json['majorName'] as String,
        minorName: json['minorName'] as String,
        majorStartTime: json['majorStartTime'] as String?,
        majorEndTime: json['majorEndTime'] as String?,
        minorStartTime: json['minorStartTime'] as String,
        minorEndTime: json['minorEndTime'] as String,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$ClassPeriodToJson(ClassPeriod instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'termYear': instance.termYear,
      'termSeason': instance.termSeason,
      'majorId': instance.majorId,
      'minorId': instance.minorId,
      'majorName': instance.majorName,
      'minorName': instance.minorName,
      'majorStartTime': instance.majorStartTime,
      'majorEndTime': instance.majorEndTime,
      'minorStartTime': instance.minorStartTime,
      'minorEndTime': instance.minorEndTime,
    };

CalendarDay _$CalendarDayFromJson(Map<String, dynamic> json) =>
    CalendarDay(
        year: (json['year'] as num).toInt(),
        month: (json['month'] as num).toInt(),
        day: (json['day'] as num).toInt(),
        weekday: (json['weekday'] as num).toInt(),
        weekIndex: (json['weekIndex'] as num).toInt(),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$CalendarDayToJson(CalendarDay instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'year': instance.year,
      'month': instance.month,
      'day': instance.day,
      'weekday': instance.weekday,
      'weekIndex': instance.weekIndex,
    };

TermInfo _$TermInfoFromJson(Map<String, dynamic> json) =>
    TermInfo(
        year: json['year'] as String,
        season: (json['season'] as num).toInt(),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$TermInfoToJson(TermInfo instance) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'year': instance.year,
  'season': instance.season,
};

CurriculumIntegratedData _$CurriculumIntegratedDataFromJson(
  Map<String, dynamic> json,
) =>
    CurriculumIntegratedData(
        currentTerm: TermInfo.fromJson(
          json['currentTerm'] as Map<String, dynamic>,
        ),
        allClasses: (json['allClasses'] as List<dynamic>)
            .map((e) => ClassItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        allPeriods: (json['allPeriods'] as List<dynamic>)
            .map((e) => ClassPeriod.fromJson(e as Map<String, dynamic>))
            .toList(),
        calendarDays: (json['calendarDays'] as List<dynamic>?)
            ?.map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        summerTermStartDate: json['summerTermStartDate'] == null
            ? null
            : DateTime.parse(json['summerTermStartDate'] as String),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$CurriculumIntegratedDataToJson(
  CurriculumIntegratedData instance,
) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'currentTerm': instance.currentTerm,
  'allClasses': instance.allClasses,
  'allPeriods': instance.allPeriods,
  'calendarDays': instance.calendarDays,
  'summerTermStartDate': instance.summerTermStartDate?.toIso8601String(),
};

ExamInfo _$ExamInfoFromJson(Map<String, dynamic> json) =>
    ExamInfo(
        courseId: json['courseId'] as String,
        examRange: json['examRange'] as String,
        examRangeAlt: json['examRangeAlt'] as String?,
        courseName: json['courseName'] as String,
        courseNameAlt: json['courseNameAlt'] as String?,
        termYear: json['termYear'] as String,
        termSeason: (json['termSeason'] as num).toInt(),
        examRoom: json['examRoom'] as String,
        examRoomAlt: json['examRoomAlt'] as String?,
        examBuilding: json['examBuilding'] as String?,
        examBuildingAlt: json['examBuildingAlt'] as String?,
        examWeek: (json['examWeek'] as num).toInt(),
        examDate: DateTime.parse(json['examDate'] as String),
        examDateDisplay: json['examDateDisplay'] as String,
        examDateDisplayAlt: json['examDateDisplayAlt'] as String?,
        examDayName: json['examDayName'] as String,
        examDayNameAlt: json['examDayNameAlt'] as String?,
        examTime: json['examTime'] as String,
        minorId: (json['minorId'] as num).toInt(),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$ExamInfoToJson(ExamInfo instance) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'courseId': instance.courseId,
  'examRange': instance.examRange,
  'examRangeAlt': instance.examRangeAlt,
  'courseName': instance.courseName,
  'courseNameAlt': instance.courseNameAlt,
  'termYear': instance.termYear,
  'termSeason': instance.termSeason,
  'examRoom': instance.examRoom,
  'examRoomAlt': instance.examRoomAlt,
  'examBuilding': instance.examBuilding,
  'examBuildingAlt': instance.examBuildingAlt,
  'examWeek': instance.examWeek,
  'examDate': instance.examDate.toIso8601String(),
  'examDateDisplay': instance.examDateDisplay,
  'examDateDisplayAlt': instance.examDateDisplayAlt,
  'examDayName': instance.examDayName,
  'examDayNameAlt': instance.examDayNameAlt,
  'examTime': instance.examTime,
  'minorId': instance.minorId,
};
