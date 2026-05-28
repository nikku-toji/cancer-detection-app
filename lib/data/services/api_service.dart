import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  // ---- Token management ----

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ---- Auth ----

  static Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final resp = await http.post(
      Uri.parse('${AppConstants.baseApiUrl}/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    _checkResponse(resp);
    return jsonDecode(resp.body);
  }

  static Future<Map<String, dynamic>> emailLogin(String email, String password) async {
    final resp = await http.post(
      Uri.parse('${AppConstants.baseApiUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkResponse(resp);
    return jsonDecode(resp.body);
  }

  static Future<Map<String, dynamic>> register(
      String email, String password, String name) async {
    final resp = await http.post(
      Uri.parse('${AppConstants.baseApiUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'name': name}),
    );
    _checkResponse(resp);
    return jsonDecode(resp.body);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final resp = await http.get(
      Uri.parse('${AppConstants.baseApiUrl}/auth/me'),
      headers: await _authHeaders(),
    );
    _checkResponse(resp);
    return jsonDecode(resp.body);
  }

  // ---- Scans ----

  static Future<Map<String, dynamic>> getScans({
    int page = 1,
    String? cancerType,
  }) async {
    var url = '${AppConstants.baseApiUrl}/scans?page=$page&limit=20';
    if (cancerType != null) url += '&cancer_type=$cancerType';
    final resp = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );
    _checkResponse(resp);
    return jsonDecode(resp.body);
  }

  static Future<Map<String, dynamic>> getScan(String scanId) async {
    final resp = await http.get(
      Uri.parse('${AppConstants.baseApiUrl}/scans/$scanId'),
      headers: await _authHeaders(),
    );
    _checkResponse(resp);
    return jsonDecode(resp.body);
  }

  static Future<void> deleteScan(String scanId) async {
    final resp = await http.delete(
      Uri.parse('${AppConstants.baseApiUrl}/scans/$scanId'),
      headers: await _authHeaders(),
    );
    _checkResponse(resp);
  }

  // ---- Analytics ----

  static Future<Map<String, dynamic>> getAnalytics() async {
    final resp = await http.get(
      Uri.parse('${AppConstants.baseApiUrl}/analytics/summary'),
      headers: await _authHeaders(),
    );
    _checkResponse(resp);
    return jsonDecode(resp.body);
  }

  static void _checkResponse(http.Response resp) {
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['detail'] ?? 'API error ${resp.statusCode}');
    }
  }
}
