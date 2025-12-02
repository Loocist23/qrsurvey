import 'question_type.dart';

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
      type: parseQuestionType(json['type'] as String? ?? 'text'),
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
