import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../shared/models/auth_user.dart';
import '../../shared/models/profile_session.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';

/// `POST /auth/login` result.
class LoginResult {
  const LoginResult({required this.token, required this.user});
  final String token;
  final AuthUser user;
}

/// Auth + Profile endpoints used by the session layer.
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  /// `POST /auth/login`. Body has exactly the documented fields.
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _client.postJson(
      '/auth/login',
      body: {'email': email, 'password': password},
      expectedStatuses: const {200},
      noAuth: true,
    );
    final token = json['token'];
    final user = json['user'];
    if (token is! String || token.isEmpty || user is! Map) {
      throw const UnexpectedApiException('Login response without token/user');
    }
    return LoginResult(
      token: token,
      user: AuthUser.fromJson(user.cast<String, dynamic>()),
    );
  }

  /// `POST /auth/logout`. Safe with an expired token (server answers 200).
  Future<void> logout() async {
    await _client.postJson('/auth/logout', expectedStatuses: const {200});
  }

  /// `GET /me`.
  Future<AuthUser> me() async =>
      AuthUser.fromJson(await _client.getJson('/me'));

  /// `GET /me/sessions`.
  Future<List<ProfileSession>> sessions() async {
    final json = await _client.getJson('/me/sessions');
    final list = (json['sessions'] as List?) ?? const [];
    return list
        .map((e) => ProfileSession.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// `DELETE /me/sessions/{sessionID}`.
  Future<void> endSession(String sessionId) async {
    await _client.deleteJson(
      '/me/sessions/$sessionId',
      expectedStatuses: const {204},
    );
  }

  /// `POST /me/password`: change own password (new one ≥ 10 characters).
  Future<void> changePassword({required String current, required String next}) async {
    await _client.postJson(
      '/me/password',
      body: {'current_password': current, 'new_password': next},
      expectedStatuses: const {200},
    );
  }

  /// `POST /me/avatar` (multipart, field `file`): upload or replace the
  /// profile photo. Returns `avatar_updated_at`.
  Future<DateTime?> uploadAvatar({required String filename, required Uint8List bytes}) async {
    final form = FormData();
    form.files.add(MapEntry('file', MultipartFile.fromBytes(bytes, filename: filename)));
    final res = await _client.send(
      () => _client.dio.post<dynamic>('/me/avatar', data: form),
      expectedStatuses: const {200},
    );
    final json = ApiClient.asJsonObject(res.data, '/me/avatar');
    final at = json['avatar_updated_at'];
    return at is String ? DateTime.tryParse(at) : null;
  }

  /// `DELETE /me/avatar`.
  Future<void> deleteAvatar() async {
    await _client.deleteJson('/me/avatar', expectedStatuses: const {200, 204});
  }

  /// `POST /me/sessions/end-others`.
  Future<int> endOtherSessions() async {
    final json = await _client.postJson(
      '/me/sessions/end-others',
      expectedStatuses: const {200},
    );
    return (json['ended'] as num?)?.toInt() ?? 0;
  }
}
