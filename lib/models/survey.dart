import 'survey_question.dart';

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
