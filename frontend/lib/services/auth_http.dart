import 'package:frontend/services/auth_api.dart';
import 'package:frontend/services/token_store.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:http/http.dart' as http;

class AuthHttp {
  final AuthApi authApi;

  AuthHttp(this.authApi);

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(String token) request,
  ) async {
    String? accessToken = await TokenStore.readAccess();

    if (accessToken == null) {
      throw Exception("No access token");
    }

    var response = await request(accessToken);

    if (response.statusCode == 401) {
      final newAccess = await authApi.refreshAccessToken();

      if (newAccess == null) {
        await TokenStore.clear();
        AuthState.instance.logout();
        return response;
      }

      response = await request(newAccess);
    }

    return response;
  }

  Future<http.Response> get(Uri uri) {
    return _authorizedRequest(
      (token) => http.get(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ),
    );
  }

  Future<http.Response> post(Uri uri, {Object? body}) {
    return _authorizedRequest(
      (token) => http.post(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: body,
      ),
    );
  }

  Future<http.Response> patch(Uri uri, {Object? body}) {
    return _authorizedRequest(
      (token) => http.patch(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: body,
      ),
    );
  }
}
