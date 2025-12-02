class EncryptedField {
  const EncryptedField({required this.cipherText, required this.nonce});

  final String cipherText;
  final String nonce;

  Map<String, dynamic> toJson() => {'cipherText': cipherText, 'nonce': nonce};
}
