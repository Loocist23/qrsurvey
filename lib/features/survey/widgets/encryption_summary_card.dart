import 'dart:math';

import 'package:flutter/material.dart';

import '../../../services/encryption_service.dart';

class EncryptionSummaryCard extends StatelessWidget {
  const EncryptionSummaryCard({super.key, required this.bundle});

  final EncryptionBundle bundle;

  String _preview(String value) {
    final int len = min(18, value.length);
    return '${value.substring(0, len)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3. Chiffrement prêt',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText('Clé AES (base64) : ${_preview(bundle.base64Key)}'),
            SelectableText(
              'Réponses : ${_preview(bundle.answers.cipherText)}',
            ),
            if (bundle.photo != null)
              SelectableText(
                'Photo : ${_preview(bundle.photo!.cipherText)}',
              ),
          ],
        ),
      ),
    );
  }
}
