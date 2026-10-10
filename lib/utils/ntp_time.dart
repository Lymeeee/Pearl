import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// SNTP 校时（UDP 123），校园网不通时退回 HTTP Date 头兜底。
/// now() 返回校准后的本地时间，未校准时即本地时钟。
class NtpTime {
  NtpTime._();

  static DateTime? _serverTime;
  static DateTime? _localTimeAtSync;
  static String? _sourceType;
  static String? _sourceHost;
  static bool _syncing = false;

  static bool get isSynced => _serverTime != null;
  static bool get isSyncing => _syncing;
  static String? get sourceType => _sourceType; // NTP / HTTP
  static String? get sourceHost => _sourceHost;

  /// 校准后的当前时间
  static DateTime now() {
    final server = _serverTime;
    final localAtSync = _localTimeAtSync;
    if (server == null || localAtSync == null) return DateTime.now();
    return server.add(DateTime.now().difference(localAtSync));
  }

  /// 依次尝试 SNTP 主机与 HTTP Date 源；全部失败返回 false（继续用本地时钟）
  static Future<bool> sync({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_syncing) return isSynced;
    _syncing = true;
    try {
      for (final host in const [
        // 校内时间服务器优先：它就是"发令枪"的钟，校内网络下也最可能可达
        'time.ustb.edu.cn',
        'ntp.aliyun.com',
        'time.apple.com',
        'pool.ntp.org',
      ]) {
        try {
          final serverUtc = await _querySntp(host, timeout);
          _record(serverUtc, 'NTP', host);
          return true;
        } catch (_) {
          // 换下一个主机
        }
      }

      for (final url in const [
        'https://www.baidu.com',
        'https://www.apple.com',
      ]) {
        try {
          final serverUtc = await _queryHttpDate(url, timeout);
          if (serverUtc != null) {
            _record(serverUtc, 'HTTP', Uri.parse(url).host);
            return true;
          }
        } catch (_) {
          // 换下一个源
        }
      }
      return false;
    } finally {
      _syncing = false;
    }
  }

  static void _record(DateTime serverUtc, String type, String host) {
    _serverTime = serverUtc.toLocal();
    _localTimeAtSync = DateTime.now();
    _sourceType = type;
    _sourceHost = host;
  }

  static Future<DateTime> _querySntp(String host, Duration timeout) async {
    final addresses = await InternetAddress.lookup(host);
    if (addresses.isEmpty) {
      throw const SocketException('No address resolved');
    }

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      final packet = Uint8List(48);
      packet[0] = 0x1B; // LI=0, VN=3, Mode=3（客户端）
      final t1 = DateTime.now().toUtc();
      _writeTimestamp(packet, 40, t1);
      socket.send(packet, addresses.first, 123);

      final completer = Completer<DateTime>();
      late final StreamSubscription<RawSocketEvent> subscription;
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null || datagram.data.length < 48) return;
        final t4 = DateTime.now().toUtc();
        final t2 = _readTimestamp(datagram.data, 32);
        final t3 = _readTimestamp(datagram.data, 40);
        // 往返延迟修正：server = t3 + (t4 - t1 - (t3 - t2)) / 2
        final rtt = t4.difference(t1) - t3.difference(t2);
        final corrected = t3.add(
          Duration(microseconds: rtt.inMicroseconds ~/ 2),
        );
        if (!completer.isCompleted) completer.complete(corrected);
      });

      try {
        return await completer.future.timeout(timeout);
      } finally {
        await subscription.cancel();
      }
    } finally {
      socket.close();
    }
  }

  static Future<DateTime?> _queryHttpDate(String url, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final dateHeader = response.headers.value(HttpHeaders.dateHeader);
      await response.drain<void>();
      if (dateHeader == null) return null;
      return HttpDate.parse(dateHeader).toUtc();
    } finally {
      client.close(force: true);
    }
  }

  /// NTP 时间戳：自 1900-01-01 UTC 起的秒数（16.16 定点）
  static const int _ntpEpochOffsetSeconds = 2208988800;

  static DateTime _readTimestamp(Uint8List data, int offset) {
    final byteData = ByteData.sublistView(data, offset, offset + 8);
    final seconds = byteData.getUint32(0);
    final fraction = byteData.getUint32(4);
    if (seconds == 0 && fraction == 0) {
      throw const FormatException('Zero NTP timestamp');
    }
    final milliseconds =
        (seconds - _ntpEpochOffsetSeconds) * 1000 + ((fraction * 1000) >> 32);
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  static void _writeTimestamp(Uint8List data, int offset, DateTime utc) {
    final byteData = ByteData.sublistView(data, offset, offset + 8);
    final milliseconds = utc.millisecondsSinceEpoch;
    final seconds = milliseconds ~/ 1000 + _ntpEpochOffsetSeconds;
    final fraction = ((milliseconds % 1000) / 1000 * (1 << 32)).round();
    byteData.setUint32(0, seconds);
    byteData.setUint32(4, fraction);
  }
}
