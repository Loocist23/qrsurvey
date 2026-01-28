import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/survey_models.dart';
import 'api_config.dart';

class AuthRepository {
  AuthRepository({
    FlutterSecureStorage? storage,
    http.Client? client,
    this.baseUrl = ApiConfig.baseUrl,
    this.loginPath = ApiConfig.authLoginPath,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client();

  final FlutterSecureStorage _storage;
  final http.Client _client;
  final String baseUrl;
  final String loginPath;

  static const String _sessionKey = 'auth_session';

  Future<AuthSession?> loadSession() async {
    final String? stored = await _storage.read(key: _sessionKey);
    if (stored == null) {
      return null;
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(stored) as Map<String, dynamic>;
      return AuthSession.fromJson(json);
    } on Exception {
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final Uri uri = Uri.parse(
      '${_trimTrailingSlash(baseUrl)}/${_trimLeadingSlash(loginPath)}',
    );
    final http.Response response = await _client.post(
      uri,
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'username': username,
        'password': password,
      }),
    );
    if (response.statusCode >= 400) {
      throw AuthException(
        'Erreur ${response.statusCode} pendant la connexion.',
      );
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final AuthSession session = AuthSession.fromJson(json);
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
    return session;
  }

  Future<void> logout() => _storage.delete(key: _sessionKey);
}

class SurveyRepository {
  SurveyRepository({
    http.Client? client,
    this.baseUrl,
    this.authToken,
    this.simulateFetch = true,
    this.questionPath = ApiConfig.questionPath,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String? baseUrl;
  final String? authToken;
  final bool simulateFetch;
  final String questionPath;

  Future<Survey> fetchSurvey(String surveyId) async {
    if (simulateFetch || baseUrl == null) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return SurveySamples.fromBase64Sample(surveyId);
    }

    final Uri uri = Uri.parse(
      '${_trimTrailingSlash(baseUrl!)}/${_trimLeadingSlash(questionPath)}/$surveyId',
    );
    final http.Response response = await _client.get(
      uri,
      headers: _authHeaders(token: authToken),
    );
    if (response.statusCode != 200) {
      throw SurveyException(
        'Impossible de récupérer le sondage (${response.statusCode}).',
      );
    }
    final dynamic payload = jsonDecode(response.body);
    if (payload is List) {
      return _surveyFromQuestionList(surveyId, payload);
    }
    return Survey.fromJson(payload as Map<String, dynamic>);
  }
}

class SubmissionRepository {
  SubmissionRepository({
    http.Client? client,
    this.baseUrl,
    this.authToken,
    this.simulateNetwork = true,
    this.answersPath = ApiConfig.answersPath,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String? baseUrl;
  final String? authToken;
  final bool simulateNetwork;
  final String answersPath;

  Future<void> submit(EncryptedSubmission submission) async {
    if (simulateNetwork || baseUrl == null) {
      await Future<void>.delayed(const Duration(seconds: 1));
      return;
    }

    final Uri uri = Uri.parse(
      '${_trimTrailingSlash(baseUrl!)}/${_trimLeadingSlash(answersPath)}',
    );
    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        ..._authHeaders(token: authToken ?? submission.authToken),
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

String _trimLeadingSlash(String value) {
  return value.replaceAll(RegExp(r'^/+'), '');
}

Survey _surveyFromQuestionList(String surveyId, List<dynamic> raw) {
  if (raw.isEmpty) {
    throw SurveyException('Aucune question trouvée pour $surveyId.');
  }
  final List<SurveyQuestion> questions = raw
      .map((dynamic item) {
        final Map<String, dynamic> json = item as Map<String, dynamic>;
        final String id = json['id']?.toString() ?? surveyId;
        final String label =
            (json['content'] ?? json['label'] ?? 'Question $id').toString();
        return SurveyQuestion(
          id: id,
          label: label,
          type: QuestionType.text,
        );
      })
      .toList();

  final String title = questions.length == 1
      ? 'Question $surveyId'
      : 'Questions ($surveyId)';
  return Survey(
    id: surveyId,
    title: title,
    description: '',
    questions: questions,
  );
}

class SurveyException implements Exception {
  SurveyException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthException implements Exception {
  AuthException(this.message);
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

Map<String, String> _authHeaders({String? token}) {
  if (token == null || token.isEmpty) {
    return const <String, String>{};
  }
  return <String, String>{'Authorization': 'Bearer $token'};
}
