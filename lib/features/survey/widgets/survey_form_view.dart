import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/survey_models.dart';
import '../../../services/encryption_service.dart';
import 'encryption_summary_card.dart';
import 'photo_capture_card.dart';
import 'questions/survey_question_field.dart';

class SurveyFormView extends StatelessWidget {
  const SurveyFormView({
    super.key,
    required this.formKey,
    required this.survey,
    required this.scannedSurveyId,
    required this.controllerFor,
    required this.choiceAnswers,
    required this.onChoiceChanged,
    required this.photo,
    required this.photoBytes,
    required this.onCapturePhoto,
    required this.lastBundle,
    required this.statusMessage,
    required this.onSubmit,
    required this.isSubmitting,
  });

  final GlobalKey<FormState> formKey;
  final Survey survey;
  final String? scannedSurveyId;
  final ControllerResolver controllerFor;
  final Map<String, String?> choiceAnswers;
  final ChoiceChangeCallback onChoiceChanged;
  final XFile? photo;
  final Uint8List? photoBytes;
  final Future<void> Function() onCapturePhoto;
  final EncryptionBundle? lastBundle;
  final String? statusMessage;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        children: [
          Text(survey.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(survey.description),
          const SizedBox(height: 12),
          Text(
            'Identifiant de question: ${scannedSurveyId ?? '-'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...survey.questions.map(
            (SurveyQuestion question) => SurveyQuestionField(
              question: question,
              controllerResolver: controllerFor,
              choiceAnswers: choiceAnswers,
              onChoiceChanged: onChoiceChanged,
            ),
          ),
          const SizedBox(height: 16),
          PhotoCaptureCard(
            photo: photo,
            photoBytes: photoBytes,
            onCapturePhoto: onCapturePhoto,
          ),
          const SizedBox(height: 16),
          if (lastBundle != null) EncryptionSummaryCard(bundle: lastBundle!),
          if (statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                statusMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock),
            label: Text(
              isSubmitting ? 'Chiffrement en cours...' : 'Chiffrer + envoyer',
            ),
          ),
        ],
      ),
    );
  }
}
