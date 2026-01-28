import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../models/survey_models.dart';
import '../../../services/encryption_service.dart';
import '../../../models/auth_session.dart';
import '../../../services/api_config.dart';
import '../../../services/pipeline_services.dart';
import '../widgets/survey_form_view.dart';
import '../widgets/survey_scanner_view.dart';

class SurveyFlowPage extends StatefulWidget {
  const SurveyFlowPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<SurveyFlowPage> createState() => _SurveyFlowPageState();
}

class _SurveyFlowPageState extends State<SurveyFlowPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final ImagePicker _imagePicker = ImagePicker();
  late final SurveyRepository _surveyRepository;
  late final SubmissionRepository _submissionRepository;
  late final EncryptionService _encryptionService;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _choiceAnswers = {};

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
    _surveyRepository = SurveyRepository(
      baseUrl: ApiConfig.baseUrl,
      authToken: widget.session.accessToken,
      simulateFetch: false,
    );
    _submissionRepository = SubmissionRepository(
      baseUrl: ApiConfig.baseUrl,
      authToken: widget.session.accessToken,
      simulateNetwork: false,
    );
    _encryptionService = EncryptionService();
    _ensureCameraPermission();
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

  TextEditingController _controllerFor(String questionId) {
    return _controllers.putIfAbsent(
      questionId,
      TextEditingController.new,
    );
  }

  void _setChoiceAnswer(String questionId, String? value) {
    setState(() {
      _choiceAnswers[questionId] = value;
    });
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
          child: _survey == null
              ? SurveyScannerView(
                  controller: _scannerController,
                  isFetchingSurvey: _isFetchingSurvey,
                  statusMessage: _statusMessage,
                  onManualEntry: _promptManualSurvey,
                  onSurveyDetected: _handleSurveyDetected,
                )
              : SurveyFormView(
                  formKey: _formKey,
                  survey: _survey!,
                  scannedSurveyId: _scannedSurveyId,
                  controllerFor: _controllerFor,
                  choiceAnswers: _choiceAnswers,
                  onChoiceChanged: _setChoiceAnswer,
                  photo: _photo,
                  photoBytes: _photoBytes,
                  onCapturePhoto: _capturePhoto,
                  lastBundle: _lastBundle,
                  statusMessage: _statusMessage,
                  onSubmit: _submitForm,
                  isSubmitting: _isSubmitting,
                ),
        ),
      ),
    );
  }

  void _handleSurveyDetected(String rawValue) {
    _scannerController.stop();
    _fetchSurvey(rawValue);
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
    if (_survey == null) {
      setState(() {
        _statusMessage = 'Sondage manquant.';
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
        authToken: widget.session.accessToken,
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
