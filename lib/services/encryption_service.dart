import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/survey_models.dart';
import 'api_config.dart';

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
  EncryptionService({AesGcm? algorithm, String? encryptionKey})
    : _algorithm = algorithm ?? AesGcm.with256bits(),
      _encryptionKey = encryptionKey ?? ApiConfig.encryptionKey;

  final AesGcm _algorithm;
  final String _encryptionKey;

  Future<SecretKey> _generateKey() async {
    // Use the fixed key from configuration
    final Uint8List keyBytes = Uint8List.fromList(utf8.encode(_encryptionKey));
    // Ensure the key is the correct length for AES-256 (32 bytes)
    final Uint8List paddedKey = _padKeyTo256Bits(keyBytes);
    return SecretKey(paddedKey);
  }

  Uint8List _padKeyTo256Bits(Uint8List keyBytes) {
    // AES-256 requires 32 bytes (256 bits)
    final Uint8List paddedKey = Uint8List(32);
    if (keyBytes.length >= 32) {
      // If key is too long, use first 32 bytes
      paddedKey.setRange(0, 32, keyBytes);
    } else {
      // If key is too short, pad with zeros
      paddedKey.setRange(0, keyBytes.length, keyBytes);
      paddedKey.fillRange(keyBytes.length, 32, 0);
    }
    return paddedKey;
  }

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
