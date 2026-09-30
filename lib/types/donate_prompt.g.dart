// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'donate_prompt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DonatePromptState _$DonatePromptStateFromJson(Map<String, dynamic> json) =>
    DonatePromptState(
        lastShownAt: (json['lastShownAt'] as num?)?.toInt(),
        muted: json['muted'] as bool? ?? false,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$DonatePromptStateToJson(DonatePromptState instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'lastShownAt': instance.lastShownAt,
      'muted': instance.muted,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
