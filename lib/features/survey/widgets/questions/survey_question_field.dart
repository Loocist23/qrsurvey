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
    switch (question.type) {
      case QuestionType.singleChoice:
        final String positive =
            question.options.isNotEmpty ? question.options.first : 'Pouce en l\'air';
        final String negative = question.options.length > 1
            ? question.options.last
            : 'Pouce en bas';
        return Padding(
          key: ValueKey<String>('question-${question.id}'),
          padding: const EdgeInsets.only(bottom: 12),
          child: BinaryChoiceField(
            label: question.label,
            positiveLabel: positive,
            negativeLabel: negative,
            isRequired: question.required ?? false,
            value: choiceAnswers[question.id],
            onChanged: (String? value) => onChoiceChanged(question.id, value),
          ),
        );
      case QuestionType.number:
      case QuestionType.text:
        final TextEditingController controller =
            controllerResolver(question.id);
        return Padding(
          key: ValueKey<String>('question-${question.id}'),
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: question.label,
              hintText: question.placeholder,
            ),
            keyboardType: question.type == QuestionType.number
                ? TextInputType.number
                : TextInputType.text,
            validator: (String? value) {
              if ((question.required ?? false) &&
                  (value == null || value.isEmpty)) {
                return 'Champ requis';
              }
              return null;
            },
          ),
        );
    }
  }
}
