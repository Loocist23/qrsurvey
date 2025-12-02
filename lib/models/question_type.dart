enum QuestionType { text, number, singleChoice }

QuestionType parseQuestionType(String raw) {
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
