import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SurveyScannerView extends StatelessWidget {
  const SurveyScannerView({
    super.key,
    required this.controller,
    required this.isFetchingSurvey,
    required this.onSurveyDetected,
    required this.onManualEntry,
    this.statusMessage,
  });

  final MobileScannerController controller;
  final bool isFetchingSurvey;
  final ValueChanged<String> onSurveyDetected;
  final VoidCallback onManualEntry;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '1. Scan du QR code',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Le QR contient un surveyId transmis ensuite à l’API.'),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            clipBehavior: Clip.hardEdge,
            child: MobileScanner(
              controller: controller,
              fit: BoxFit.cover,
              onDetect: (BarcodeCapture capture) {
                final Iterable<Barcode> readable = capture.barcodes.where(
                  (Barcode code) => (code.rawValue ?? '').isNotEmpty,
                );
                if (readable.isEmpty || isFetchingSurvey) {
                  return;
                }
                onSurveyDetected(readable.first.rawValue!.trim());
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onManualEntry,
          icon: const Icon(Icons.keyboard),
          label: const Text('Saisir manuellement un ID'),
        ),
        const SizedBox(height: 8),
        if (statusMessage != null)
          Text(
            statusMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
