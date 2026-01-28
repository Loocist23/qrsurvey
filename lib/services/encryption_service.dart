import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/survey_models.dart';

class EncryptionBundle {
  const EncryptionBundle({
    required this.base64Key,
    required this.answers,
    this.photo,
  });

  final String base64Key;
  final EncryptedField answers;
  final EncryptedField? photo;
}

class EncryptionService {
  EncryptionService({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  final AesGcm _algorithm;

  Future<SecretKey> _generateKey() => _algorithm.newSecretKey();

  Future<EncryptionBundle> encryptSubmission({
    required Object answers,
    Uint8List? photoBytes,
  }) async {
    final SecretKey secretKey = await _generateKey();
    final Uint8List keyBytes = Uint8List.fromList(
      await secretKey.extractBytes(),
    );

    final EncryptedField encryptedAnswers = await _encryptBytes(
      _encodeJson(answers),
      secretKey,
    );
    final EncryptedField? encryptedPhoto = photoBytes == null
        ? null
        : await _encryptBytes(photoBytes, secretKey);

    return EncryptionBundle(
      base64Key: base64Encode(keyBytes),
      answers: encryptedAnswers,
      photo: encryptedPhoto,
    );
  }

  Future<EncryptedField> _encryptBytes(
    Uint8List data,
    SecretKey secretKey,
  ) async {
    final List<int> nonce = _algorithm.newNonce();
    final SecretBox box = await _algorithm.encrypt(
      data,
      secretKey: secretKey,
      nonce: nonce,
    );

    return EncryptedField(
      cipherText: base64Encode(box.cipherText),
      nonce: base64Encode(box.nonce),
    );
  }

  Uint8List _encodeJson(Object json) {
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }
}
