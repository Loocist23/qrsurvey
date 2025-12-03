# Guide de modification de QRCodeQuizz

Ce document complète `docs/architecture.md` et répond précisément à « quel fichier modifier pour faire évoluer telle étape du parcours QR → sondage → chiffrement ? ». Chaque section cite les classes/méthodes à toucher et l’ordre exact des actions.

## Carte rapide de l’arborescence

| Zone | Pour modifier… | Chemins clés |
| --- | --- | --- |
| Entrée / thème | Point de départ Flutter, Material 3, navigation vers le flow | `lib/main.dart`, `lib/app.dart` |
| Parcours utilisateur | État global, permissions, appels services, enchaînement des vues | `lib/features/survey/pages/survey_flow_page.dart` |
| Widgets UI | Scanner (`MobileScanner`), formulaire dynamique, carte photo, résumé de chiffrement | `lib/features/survey/widgets/**` |
| Modèles de données | Questions, sondages, réponses, payload chiffré, mocks | `lib/models/**/*.dart` |
| Services | Auth/token, fetch sondage, envoi, chiffrement AES‑GCM | `lib/services/pipeline_services.dart`, `lib/services/encryption_service.dart` |
| Docs | Vue d’ensemble, présent guide | `docs/architecture.md`, `docs/guide_modifications.md` |

## Flux complet et points d’entrée

| Étape | Ce qui se passe | Fichiers/méthodes à modifier |
| --- | --- | --- |
| 0. Boot | `main()` appelle `SurveyApp` (Material 3, thème) | `lib/main.dart`, `lib/app.dart:8-20` |
| 1. Auth + permissions | `_initialize` demande la caméra (`_ensureCameraPermission`) puis `AuthRepository.login` et stocke `_authToken` | `survey_flow_page.dart:47-86`, `pipeline_services.dart:13-42` |
| 2. Scan / saisie ID | `SurveyScannerView` écoute `MobileScanner` et renvoie `rawValue` à `_handleSurveyDetected` | `survey_scanner_view.dart:8-60`, `survey_flow_page.dart:100-116` |
| 3. Fetch sondage | `_fetchSurvey` appelle `SurveyRepository.fetchSurvey` puis instancie les `TextEditingController` | `survey_flow_page.dart:118-167`, `pipeline_services.dart:44-82` |
| 4. Formulaire dynamique | `SurveyFormView` rend chaque `SurveyQuestion` via `SurveyQuestionField` | `survey_form_view.dart:22-82`, `survey_question_field.dart:15-70` |
| 5. Capture photo | `_capturePhoto` vérifie la permission caméra, ouvre `image_picker`, stocke `_photoBytes` | `survey_flow_page.dart:169-215`, `photo_capture_card.dart:10-70` |
| 6. Chiffrement + soumission | `_submitForm` assemble `SurveyAnswer`, appelle `EncryptionService.encryptSubmission`, puis `SubmissionRepository.submit` | `survey_flow_page.dart:217-296`, `encryption_service.dart:11-74`, `pipeline_services.dart:84-134` |
| 7. Reset | `_resetSurvey` vide `controllers`, relance le scanner | `survey_flow_page.dart:298-312` |

Utilisez cette table comme check-list : quand vous modifiez une étape, assurez-vous de couvrir à la fois la partie UI (widgets) et la partie service/modèle correspondante.

## Scénarios de modification précis

### 1. Personnaliser l’expérience utilisateur

1. **Thème global / navigation**
   - Ouvrez `lib/app.dart`.
   - Ajustez `MaterialApp` (`title`, `theme`, `darkTheme`, `routes`, etc.).
   - Pour intercaler un onboarding avant le flow, remplacez `home: const SurveyFlowPage()` par votre widget et naviguez ensuite vers `SurveyFlowPage`.
2. **Scanner & saisie manuelle**
   - Le `MobileScannerController` est créé dans `SurveyFlowPage` (`_scannerController` ligne 20). Changez `formats`, activez `torchEnabled`, etc.
   - L’UI du scanner est dans `lib/features/survey/widgets/survey_scanner_view.dart`. Pour ajouter une aide visuelle (overlay, instructions), modifiez le `Card` central ou ajoutez des boutons sous `OutlinedButton.icon`.
   - La saisie manuelle se trouve dans `_promptManualSurvey` (`survey_flow_page.dart:133`). Ajoutez validation, hints ou un bouton scan test ici.
3. **Messages d’état / transitions**
   - `_statusMessage`, `_isFetchingSurvey` et `_isSubmitting` pilotent les bannières et boutons (`survey_flow_page.dart`). Injectez vos propres flags si vous devez afficher une bannière success/erreur plus riche.
4. **Formulaire dynamique**
   - Les blocs sont montés dans `SurveyFormView`. Réordonnez ou insérez des sections (ex: `ConsentCard`) directement dans la `ListView`.
   - Pour changer les contrôles d’une question, éditez `SurveyQuestionField` : vous pouvez remplacer la logique `QuestionType.singleChoice` par un `DropdownButtonFormField` ou un widget custom.
5. **Photo & résumé**
   - `PhotoCaptureCard` affiche la preview : changez la taille, ajoutez un bouton « Supprimer photo ».
   - `EncryptionSummaryCard` tronque les base64 via `_preview`. Ajustez la longueur, ajoutez un bouton `IconButton` pour copier dans le presse-papiers ou masquer les clés derrière un `ExpansionTile`.

### 2. Ajouter un nouveau type de question (ex : date)

