import 'package:crypto/crypto.dart';
import 'dart:convert';

class Announcement {
  final String title;
  final String? date;
  final String group;
  final String? language;
  final String markdown;
  final String? source;

  Announcement({
    required this.title,
    this.date,
    required this.group,
    this.language,
    required this.markdown,
    this.source,
  });

  /// Calculate unique key for this announcement based on essential fields
  String calculateKey() {
    final essentials = {
      'title': title,
      'date': date,
      'group': group,
      'language': language,
      'markdown': markdown,
      'source': source,
    };
    final jsonString = json.encode(essentials);
    final bytes = utf8.encode(jsonString);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      title: json['title'] as String? ?? '',
      date: json['date'] as String?,
      group: json['group'] as String? ?? '',
      language: json['language'] as String?,
      markdown: json['markdown'] as String? ?? '',
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'date': date,
    'group': group,
    'language': language,
    'markdown': markdown,
    'source': source,
  };
}

class ReleaseInfo {
  final String stableVersion;
  final Map<String, Map<String, String>> stableDownloads;
  final String? betaVersion;
  final Map<String, Map<String, String>> betaDownloads;

  ReleaseInfo({
    required this.stableVersion,
    required this.stableDownloads,
    this.betaVersion,
    required this.betaDownloads,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseInfo(
      stableVersion: json['stableVersion'] as String? ?? '',
      stableDownloads: (json['stableDownloads'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>).map(
          (k2, v2) => MapEntry(k2, v2 as String? ?? ''),
        )),
      ) ?? {},
      betaVersion: json['betaVersion'] as String?,
      betaDownloads: (json['betaDownloads'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>).map(
          (k2, v2) => MapEntry(k2, v2 as String? ?? ''),
        )),
      ) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'stableVersion': stableVersion,
    'stableDownloads': stableDownloads,
    'betaVersion': betaVersion,
    'betaDownloads': betaDownloads,
  };
}
