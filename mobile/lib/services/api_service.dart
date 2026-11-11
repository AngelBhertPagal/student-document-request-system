import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<void> saveAuthData(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(AppConstants.userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/login/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await saveAuthData(data['token'], data['user']);
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Invalid username or password.');
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
    final response = await http.post(
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
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await saveAuthData(data['token'], data['user']);
      return data;
    } else {
      final firstError = data.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first);
      }
      throw Exception('Registration failed.');
    }
  }

  static Future<List<dynamic>> fetchDocumentTypes() async {
    final url = Uri.parse('${AppConstants.baseUrl}/types/');
    final response = await http.get(url);
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
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('results')) {
        return data['results'];
      }
      return data;
    } else {
      throw Exception('Failed to fetch requests.');
    }
  }

  static Future<Map<String, dynamic>> fetchRequestDetails(int id) async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/requests/$id/');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load request details.');
    }
  }

  static Future<Map<String, dynamic>> createRequest({
    required int documentTypeId,
    required int copies,
    required String purpose,
    required String deliveryMethod,
  }) async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/requests/');
    final response = await http.post(
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
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data.toString());
    }
  }

  static Future<List<dynamic>> fetchNotifications() async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/notifications/');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );

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
    await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
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

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to update request status.');
    }
  }

  static Future<Map<String, dynamic>> fetchStats() async {
    final token = await getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/requests/stats/');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch dashboard stats.');
    }
  }
}
