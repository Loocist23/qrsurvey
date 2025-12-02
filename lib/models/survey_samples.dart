import 'dart:convert';

import 'survey.dart';

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
