import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

class ApiService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 15);

  /// Registered in main.dart to redirect back to LoginScreen on HTTP 401.
  static VoidCallback? onSessionExpired;

  static Future<String?> getToken() async {
    return _secureStorage.read(key: AppConstants.tokenKey);
  }

  static Future<void> saveAuthData(String token, Map<String, dynamic> user) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
    await _secureStorage.write(key: AppConstants.userKey, value: jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final userStr = await _secureStorage.read(key: AppConstants.userKey);
    if (userStr != null) {
      return jsonDecode(userStr) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearLocalSession() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.userKey);
  }

  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        final url = Uri.parse('${AppConstants.baseUrl}/auth/logout/');
        await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Token $token',
              },
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Best-effort server token revocation; always clear local credentials.
    } finally {
      await clearLocalSession();
    }
  }

  static Future<http.Response> _executeRequest(Future<http.Response> Function() requestFn) async {
    try {
      return await requestFn().timeout(_timeout);
    } on SocketException {
      throw Exception('You are offline or the server is unreachable. Please check your connection and try again.');
    } on TimeoutException {
      throw Exception('Connection timed out. Please check your internet connection and try again.');
    } on http.ClientException {
      throw Exception('Unable to connect to the server. Please verify your network connection.');
    }
  }

  static Future<void> _handleUnauthorized(http.Response response) async {
    if (response.statusCode == 401) {
      await clearLocalSession();
      onSessionExpired?.call();
      throw Exception('Your session has expired. Please sign in again.');
    }
  }

  static String _extractErrorMessage(String body, String fallback) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        if (data.containsKey('detail')) return data['detail'].toString();
        if (data.values.isNotEmpty) {
          final first = data.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
          return first.toString();
        }
      }
    } catch (_) {}
    return fallback;
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/login/');
    final response = await _executeRequest(
      () => http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await saveAuthData(data['token'], data['user']);
      return data;
    } else {
      throw Exception(_extractErrorMessage(response.body, 'Invalid username or password.'));
    }
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
    required String studentId,
    required String course,
    required int yearLevel,
    required String contactNumber,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/register/');
    final response = await _executeRequest(
      () => http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'student_id': studentId,
          'course': course,
          'year_level': yearLevel,
          'contact_number': contactNumber,
        }),
      ),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await saveAuthData(data['token'], data['user']);
      return data;
    } else {
      throw Exception(_extractErrorMessage(response.body, 'Registration failed.'));
    }
  }

  static Future<List<dynamic>> fetchDocumentTypes() async {
    final url = Uri.parse('${AppConstants.baseUrl}/types/');
    final response = await _executeRequest(() => http.get(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('results')) {
        return data['results'];
      }
      return data;
    } else {
      throw Exception('Failed to load document types.');
    }
  }

  static Future<List<dynamic>> fetchMyRequests({String? statusFilter}) async {
    final token = await getToken();
    var uriString = '${AppConstants.baseUrl}/requests/';
    if (statusFilter != null && statusFilter.isNotEmpty) {
      uriString += '?status=$statusFilter';
    }
    final url = Uri.parse(uriString);
    final response = await _executeRequest(
      () => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      ),
    );

    await _handleUnauthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('results')) {
        return data['results'];
      }
      return data;
    } else {
      throw Exception(_extractErrorMessage(response.body, 'Failed to fetch requests.'));
    }
  }

  static Future<Map<String, dynamic>> fetchRequestDetails(int id) async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/requests/$id/');
    final response = await _executeRequest(
      () => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      ),
    );

    await _handleUnauthorized(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(_extractErrorMessage(response.body, 'Failed to load request details.'));
    }
  }

  static Future<Map<String, dynamic>> createRequest({
    required int documentTypeId,
    required int copies,
    required String purpose,
    required String deliveryMethod,
    String? attachmentPath,
  }) async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/requests/');

    http.Response response;
    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      response = await _executeRequest(() async {
        final request = http.MultipartRequest('POST', url);
        request.headers['Authorization'] = 'Token $token';
        request.fields['document_type'] = documentTypeId.toString();
        request.fields['copies'] = copies.toString();
        request.fields['purpose'] = purpose;
        request.fields['delivery_method'] = deliveryMethod;
        request.files.add(await http.MultipartFile.fromPath('attachment', attachmentPath));
        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      });
    } else {
      response = await _executeRequest(
        () => http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $token',
          },
          body: jsonEncode({
            'document_type': documentTypeId,
            'copies': copies,
            'purpose': purpose,
            'delivery_method': deliveryMethod,
          }),
        ),
      );
    }

    await _handleUnauthorized(response);

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(_extractErrorMessage(response.body, 'Failed to submit document request.'));
    }
  }

  static Future<List<dynamic>> fetchNotifications() async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/notifications/');
    final response = await _executeRequest(
      () => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      ),
    );

    await _handleUnauthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('results')) {
        return data['results'];
      }
      return data;
    } else {
      throw Exception('Failed to load notifications.');
    }
  }

  static Future<void> markNotificationRead(int id) async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/notifications/$id/mark_as_read/');
    final response = await _executeRequest(
      () => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      ),
    );
    await _handleUnauthorized(response);
  }

  static Future<Map<String, dynamic>> updateRequestStatus({
    required int requestId,
    required String newStatus,
    String remarks = '',
    String rejectionReason = '',
    String? deliveryMethod,
    String? recipientName,
    String? releaseNotes,
  }) async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/requests/$requestId/update-status/');
    final body = <String, dynamic>{
      'status': newStatus,
      'remarks': remarks,
      'rejection_reason': rejectionReason,
    };
    if (deliveryMethod != null) body['delivery_method'] = deliveryMethod;
    if (recipientName != null) body['recipient_name'] = recipientName;
    if (releaseNotes != null) body['release_notes'] = releaseNotes;

    final response = await _executeRequest(
      () => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode(body),
      ),
    );

    await _handleUnauthorized(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(_extractErrorMessage(response.body, 'Failed to update request status.'));
    }
  }

  static Future<Map<String, dynamic>> fetchStats() async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/requests/stats/');
    final response = await _executeRequest(
      () => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      ),
    );

    await _handleUnauthorized(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch dashboard stats.');
    }
  }
}
