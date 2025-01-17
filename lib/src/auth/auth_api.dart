import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk/src/auth/access_token_store.dart';
import 'package:kakao_flutter_sdk/src/auth/model/access_token_response.dart';
import 'package:kakao_flutter_sdk/src/common/api_factory.dart';
import 'package:kakao_flutter_sdk/src/common/kakao_context.dart';
import 'package:platform/platform.dart';

/// Provides Kakao OAuth API.
class AuthApi {
  AuthApi({Dio? dio, Platform? platform, AccessTokenStore? tokenStore})
      : _dio = dio ?? ApiFactory.kauthApi,
        _platform = platform ?? LocalPlatform(),
        _tokenStore = tokenStore ?? AccessTokenStore.instance;

  final Dio _dio;
  final Platform _platform;
  final AccessTokenStore _tokenStore;

  /// Default instance SDK provides.
  static final AuthApi instance = AuthApi();

  /// Check OAuthToken is issued.
  Future<bool> hasToken() async {
    final token = await _tokenStore.fromStore();
    return token.accessToken != null && token.refreshToken != null;
  }

  /// Issues an access token from authCode acquired from [AuthCodeClient].
  Future<AccessTokenResponse> issueAccessToken(String authCode,
      {String? redirectUri, String? clientId}) async {
    final data = {
      "code": authCode,
      "grant_type": "authorization_code",
      "client_id": clientId ?? KakaoContext.platformClientId,
      "redirect_uri": redirectUri ?? await _platformRedirectUri(),
      ...await _platformData()
    };
    return await _issueAccessToken(data);
  }

  /// Issues a new access token from the given refresh token.
  ///
  /// Refresh tokens are usually retrieved from [AccessTokenStore].
  Future<AccessTokenResponse> refreshAccessToken(String refreshToken,
      {String? redirectUri, String? clientId}) async {
    final data = {
      "refresh_token": refreshToken,
      "grant_type": "refresh_token",
      "client_id": clientId ?? KakaoContext.platformClientId,
      "redirect_uri": redirectUri ?? await _platformRedirectUri(),
      ...await _platformData()
    };
    return await _issueAccessToken(data);
  }

  /// Issues temporary agt (access token-generated token), which can be used to acquire auth code.
  Future<String> agt({String? clientId, String? accessToken}) async {
    final tokenInfo = await _tokenStore.fromStore();
    final data = {
      "client_id": clientId ?? KakaoContext.platformClientId,
      "access_token": accessToken ?? tokenInfo.accessToken
    };

    return await ApiFactory.handleApiError(() async {
      final response = await _dio.post("/api/agt", data: data);
      return response.data["agt"];
    });
  }

  Future<AccessTokenResponse> _issueAccessToken(data) async {
    return await ApiFactory.handleApiError(() async {
      Response response = await _dio.post("/oauth/token", data: data);
      return AccessTokenResponse.fromJson(response.data);
    });
  }

  Future<Map<String, String>> _platformData() async {
    final origin = await KakaoContext.origin;
    if (kIsWeb) return {"client_origin": origin};
    return _platform.isAndroid
        ? {"android_key_hash": origin}
        : _platform.isIOS
            ? {"ios_bundle_id": origin}
            : {};
  }

  Future<String> _platformRedirectUri() async {
    if (kIsWeb) return await KakaoContext.origin;
    return "kakao${KakaoContext.clientId}://oauth";
  }
}