1. **Déclarer le type** – Ajoutez `date` à l’enum `QuestionType` (`lib/models/question_type.dart`) et mettez à jour `parseQuestionType`.
2. **Parsing JSON** – Aucune modif nécessaire dans `SurveyQuestion.fromJson` tant que la clé `type` existe, mais vous pouvez valider les `options` spécifiques ici.
3. **UI / validation** – Dans `SurveyQuestionField.build`, ajoutez un nouveau `case QuestionType.date` qui retourne un `TextFormField` en lecture seule + `showDatePicker` via `GestureDetector`, ou un widget dédié.
4. **Réponse sérialisée** – Aucun changement côté `SurveyAnswer` (stocke une `String`). Transformez la date au format voulue (`ISO8601`) avant `SurveyAnswer`.
5. **Mocks** – Ajoutez un exemple dans `lib/models/survey_samples.dart` pour vérifier le rendu hors ligne.
6. **Tests** – Montez `SurveyFormView` dans un test widget et interagissez avec votre nouveau type pour valider `validator` + `onChanged`.

### 3. Brancher un backend réel

1. **Configurer les repositories**
   ```dart
   final SurveyRepository _surveyRepository = SurveyRepository(
     baseUrl: const String.fromEnvironment('API_BASE_URL'),
     simulateFetch: false,
   );
   final SubmissionRepository _submissionRepository = SubmissionRepository(
     baseUrl: const String.fromEnvironment('API_BASE_URL'),
     simulateNetwork: false,
   );
   ```
   Placez ce code dans `SurveyFlowPage` (déclarations lignes 23‑29). Vous pouvez aussi injecter les instances via un `InheritedWidget` si plusieurs écrans les utilisent.
2. **Auth réelle**
   - Remplacez `AuthRepository.login` par votre implémentation (OAuth2, Basic, etc.) dans `lib/services/pipeline_services.dart`.
   - Continuez d’écrire le token obtenu dans `flutter_secure_storage` (`_storage.write`) pour que `SurveyFlowPage` n’ait rien à changer.
3. **Erreurs HTTP**
   - `SurveyRepository.fetchSurvey` et `SubmissionRepository.submit` lèvent `SurveyException` / `SubmissionException`. Ajoutez une inspection des `response.statusCode` pour retourner des messages détaillés (`switch` 400/401/500) et déclencher un `logout()` si nécessaire.
4. **Logs et monitoring**
   - Injectez un `http.Client` personnalisé (ex: avec interceptors) via les constructeurs `SurveyRepository(client: myClient, ...)`.

### 4. Adapter chiffrement, payloads et stockage

1. **Changer d’algorithme**
   - Modifiez `EncryptionService` (`lib/services/encryption_service.dart`). Par exemple :
     ```dart
     class EncryptionService {
       EncryptionService() : _algorithm = ChaCha20.poly1305Aead();
     }
     ```
   - Si vous devez renvoyer l’`authTag`, étendez `EncryptedField` (`lib/models/encrypted_field.dart`) pour inclure un champ `tag`.
2. **Ajouter des métadonnées**
   - `EncryptedSubmission` (`lib/models/encrypted_submission.dart`) contient `surveyId`, `answers`, `photo`, `encryptionKey`, `authToken`.
   - Ajoutez vos propriétés (ex: `deviceId`, `gps`) + mise à jour de `toJson`.
   - Dans `_submitForm`, renseignez ces champs avant l’appel à `_submissionRepository.submit`.
3. **Persister la photo temporairement**
   - Par défaut, `_capturePhoto` laisse tout en mémoire. Si vous devez sauvegarder un fichier :
     - Utilisez `XFile.saveTo`.
     - Passez le chemin au backend ou relisez les bytes avant chiffrement.
     - Supprimez le fichier une fois `encryptSubmission` terminé pour éviter les fuites disque.

### 5. Modèles, mocks et localisation

- **Modifier les textes** – Les libellés par défaut viennent du backend. Pour tester hors ligne, ajustez `SurveySamples._sampleData`.
- **Localiser l’UI** – Centralisez les chaînes dans `lib/l10n` (à créer), et remplacez les `Text('...')` existants (scanner, boutons, messages) par `AppLocalizations`.
- **Structure du sondage** – `lib/models/survey.dart` expose `toJson`; utilisez-le si vous devez poster un sondage depuis un outil interne ou valider la compatibilité avec un backend externe.

### 6. Tests et vérifications

1. **Lint & format** – `flutter analyze` (analyse statique) et `dart format .` si nécessaire.
2. **Tests widget** – `test/widget_test.dart` contient un squelette. Dupliquez-le pour couvrir :
   - rendu d’une question obligatoire,
   - affichage des erreurs `SurveyException`,
   - présence du résumé de chiffrement lorsqu’un `EncryptionBundle` est injecté.
3. **Tests manuels**
   - Simulateur : testez la saisie manuelle (caméra indisponible).
   - Device réel : testez `permission_handler` et `image_picker` (caméra frontale).
   - Backend réel : tracez les requêtes `GET /survey/{id}` et `POST /answers` avec un proxy (ex: `mitmproxy`) pour vérifier les headers `Authorization`.

## Ressources utiles

- `docs/architecture.md` : narrative complète du pipeline.
- `README.md` : commandes de build et déploiement.
- `rg TODO lib` : recherche rapide des TODO en attente.

Avec ce guide, vous pouvez pointer précisément la classe/le fichier à modifier pour chaque évolution et vérifier que l’intégralité du pipeline reste cohérente (UI → services → chiffrement → envoi).
