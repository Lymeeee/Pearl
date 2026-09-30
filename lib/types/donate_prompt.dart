import 'package:json_annotation/json_annotation.dart';
import 'base.dart';

part 'donate_prompt.g.dart';

/// 捐赠提醒的展示状态
@JsonSerializable()
class DonatePromptState extends BaseDataClass {
  /// 上次展示时间（毫秒时间戳），为空表示还没弹过
  int? lastShownAt;

  /// 用户勾过"不再提醒"
  bool muted;

  DonatePromptState({this.lastShownAt, this.muted = false});

  @override
  Map<String, dynamic> getEssentials() => {
    'lastShownAt': lastShownAt,
    'muted': muted,
  };

  factory DonatePromptState.fromJson(Map<String, dynamic> json) =>
      _$DonatePromptStateFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$DonatePromptStateToJson(this);
}
