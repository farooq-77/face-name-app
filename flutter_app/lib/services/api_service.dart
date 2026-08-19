import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/recognition_result.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) {
    if (!AppConfig.apiConfigured) {
      throw ApiException('Backend API URL is not configured.');
    }
    final base = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  Future<String> _idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ApiException('Please sign in again.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Could not create authentication token.');
    }
    return token;
  }

  Future<RecognitionResponse> recognize(File image) async {
    final request = http.MultipartRequest('POST', _uri('/v1/recognize'));
    request.headers['Authorization'] = 'Bearer ${await _idToken()}';
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    final response = await http.Response.fromStream(await request.send());
    final body = _decode(response);
    if (response.statusCode != 200) throw _error(response, body);
    return RecognitionResponse.fromJson(body);
  }

  Future<SavedFace> enroll({
    required File image,
    required int faceIndex,
    required String name,
    required String imagePath,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/v1/faces'));
    request.headers['Authorization'] = 'Bearer ${await _idToken()}';
    request.fields['name'] = name.trim();
    request.fields['face_index'] = '$faceIndex';
    request.fields['image_path'] = imagePath;
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    final response = await http.Response.fromStream(await request.send());
    final body = _decode(response);
    if (response.statusCode != 201) throw _error(response, body);
    return SavedFace.fromJson(body);
  }

  Future<List<SavedFace>> listFaces() async {
    final response = await _client.get(
      _uri('/v1/faces'),
      headers: {'Authorization': 'Bearer ${await _idToken()}'},
    );
    final body = _decode(response);
    if (response.statusCode != 200) throw _error(response, body);

    final values = body['faces'] as List<dynamic>? ?? const [];
    return values
        .map((e) => SavedFace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteFace(String id) async {
    final response = await _client.delete(
      _uri('/v1/faces/$id'),
      headers: {'Authorization': 'Bearer ${await _idToken()}'},
    );
    if (response.statusCode != 204) {
      throw _error(response, _decode(response));
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'message': response.body};
    }
  }

  ApiException _error(http.Response response, Map<String, dynamic> body) {
    final detail = body['detail'];
    if (detail is Map<String, dynamic>) {
      return ApiException(
        (detail['message'] ?? 'Request failed').toString(),
        code: detail['code']?.toString(),
        statusCode: response.statusCode,
      );
    }
    return ApiException(
      (body['message'] ?? detail ?? 'Request failed').toString(),
      statusCode: response.statusCode,
    );
  }

  void dispose() => _client.close();
}
