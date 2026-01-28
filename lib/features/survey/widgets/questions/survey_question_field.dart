import 'package:flutter/material.dart';

import '../../../../models/survey_models.dart';
import 'binary_choice_field.dart';

typedef ControllerResolver = TextEditingController Function(String questionId);
typedef ChoiceChangeCallback = void Function(String questionId, String? value);

class SurveyQuestionField extends StatelessWidget {
  const SurveyQuestionField({
    super.key,
    required this.question,
    required this.controllerResolver,
    required this.choiceAnswers,
    required this.onChoiceChanged,
  });

  final SurveyQuestion question;
  final ControllerResolver controllerResolver;
  final Map<String, String?> choiceAnswers;
  final ChoiceChangeCallback onChoiceChanged;

  @override
  Widget build(BuildContext context) {
    const String positive = 'Pouce en l\'air';
    const String negative = 'Pouce en bas';
    return Padding(
      key: ValueKey<String>('question-${question.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: BinaryChoiceField(
        label: question.label,
        positiveLabel: positive,
        negativeLabel: negative,
        isRequired: question.required ?? false,
        value: choiceAnswers[question.id],
        showLabels: true,
        onChanged: (String? value) => onChoiceChanged(question.id, value),
      ),
    );
  }
}
