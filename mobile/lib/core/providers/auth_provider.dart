import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../../features/auth/domain/auth_models.dart';

// ── 当前用户状态 ───────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
  (ref) => AuthNotifier(ref),
);

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  Future<void> _init() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        state = const AsyncValue.data(null);
        return;
      }
      await fetchMe();
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> fetchMe() async {
    try {
      final resp = await _ref.read(apiClientProvider).get(ApiEndpoints.me);
      state = AsyncValue.data(UserModel.fromJson(resp['data']));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AsyncValue.data(null);
  }

  UserModel? get currentUser {
    return state.whenOrNull(data: (u) => u);
  }
}

// ── isLoggedIn 便捷 provider ─────────────────────────────────

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).whenOrNull(data: (u) => u != null) ?? false;
});
