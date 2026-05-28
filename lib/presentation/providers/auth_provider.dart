import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';

final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    String? error,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        user: user ?? this.user,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await ApiService.getToken();
      if (token != null) {
        final user = await ApiService.getMe();
        state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
        return;
      }
    } catch (_) {
      await ApiService.clearToken();
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('No ID token received');

      final result = await ApiService.googleLogin(idToken);
      await ApiService.saveToken(result['access_token']);
      state = state.copyWith(
        isLoading: false, isAuthenticated: true, user: result['user']);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await ApiService.emailLogin(email, password);
      await ApiService.saveToken(result['access_token']);
      state = state.copyWith(
        isLoading: false, isAuthenticated: true, user: result['user']);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register(String email, String password, String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await ApiService.register(email, password, name);
      await ApiService.saveToken(result['access_token']);
      state = state.copyWith(
        isLoading: false, isAuthenticated: true, user: result['user']);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await ApiService.clearToken();
    await _googleSignIn.signOut();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier());
