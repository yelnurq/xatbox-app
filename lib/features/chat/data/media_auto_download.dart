import '../../../core/network/network_status.dart';

/// When chat media previews (image/video thumbnails) and voice notes are
/// fetched without a tap (ТЗ п.24.15). Originals are always downloaded on tap.
enum MediaAutoDownload {
  never,
  wifiOnly,
  always;

  static const fallback = MediaAutoDownload.wifiOnly;

  String get storageValue => switch (this) {
    MediaAutoDownload.never => 'never',
    MediaAutoDownload.wifiOnly => 'wifi',
    MediaAutoDownload.always => 'always',
  };

  static MediaAutoDownload parse(String? v) => switch (v) {
    'never' => MediaAutoDownload.never,
    'always' => MediaAutoDownload.always,
    _ => fallback,
  };

  /// Decision table: nothing without a network; Wi-Fi only means the Wi-Fi
  /// (or Ethernet) interface — mobile and unknown links are treated as metered.
  bool allows(NetworkKind network) => switch (this) {
    MediaAutoDownload.never => false,
    MediaAutoDownload.wifiOnly => network == NetworkKind.wifi,
    MediaAutoDownload.always => network.online,
  };
}

/// Messages kept per conversation in the local cache (Settings).
const chatMessageLimitOptions = [50, 100, 300];
const chatMessageLimitDefault = 100;
