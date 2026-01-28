class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.userId,
    required this.username,
  });

  final String accessToken;
  final String refreshToken;
  final String role;
  final int userId;
  final String username;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      role: json['role'] as String,
      userId: (json['user_id'] as num).toInt(),
      username: json['username'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'role': role,
      'user_id': userId,
      'username': username,
    };
  }
}
