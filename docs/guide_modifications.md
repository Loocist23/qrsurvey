# Guide de modification de QRCodeQuizz

Ce document complète `docs/architecture.md` et répond à la question « où dois-je intervenir pour modifier telle ou telle partie du flux QR → sondage → chiffrement ? ». Il se lit comme une carte des fichiers principaux, avec des scénarios de modification concrets.

## Carte rapide de l’arborescence

| Zone | Pour modifier… | Chemins clés |
| --- | --- | --- |
| Entrée / thème | Point de départ Flutter, Material 3, navigation vers le flow | `lib/main.dart`, `lib/app.dart` |
| Parcours utilisateur | Logique du scanner, formulaire dynamique, capture photo, états | `lib/features/survey/pages/survey_flow_page.dart` |
| Widgets UI | Scanner (`MobileScanner`), formulaire + cartes photo/chiffrement, composants de question | `lib/features/survey/widgets/**` |
| Modèles | Types de questions, schémas de sondage, payloads chiffrés, échantillons mockés | `lib/models/**/*.dart` |
| Services | Auth token, fetch sondage, soumission HTTPS, chiffrement AES‑GCM | `lib/services/pipeline_services.dart`, `lib/services/encryption_service.dart` |
| Documentation | Vue d’ensemble technique | `docs/architecture.md` |

## Modifier l’expérience utilisateur

- **Thème ou écran d’accueil** – Ajustez `MaterialApp` dans `lib/app.dart:8` (titre, thèmes, routes) ou remplacez `SurveyFlowPage` par votre propre page si vous introduisez un onboarding.
- **Scanner & saisie manuelle** – `lib/features/survey/widgets/survey_scanner_view.dart:8` contient la configuration `MobileScanner`. Pour limiter/étendre les formats de code, passez par le `MobileScannerController` instancié dans `survey_flow_page.dart:22`. Le bouton « Saisir manuellement » déclenche `_promptManualSurvey`; modifiez ce dialog dans `survey_flow_page.dart:120` pour renforcer la validation.
- **États & transitions** – Toute évolution du flux (autorisation caméra, appels réseau, messages d’erreur) se fait dans `SurveyFlowPage` (`_initialize`, `_fetchSurvey`, `_capturePhoto`, `_submitForm`). Ajoutez vos propres variables d’état ou métriques dans `_SurveyFlowPageState`.
- **Formulaire dynamique** – `lib/features/survey/widgets/survey_form_view.dart:15` alimente la `ListView`. Pour changer l’ordre des blocs, insérez ou réorganisez les widgets ici (par exemple ajouter une section « Consentement » avant la photo).
- **Photo & récapitulatif** – `PhotoCaptureCard` (`lib/features/survey/widgets/photo_capture_card.dart`) s’occupe de l’UX de prise de photo. Personnalisez le message, les boutons ou remplacez `image_picker` par un autre plugin via la callback `onCapturePhoto` implémentée dans `SurveyFlowPage._capturePhoto`.
- **Résumés de chiffrement** – `EncryptionSummaryCard` (`lib/features/survey/widgets/encryption_summary_card.dart`) affiche les aperçus base64. Ajoutez-y des boutons « Copier » ou un toggle pour masquer/afficher les clés.

## Ajouter de nouveaux types de questions

1. Déclarez les nouveaux types dans `lib/models/question_type.dart`.
2. Étendez le parsing dans `SurveyQuestion.fromJson` (`lib/models/survey_question.dart:16`).
3. Rendez `SurveyQuestionField` (`lib/features/survey/widgets/questions/survey_question_field.dart`) conscient de ce type en branchant le widget voulu (ex. slider, date picker). Faites passer la validation via `FormField`.
4. Si vos mocks doivent exposer ce type, ajustez `lib/models/survey_samples.dart`.

## Brancher un backend réel

- **Repositories** – Passez `simulateFetch = false` et `simulateNetwork = false` lors de l’instanciation de `SurveyRepository`/`SubmissionRepository` dans `survey_flow_page.dart:30`. Fournissez `baseUrl` (ex: `SurveyRepository(baseUrl: dotenv.env['API_URL'])`).
- **AuthRepository** – `lib/services/pipeline_services.dart:13` stocke simplement un token généré localement. Remplacez `login` par votre implémentation OAuth/REST et assurez-vous d’écrire dans `flutter_secure_storage` pour conserver la compatibilité UI.
- **Gestion des erreurs** – Les exceptions `SurveyException` et `SubmissionException` sont propagées jusqu’à `_statusMessage`. Pour gérer des codes spécifiques (ex: 401 → re-login), détectez-les dans `_fetchSurvey` / `_submitForm`.

## Adapter chiffrement et stockage

- **Algorithme / taille de clé** – Modifiez `EncryptionService` (`lib/services/encryption_service.dart`). Vous pouvez injecter un `AesGcm` différent ou créer une nouvelle classe (ex: `ChaCha20Poly1305`). Toute transformation supplémentaire (signature, split key) doit être ajoutée dans `encryptSubmission`.
- **Payload envoyé** – `lib/models/encrypted_submission.dart` définit la sérialisation. Ajoutez vos champs (UUID, géolocalisation, etc.) puis mettez à jour la construction de `EncryptedSubmission` dans `_submitForm`.
- **Photo optionnelle** – `_capturePhoto` (dans `SurveyFlowPage`) lit les bytes puis les passe à `EncryptionService`. Si vous souhaitez sauvegarder temporairement la photo sur disque, faites-le ici mais pensez à l’effacer après chiffrement.

## Tests et vérifications

- `flutter analyze` et `flutter test` (voir `README.md`) doivent tourner sans erreurs avant de pousser une modification structurante.
- Pour valider un nouveau type de question, ajoutez un test widget dans `test/widget_test.dart` ou créez un fichier dédié (`test/features/...`) qui monte `SurveyFormView` avec un `Survey` synthétique.
- Testez sur un device réel dès que vous modifiez les permissions/caméra : les simulateurs traitent différemment `permission_handler` et `image_picker`.

## Ressources utiles

- `docs/architecture.md` pour comprendre le storytelling complet de la fonctionnalité.
- Issues / TODOs : cherchez `TODO` via `rg TODO lib` si vous souhaitez trouver des points d’accroche rapides.

Avec cette carte en main vous devriez savoir immédiatement quel fichier modifier selon que vous touchez à l’UI, aux modèles de sondage, aux services réseau ou au chiffrement.
