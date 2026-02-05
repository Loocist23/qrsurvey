import 'encrypted_field.dart';

class EncryptedSubmission {
  const EncryptedSubmission({
    required this.surveyId,
    required this.answers,
    this.photo,
    required this.authToken,
  });

  final String surveyId;
  final EncryptedField answers;
  final EncryptedField? photo;
  final String authToken;

  Map<String, dynamic> toJson() => {
        'surveyId': surveyId,
        'answers': answers.toJson(),
        if (photo != null) 'photo': photo!.toJson(),
        'authToken': authToken,
      };
}
