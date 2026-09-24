import '../../../core/api/api_client.dart';
import 'update_models.dart';

/// Release endpoints of the Chat Service (`/app/android/*`).
class UpdateApi {
  UpdateApi(this.client);

  final ApiClient client;

  /// `GET /app/<platform>/latest?abi=&version_code=` (android / windows /
  /// macos / linux); [beta]: `&channel=beta` (desktop «Получать бета-версии»).
  Future<AppRelease> latest({
    required String abi,
    required int versionCode,
    String platform = 'android',
    bool beta = false,
  }) async {
    final json = await client.getJson(
      '/app/$platform/latest',
      query: {'abi': abi, 'version_code': '$versionCode', if (beta) 'channel': 'beta'},
    );
    return AppRelease.fromJson(json);
  }

  /// [AppRelease.downloadPath] is absolute (`/api/v1/app/...`); the client's
  /// base URL already ends with `/api/v1` (possibly behind a path prefix).
  static String relativeDownloadPath(String downloadPath) {
    const prefix = '/api/v1';
    return downloadPath.startsWith(prefix)
        ? downloadPath.substring(prefix.length)
        : downloadPath;
  }
}
