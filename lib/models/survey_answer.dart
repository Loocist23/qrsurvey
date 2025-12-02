class SurveyAnswer {
  const SurveyAnswer({required this.questionId, required this.response});

  final String questionId;
  final String response;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'response': response,
      };
}
