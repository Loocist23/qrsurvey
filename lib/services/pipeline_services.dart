import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/survey_models.dart';

class AuthRepository {
  AuthRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'auth_token';

  Future<String> login({
    String username = 'agent',
    String password = 'demo',
  }) async {
    final String? stored = await _storage.read(key: _tokenKey);
    if (stored != null) {
      return stored;
    }

    // Simule un appel HTTPS avant de stocker le token en sécurisé.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final String token = base64Encode(_randomBytes(32));
    await _storage.write(key: _tokenKey, value: token);
    return token;
  }

  Future<void> logout() => _storage.delete(key: _tokenKey);

  static List<int> _randomBytes(int length) {
    final Random random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

class SurveyRepository {
  SurveyRepository({
    http.Client? client,
    this.baseUrl,
    this.simulateFetch = true,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String? baseUrl;
  final bool simulateFetch;

  Future<Survey> fetchSurvey(String surveyId) async {
    if (simulateFetch || baseUrl == null) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return SurveySamples.fromBase64Sample(surveyId);
    }

    final Uri uri = Uri.parse(
      '${_trimTrailingSlash(baseUrl!)}/survey/$surveyId',
    );
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw SurveyException(
        'Impossible de récupérer le sondage (${response.statusCode}).',
      );
    }
    return Survey.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class SubmissionRepository {
  SubmissionRepository({
    http.Client? client,
    this.baseUrl,
    this.simulateNetwork = true,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String? baseUrl;
  final bool simulateNetwork;

  Future<void> submit(EncryptedSubmission submission) async {
    if (simulateNetwork || baseUrl == null) {
      await Future<void>.delayed(const Duration(seconds: 1));
      return;
    }

    final Uri uri = Uri.parse('${_trimTrailingSlash(baseUrl!)}/answers');
    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${submission.authToken}',
      },
      body: jsonEncode(submission.toJson()),
    );

    if (response.statusCode >= 400) {
      throw SubmissionException(
        'Erreur ${response.statusCode} pendant la soumission.',
      );
    }
  }
}

String _trimTrailingSlash(String value) {
  return value.replaceAll(RegExp(r'/+$'), '');
}

class SurveyException implements Exception {
  SurveyException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SubmissionException implements Exception {
  SubmissionException(this.message);
  final String message;

  @override
  String toString() => message;
}
