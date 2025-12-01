# QRCodeQuizz

Prototype Flutter app that demonstrates the full capture pipeline described earlier:

1. **QR scan** – opens the camera feed (via `mobile_scanner`) and extracts the `surveyId` embedded in the code. A manual fallback input is also available for emulators.
2. **Survey fetch** – calls the `SurveyRepository` which in turn would hit your HTTPS API (the default implementation mocks a backend while keeping the structure ready for real endpoints).
3. **Photo capture** – requests runtime permissions, opens the camera (`image_picker`) and keeps the bytes in memory only.
4. **Local encryption** – answers + photo are encrypted with AES‑GCM (`cryptography`) and the symmetric key is represented in base64 for transport/storage.
5. **Secure submission** – the payload is POSTed via HTTPS with a bearer token (persisted inside `flutter_secure_storage`). The default `SubmissionRepository` simulates the network call so you can develop offline.

## Getting started

```bash
flutter pub get
flutter build apk --release
```

Useful commands when iterating:

```bash
flutter analyze
flutter test
```

On Android the manifest already declares `CAMERA` and `INTERNET` permissions. For iOS you still need to add camera usage descriptions inside `ios/Runner/Info.plist` (`NSCameraUsageDescription`).

## Flow walkthrough

- Launching the app shows the scanner. Scan any QR containing the survey id (plain text is enough) or tap “Saisir manuellement un ID”.
- The mocked API returns a survey schema; the UI renders dynamic fields + dropdowns.
- Tap “Prendre une photo” to capture a respondent picture (shown locally for confirmation only).
- “Chiffrer + envoyer” encrypts the JSON answers + photo bytes locally with AES‑GCM, displays the base64 key/preview and calls the submission repository which would POST to your backend via HTTPS/TLS with the bearer token.
- Hit the QR icon in the app bar to reset and scan a new survey.

## Notes

- Tokens are stored inside secure storage; replace the `AuthRepository` with your login/OAuth implementation when you hook it up to a real backend.
- `SurveyRepository` and `SubmissionRepository` expose `baseUrl`/`simulate*` parameters so you can toggle between the mock mode and real network calls.
- Remember to wipe any temporary files after upload if you ever persist the photo to disk. In this prototype nothing touches the filesystem; everything stays in memory until it is encrypted.
