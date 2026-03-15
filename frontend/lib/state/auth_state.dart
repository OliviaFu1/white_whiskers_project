import 'package:flutter/material.dart';
import 'package:frontend/services/auth_api.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/token_store.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthState extends ValueNotifier<bool> {
  static final AuthState instance = AuthState._();
  AuthState._() : super(false);

  Future<void> logout() async {
    await TokenStore.clear();
    await PetStore.clear();
    value = false;
  }

  void login() => value = true;
  Future<void> initialize() async {
    final access = await TokenStore.readAccess();

    if (access == null) {
      logout();
      return;
    }

    final isExpired = JwtDecoder.isExpired(access);

    if (!isExpired) {
      login();
      return;
    }

    final refresh = await AuthApi().refreshAccessToken();
    if (refresh != null) {
      login();
    } else {
      await TokenStore.clear();
      logout();
    }
  }
}
