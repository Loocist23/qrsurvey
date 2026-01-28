import 'package:flutter/material.dart';

import '../../../models/auth_session.dart';
import '../../../services/pipeline_services.dart';
import '../../survey/pages/survey_flow_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthRepository _authRepository = AuthRepository();

  bool _isLoading = true;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final AuthSession? session = await _authRepository.loadSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  void _handleLoggedIn(AuthSession session) {
    setState(() {
      _session = session;
    });
  }

  Future<void> _handleRequireLogin() async {
    await _authRepository.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return LoginPage(
        authRepository: _authRepository,
        onLoggedIn: _handleLoggedIn,
      );
    }

    return SurveyFlowPage(
      session: _session!,
      onRequireLogin: _handleRequireLogin,
    );
  }
}
