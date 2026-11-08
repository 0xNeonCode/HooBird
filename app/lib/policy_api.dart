// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:convert';

import 'package:http/http.dart' as http;

class PolicyException implements Exception {
  PolicyException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => message;
}

class PolicyApi {
  PolicyApi(String baseUrl) : base = Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), ''));

  final Uri base;

  Future<Map<String, dynamic>> login(
    String username,
    String password,
    String deviceId,
  ) {
    return _send(
      'POST',
      '/_hoobird/v1/login',
      body: {
        'username': username.trim(),
        'password': password,
        'device_id': deviceId,
        'device_name': 'HooBird',
      },
    );
  }

  Future<Map<String, dynamic>> me(String token) {
    return _send('GET', '/_hoobird/v1/me', token: token);
  }

  Future<Map<String, dynamic>> search(String token, String query) {
    return _send(
      'GET',
      '/_hoobird/v1/directory',
      token: token,
      query: {'q': query.trim()},
    );
  }

  Future<Map<String, dynamic>> childPolicy(String token, String childId) {
    return _send('GET', '/_hoobird/v1/children/$childId', token: token);
  }

  Future<Map<String, dynamic>> approve(
    String token,
    String childId,
    String contactUserId,
  ) {
    return _send(
      'POST',
      '/_hoobird/v1/children/$childId/approvals',
      token: token,
      body: {'contact_user_id': contactUserId},
    );
  }

  Future<Map<String, dynamic>> revokeApproval(
    String token,
    String childId,
    String contactUserId,
  ) {
    return _send(
      'DELETE',
      '/_hoobird/v1/children/$childId/approvals/${Uri.encodeComponent(contactUserId)}',
      token: token,
    );
  }

  Future<Map<String, dynamic>> block(
    String token,
    String childId,
    String contactUserId,
  ) {
    return _send(
      'POST',
      '/_hoobird/v1/children/$childId/blocks',
      token: token,
      body: {'contact_user_id': contactUserId},
    );
  }

  Future<Map<String, dynamic>> liftBlock(
    String token,
    String childId,
    String contactUserId,
  ) {
    return _send(
      'DELETE',
      '/_hoobird/v1/children/$childId/blocks/${Uri.encodeComponent(contactUserId)}',
      token: token,
    );
  }

  Future<Map<String, dynamic>> authorizeDevice(
    String token,
    String childId,
    String deviceId,
  ) {
    return _send(
      'POST',
      '/_hoobird/v1/children/$childId/devices',
      token: token,
      body: {'device_id': deviceId},
    );
  }

  Future<Map<String, dynamic>> revokeDevice(
    String token,
    String childId,
    String deviceId,
  ) {
    return _send(
      'DELETE',
      '/_hoobird/v1/children/$childId/devices/${Uri.encodeComponent(deviceId)}',
      token: token,
    );
  }

  Future<Map<String, dynamic>> linkCode(String token, String childId) {
    return _send(
      'POST',
      '/_hoobird/v1/children/$childId/link-codes',
      token: token,
      body: const {},
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = base.replace(
      path: '${base.path}$path',
      queryParameters: query,
    );
    final headers = <String, String>{'content-type': 'application/json'};
    if (token != null) {
      headers['authorization'] = 'Bearer $token';
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final streamed = await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final detail = decoded is Map ? decoded['detail'] : null;
      final code = detail is Map ? '${detail['hoobird_code'] ?? 'http_${response.statusCode}'}' : 'http_${response.statusCode}';
      final message = detail is Map
          ? '${detail['error'] ?? 'Die Anfrage wurde abgelehnt.'}'
          : 'Die Anfrage wurde abgelehnt (${response.statusCode}).';
      throw PolicyException(response.statusCode, code, message);
    }
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    throw PolicyException(response.statusCode, 'bad_response', 'Unerwartete Antwort.');
  }
}
