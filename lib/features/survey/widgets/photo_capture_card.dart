import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoCaptureCard extends StatelessWidget {
  const PhotoCaptureCard({
    super.key,
    required this.photo,
    required this.photoBytes,
    required this.onCapturePhoto,
  });

  final XFile? photo;
  final Uint8List? photoBytes;
  final Future<void> Function() onCapturePhoto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2. Photo avec consentement',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'La photo sera chiffrée localement (AES-GCM) avant envoi.',
            ),
            const SizedBox(height: 12),
            if (photoBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  photoBytes!,
                  fit: BoxFit.cover,
                  height: 180,
                  width: double.infinity,
                ),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Aucune photo capturée'),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    onCapturePhoto();
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    photo == null ? 'Prendre une photo' : 'Reprendre',
                  ),
                ),
                const SizedBox(width: 12),
                if (photo != null)
                  Expanded(
                    child: Text(photo!.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
