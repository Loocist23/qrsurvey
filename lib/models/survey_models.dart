import 'dart:convert';

enum QuestionType { text, number, singleChoice }

QuestionType _parseQuestionType(String raw) {
  switch (raw.toLowerCase()) {
    case 'number':
      return QuestionType.number;
    case 'choice':
    case 'singlechoice':
      return QuestionType.singleChoice;
    default:
      return QuestionType.text;
  }
}

class SurveyQuestion {
  const SurveyQuestion({
    required this.id,
    required this.label,
    required this.type,
    this.options = const [],
    this.required,
    this.placeholder,
  });

  final String id;
  final String label;
  final QuestionType type;
  final List<String> options;
  final bool? required;
  final String? placeholder;

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    return SurveyQuestion(
      id: json['id'] as String,
      label: json['label'] as String,
      type: _parseQuestionType(json['type'] as String? ?? 'text'),
      options:
          (json['options'] as List<dynamic>?)
              ?.map((dynamic item) => item.toString())
              .toList() ??
          const [],
      required: json['required'] as bool?,
      placeholder: json['placeholder'] as String?,
    );
  }
}

class Survey {
  const Survey({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
  });

  final String id;
  final String title;
  final String description;
  final List<SurveyQuestion> questions;

  factory Survey.fromJson(Map<String, dynamic> json) {
    return Survey(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>)
          .map(
            (dynamic raw) =>
                SurveyQuestion.fromJson(raw as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'questions': questions
        .map(
          (SurveyQuestion q) => {
            'id': q.id,
            'label': q.label,
            'type': q.type.name,
            'options': q.options,
            'required': q.required,
          },
        )
        .toList(),
  };
}

class SurveyAnswer {
  const SurveyAnswer({required this.questionId, required this.response});

  final String questionId;
  final String response;

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'response': response,
  };
}

class EncryptedField {
  const EncryptedField({required this.cipherText, required this.nonce});

  final String cipherText;
  final String nonce;

  Map<String, dynamic> toJson() => {'cipherText': cipherText, 'nonce': nonce};
}

class EncryptedSubmission {
  const EncryptedSubmission({
    required this.surveyId,
    required this.answers,
    this.photo,
    required this.encryptionKey,
    required this.authToken,
  });

  final String surveyId;
  final EncryptedField answers;
  final EncryptedField? photo;
  final String encryptionKey;
  final String authToken;

  Map<String, dynamic> toJson() => {
    'surveyId': surveyId,
    'answers': answers.toJson(),
    if (photo != null) 'photo': photo!.toJson(),
    'encryptionKey': encryptionKey,
    'authToken': authToken,
  };
}

class SurveySamples {
  static Survey fromBase64Sample(String seed) {
    final Map<String, dynamic> data =
        jsonDecode(_sampleData(seed)) as Map<String, dynamic>;
    return Survey.fromJson(data);
  }

  static String _sampleData(String surveyId) {
    return jsonEncode({
      'id': surveyId,
      'title': 'Satisfaction événement',
      'description': 'Merci de répondre rapidement après le scan du QR code.',
      'questions': [
        {
          'id': 'fullname',
          'label': 'Nom complet (optionnel)',
          'type': 'text',
          'required': false,
          'placeholder': 'Alex Martin',
        },
        {
          'id': 'enjoyment',
          'label': "Quel est votre niveau de satisfaction ?",
          'type': 'choice',
          'options': ['Excellent', 'Bien', 'Moyen', 'Mauvais'],
          'required': true,
        },
        {
          'id': 'comment',
          'label': 'Un commentaire rapide',
          'type': 'text',
          'required': false,
          'placeholder': 'Ce que vous avez préféré...',
        },
      ],
    });
  }
}
