class SurveyAnswer {
  const SurveyAnswer({
    required this.id,
    required this.content,
    required this.answer,
  });

  final Object id;
  final String content;
  final Object? answer;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'answer': answer,
      };
}
