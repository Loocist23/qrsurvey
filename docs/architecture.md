# Architecture & logique de QRCodeQuizz

## Aperçu
- Application Flutter (`lib/main.dart`) qui démontre un pipeline complet depuis le scan d’un QR code jusqu’à la soumission chiffrée d’un sondage.
- Le widget principal `SurveyFlowPage` orchestre permissions caméra, authentification mockée, rendu dynamique du formulaire, capture photo et chiffrement local.
- Le flux fonctionne entièrement hors ligne grâce aux repos et jeux de données simulés, tout en conservant des interfaces compatibles avec un backend réel.

## Parcours utilisateur et logique écran
1. **Initialisation**
   - `initState` appelle `_ensureCameraPermission` puis `AuthRepository.login` pour obtenir un bearer token stocké dans `flutter_secure_storage`.
   - L’écran reste bloqué sur un `CircularProgressIndicator` tant que `_authToken` est null.
2. **Scan QR ou saisie manuelle**
   - `_buildScanner` affiche `MobileScanner` (format QR uniquement). Dès qu’un code contient une `rawValue`, le flux est arrêté et `_fetchSurvey` est déclenché.
   - L’icône clavier ouvre `_promptManualSurvey`, un `AlertDialog` permettant de tester sur simulateur/emulateur.
3. **Chargement du sondage**
   - `SurveyRepository.fetchSurvey` retourne soit un schéma simulé (`SurveySamples`) soit les données JSON depuis `GET {baseUrl}/survey/{surveyId}`.
   - Les contrôleurs de formulaire sont recréés et `_survey` devient non null, ce qui remplace la vue scanner par `_buildSurveyForm`.
4. **Formulaire dynamique**
   - La liste des `SurveyQuestion` est mappée vers des widgets : `DropdownButtonFormField` pour `singleChoice`, `TextFormField` pour `text`/`number`.
   - Chaque champ applique la validation « Champ requis » si `question.required == true`.
   - `_controllers` associe question → `TextEditingController` et `_choiceAnswers` retient les sélections.
5. **Capture photo**
   - Carte « Photo avec consentement » appelle `_capturePhoto`, qui (re)demande la permission caméra, lance `image_picker` en mode caméra frontale, conserve uniquement les bytes en mémoire et affiche un aperçu local.
6. **Chiffrement + envoi**
   - `_submitForm` vérifie que le formulaire est valide, assemble un payload `{ answers, submittedAt }`, puis appelle `EncryptionService.encryptSubmission`.
   - Un résumé affiche la clé AES base64 + un extrait des ciphertexts (`_buildEncryptionSummary`) pour faciliter le débogage.
   - `SubmissionRepository.submit` simule une requête HTTPS (ou POST réel vers `{baseUrl}/answers` avec `Authorization: Bearer {token}`) et renvoie les éventuelles erreurs à l’UI.
7. **Reset**
   - L’icône QR dans l’AppBar déclenche `_resetSurvey`, vide les contrôleurs, supprime photo/bundle/status et relance `MobileScanner`.

## Modèles de données (`lib/models/survey_models.dart`)
- `QuestionType` : enum (`text`, `number`, `singleChoice`) avec parseur tolérant (`_parseQuestionType`).
- `SurveyQuestion` : définit id, label, type, options (pour choix), booléen `required` et placeholder.
- `Survey` : métadonnées du sondage (title, description) + liste de questions. Fournit `fromJson` / `toJson`.
- `SurveyAnswer` : lien `questionId` ↔ `response`, utilisé lors de la collecte UI et de la sérialisation.
- `EncryptedField` : couple `{ cipherText, nonce }` en base64 pour chaque payload chiffré.
- `EncryptedSubmission` : structure envoyée au backend (`surveyId`, champs chiffrés, clé AES en base64, token d’authentification).
- `SurveySamples` : générateur de sondage mocké, utilisé par `SurveyRepository` lorsque `simulateFetch == true`.

## Services pipeline (`lib/services/pipeline_services.dart`)
- `AuthRepository`
  - Utilise `flutter_secure_storage` pour persister le bearer token.
  - `login` génère un token aléatoire (Base64 de 32 octets sécurisés) après avoir simulé un appel réseau.
  - `logout` supprime la clé `auth_token`.
- `SurveyRepository`
  - Injection d’un `http.Client` optionnel, `baseUrl` et booléen `simulateFetch`.
  - Mode simulé : renvoie `SurveySamples` après un délai artificiel.
  - Mode réel : `GET {baseUrl}/survey/{surveyId}` et parse JSON → `Survey`, sinon `SurveyException`.
- `SubmissionRepository`
  - Paramètres analogues (`http.Client`, `baseUrl`, `simulateNetwork`).
  - Mode simulé : simple `Future.delayed`.
  - Mode réel : `POST {baseUrl}/answers` avec entête `Authorization` et body JSON issu de `EncryptedSubmission.toJson()`.
  - Erreurs HTTP ≥ 400 lèvent `SubmissionException` dont le message est surfacé dans l’UI.

## Service de chiffrement (`lib/services/encryption_service.dart`)
- `EncryptionService` encapsule `AesGcm.with256bits()` (package `cryptography`).
- `encryptSubmission` :
  - Génère une clé symétrique (`SecretKey`), l’extrait en octets et la convertit en Base64.
  - Chiffre le JSON des réponses via `_encryptBytes`, qui produit `EncryptedField` (cipherText + nonce en Base64).
  - Si des bytes photo sont fournis, applique le même flux.
  - Retourne un `EncryptionBundle` regroupant clé, réponses chiffrées et éventuel bloc photo.
- Toutes les données (réponses/photo) restent en mémoire claire uniquement le temps du chiffrement, aucun fichier temporaire n’est écrit.

## Gestion d’état & UX (`lib/main.dart`)
- `_statusMessage`, `_isFetchingSurvey` et `_isSubmitting` contrôlent les messages d’erreur/chargement.
- `GlobalKey<FormState>` centralise la validation du formulaire dynamique.
- `_lastBundle` permet de montrer le résultat du chiffrement sans toucher au backend.
- Les permissions caméra sont demandées à deux endroits (scan et capture photo) pour éviter d’échouer silencieusement.

## Extension / intégration backend
- Pour brancher un vrai backend, fournir `baseUrl` aux repositories et passer `simulateFetch = false`, `simulateNetwork = false`.
- Remplacer `AuthRepository` par votre implémentation OAuth/login réelle : l’UI n’a besoin que d’un token Bearer.
- Adapter `SurveySamples` ou supprimer son usage si vos serveurs renvoient des schémas plus complexes (types supplémentaires, contraintes, etc.).

Ce document sert de référence pour tout nouveau collaborateur : il décrit où se situent les modèles, comment les services communiquent et comment l’écran principal réagit au cycle QR → formulaire → photo → chiffrement → envoi.
