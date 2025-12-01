import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/survey_models.dart';
import 'services/encryption_service.dart';
import 'services/pipeline_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SurveyApp());
}

class SurveyApp extends StatelessWidget {
  const SurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Survey Capture',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const SurveyFlowPage(),
    );
  }
}

class SurveyFlowPage extends StatefulWidget {
  const SurveyFlowPage({super.key});

  @override
  State<SurveyFlowPage> createState() => _SurveyFlowPageState();
}

class _SurveyFlowPageState extends State<SurveyFlowPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final ImagePicker _imagePicker = ImagePicker();
  final SurveyRepository _surveyRepository = SurveyRepository();
  final AuthRepository _authRepository = AuthRepository();
  final SubmissionRepository _submissionRepository = SubmissionRepository();
  final EncryptionService _encryptionService = EncryptionService();

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _choiceAnswers = {};

  String? _authToken;
  String? _statusMessage;
  Survey? _survey;
  String? _scannedSurveyId;
  XFile? _photo;
  Uint8List? _photoBytes;
  EncryptionBundle? _lastBundle;
  bool _isFetchingSurvey = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _ensureCameraPermission();
    final String token = await _authRepository.login();
    if (!mounted) {
      return;
    }
    setState(() {
      _authToken = token;
    });
  }

  Future<void> _ensureCameraPermission() async {
    PermissionStatus status = PermissionStatus.granted;
    try {
      status = await Permission.camera.request();
    } on Exception {
      status = PermissionStatus.granted;
    }
    if (!mounted) {
      return;
    }
    if (!status.isGranted) {
      setState(() {
        _statusMessage =
            'Permission caméra refusée. Active-la pour scanner un QR code.';
      });
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    _scannerController.dispose();
    super.dispose();
  }

  void _disposeControllers() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _choiceAnswers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline QR → Survey'),
        actions: [
          if (_survey != null)
            IconButton(
              tooltip: 'Recommencer le scan',
              onPressed: _resetSurvey,
              icon: const Icon(Icons.qr_code_scanner),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _authToken == null
              ? const Center(child: CircularProgressIndicator())
              : _survey == null
              ? _buildScanner(context)
              : _buildSurveyForm(context),
        ),
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
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
              controller: _scannerController,
              fit: BoxFit.cover,
              onDetect: (BarcodeCapture capture) {
                final Iterable<Barcode> readable = capture.barcodes.where(
                  (Barcode code) => (code.rawValue ?? '').isNotEmpty,
                );
                if (readable.isEmpty || _isFetchingSurvey) {
                  return;
                }
                final String value = readable.first.rawValue!.trim();
                _scannerController.stop();
                _fetchSurvey(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _promptManualSurvey,
          icon: const Icon(Icons.keyboard),
          label: const Text('Saisir manuellement un ID'),
        ),
        const SizedBox(height: 8),
        if (_statusMessage != null)
          Text(
            _statusMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Widget _buildSurveyForm(BuildContext context) {
    final Survey survey = _survey!;
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Text(survey.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(survey.description),
          const SizedBox(height: 12),
          Text(
            'QR: ${_scannedSurveyId ?? '-'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...survey.questions.map(_buildQuestionField),
          const SizedBox(height: 16),
          _buildPhotoCaptureCard(context),
          const SizedBox(height: 16),
          if (_lastBundle != null) _buildEncryptionSummary(context),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _statusMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitForm,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock),
            label: Text(
              _isSubmitting ? 'Chiffrement en cours...' : 'Chiffrer + envoyer',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionField(SurveyQuestion question) {
    switch (question.type) {
      case QuestionType.singleChoice:
        final String? selected = _choiceAnswers[question.id];
        return Padding(
          key: ValueKey<String>('question-${question.id}'),
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: InputDecoration(labelText: question.label),
            items: question.options
                .map(
                  (String option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              setState(() {
                _choiceAnswers[question.id] = value;
              });
            },
            validator: (String? value) {
              if ((question.required ?? false) &&
                  (value == null || value.isEmpty)) {
                return 'Champ requis';
              }
              return null;
            },
          ),
        );
      case QuestionType.number:
      case QuestionType.text:
        final TextEditingController controller = _controllers.putIfAbsent(
          question.id,
          TextEditingController.new,
        );
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

  Widget _buildPhotoCaptureCard(BuildContext context) {
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
            if (_photoBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _photoBytes!,
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
                  onPressed: _capturePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    _photo == null ? 'Prendre une photo' : 'Reprendre',
                  ),
                ),
                const SizedBox(width: 12),
                if (_photo != null)
                  Expanded(
                    child: Text(_photo!.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEncryptionSummary(BuildContext context) {
    final EncryptionBundle bundle = _lastBundle!;
    String preview(String cipherText) {
      final int len = min(18, cipherText.length);
      return '${cipherText.substring(0, len)}…';
    }

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
            SelectableText('Clé AES (base64) : ${preview(bundle.base64Key)}'),
            SelectableText('Réponses : ${preview(bundle.answers.cipherText)}'),
            if (bundle.photo != null)
              SelectableText('Photo : ${preview(bundle.photo!.cipherText)}'),
          ],
        ),
      ),
    );
  }

  void _fetchSurvey(String surveyId) {
    setState(() {
      _isFetchingSurvey = true;
      _statusMessage = 'Chargement du sondage $surveyId…';
    });

    _surveyRepository
        .fetchSurvey(surveyId)
        .then((Survey survey) {
          if (!mounted) {
            return;
          }
          _disposeControllers();
          setState(() {
            _survey = survey;
            _scannedSurveyId = surveyId;
            _statusMessage = null;
          });
        })
        .catchError((Object error) {
          if (!mounted) {
            return;
          }
          _scannerController.start();
          setState(() {
            _statusMessage = 'Erreur: $error';
          });
        })
        .whenComplete(() {
          if (!mounted) {
            return;
          }
          setState(() {
            _isFetchingSurvey = false;
          });
        });
  }

  Future<void> _promptManualSurvey() async {
    final TextEditingController controller = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Saisir un surveyId'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'ex: survey-123'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) {
      _fetchSurvey(value);
    }
  }

  Future<void> _capturePhoto() async {
    PermissionStatus status = PermissionStatus.granted;
    try {
      status = await Permission.camera.request();
    } on Exception {
      status = PermissionStatus.granted;
    }
    if (!status.isGranted) {
      setState(() {
        _statusMessage = 'La caméra est nécessaire pour prendre une photo.';
      });
      return;
    }
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.front,
    );
    if (image == null) {
      return;
    }
    final Uint8List bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _photo = image;
      _photoBytes = bytes;
      _statusMessage = null;
    });
  }

  Future<void> _submitForm() async {
    if (_survey == null || _authToken == null) {
      setState(() {
        _statusMessage = 'Authentification ou sondage manquant.';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final List<SurveyAnswer> answers = _survey!.questions.map((
        SurveyQuestion q,
      ) {
        final String response = q.type == QuestionType.singleChoice
            ? _choiceAnswers[q.id] ?? ''
            : _controllers[q.id]?.text ?? '';
        return SurveyAnswer(questionId: q.id, response: response);
      }).toList();
      final Map<String, dynamic> payload = <String, dynamic>{
        'answers': answers.map((SurveyAnswer a) => a.toJson()).toList(),
        'submittedAt': DateTime.now().toIso8601String(),
      };

      final EncryptionBundle bundle = await _encryptionService
          .encryptSubmission(answers: payload, photoBytes: _photoBytes);

      final EncryptedSubmission submission = EncryptedSubmission(
        surveyId: _survey!.id,
        answers: bundle.answers,
        photo: bundle.photo,
        encryptionKey: bundle.base64Key,
        authToken: _authToken!,
      );

      await _submissionRepository.submit(submission);

      if (!mounted) {
        return;
      }
      setState(() {
        _lastBundle = bundle;
        _statusMessage = 'Données chiffrées et envoyées via HTTPS (simulé).';
      });
    } on SubmissionException catch (error) {
      setState(() {
        _statusMessage = error.message;
      });
    } on Exception catch (error) {
      setState(() {
        _statusMessage = 'Erreur inattendue: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetSurvey() {
    _disposeControllers();
    setState(() {
      _survey = null;
      _scannedSurveyId = null;
      _photo = null;
      _photoBytes = null;
      _lastBundle = null;
      _statusMessage = null;
    });
    _scannerController.start();
  }
}
