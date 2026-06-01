import '/types/sync.dart';

extension ReleaseInfoExtension on ReleaseInfo {
  String getDisplayPlatformName(String platform) {
    return switch (platform.toLowerCase()) {
      'windows' => 'Windows',
      'macos' => 'macOS',
      'linux' => 'Linux',
      'android' => 'Android',
      'ios' => 'iOS',
      _ => platform,
    };
  }

  String getDisplayDownloadChannelName(String channel) {
    return switch (channel.toLowerCase()) {
      'github' => 'GitHub 仓库',
      'yunpan' => '北科云盘镜像',
      _ => channel,
    };
  }

  String getDisplayDownloadChannelTip(String channel) {
    return switch (channel.toLowerCase()) {
      'github' => '从 GitHub 官方仓库中下载，网络连接可能不稳定',
      'yunpan' => '从北科内网云盘下载，速度快且不消耗校园网流量',
      _ => '',
    };
  }

  bool getIsRecommendedChannel(String channel) {
    return switch (channel.toLowerCase()) {
      'yunpan' => true,
      _ => false,
    };
  }
}
