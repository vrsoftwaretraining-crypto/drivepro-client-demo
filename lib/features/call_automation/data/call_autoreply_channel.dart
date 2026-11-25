// Developed by @Ramana Code Softwares

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AutoReplyLogEntry {
  AutoReplyLogEntry(this.id, this.at, this.number, this.kind, this.sms, this.synced);

  factory AutoReplyLogEntry.fromJson(Map<String, dynamic> j) => AutoReplyLogEntry(
        j['id'] as String? ?? '',
        DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
        j['number'] as String? ?? '',
        j['kind'] as String? ?? 'missed',
        j['sms'] as String? ?? '',
        j['synced'] as bool? ?? false,
      );

  final String id;
  final DateTime at;
  final String number;
  final String kind; // missed | answered
  final String sms; // sent | failed: ... | skipped: ...
  final bool synced;
}

/// Bridge to the native Android receiver (see android_native/).
class CallAutoReplyChannel {
  static const _channel = MethodChannel('drivepro/call_autoreply');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<Map<String, dynamic>> getConfig() async => Map<String, dynamic>.from(
      await _channel.invokeMethod<Map<dynamic, dynamic>>('getConfig') ?? {});

  static Future<void> saveConfig(Map<String, dynamic> config) =>
      _channel.invokeMethod('saveConfig', config);

  static Future<Map<String, bool>> permissions() async {
    final m = await _channel.invokeMethod<Map<dynamic, dynamic>>('permissions') ?? {};
    return m.map((k, v) => MapEntry(k as String, v == true));
  }

  static Future<Map<String, bool>> requestPermissions() async {
    final m = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestPermissions') ?? {};
    return m.map((k, v) => MapEntry(k as String, v == true));
  }

  static Future<List<AutoReplyLogEntry>> getLog() async {
    final raw = await _channel.invokeMethod<String>('getLog') ?? '[]';
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => AutoReplyLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> markSynced(List<String> ids) =>
      _channel.invokeMethod('markSynced', ids);

  static Future<void> sendTest(String number) => _channel.invokeMethod('sendTest', number);
}
