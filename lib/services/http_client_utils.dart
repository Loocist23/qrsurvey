import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/io_client.dart' as http show IOClient;

/// Creates an HTTP client that accepts self-signed certificates.
/// This should only be used for development/testing purposes.
http.Client createInsecureHttpClient() {
  final HttpClient client = HttpClient()
    ..badCertificateCallback = 
        (X509Certificate cert, String host, int port) => true;
  
  return http.IOClient(client);
}

/// Creates a secure HTTP client with default certificate verification.
/// This is the production-ready client.
http.Client createSecureHttpClient() {
  return http.Client();
}