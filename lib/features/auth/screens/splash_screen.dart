import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  AuthProvider? _auth;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthProvider>().initialize();
      if (!mounted) return;
      _maybeNavigate(context.read<AuthProvider>().state);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = context.read<AuthProvider>();
    if (_auth != current) {
      _auth = current;
      _auth!.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _maybeNavigate(_auth!.state);
  }

  void _maybeNavigate(AuthState state) {
    if (_navigated) return;
    switch (state.status) {
      case AuthStatus.authenticated:
        _navigated = true;
        Navigator.of(context).pushReplacementNamed(RouteNames.homeAlias);
        break;
      case AuthStatus.biometricAvailable:
        _navigated = true;
        Navigator.of(context).pushReplacementNamed(RouteNames.biometricLogin);
        break;
      case AuthStatus.needsSetup:
        _navigated = true;
        Navigator.of(context).pushReplacementNamed(RouteNames.storeSetup);
        break;
      case AuthStatus.needsVerification:
        _navigated = true;
        Navigator.of(context).pushReplacementNamed(RouteNames.otp);
        break;
      case AuthStatus.sessionExpired:
      case AuthStatus.unauthenticated:
        _navigated = true;
        Navigator.of(context).pushReplacementNamed(RouteNames.login);
        break;
      case AuthStatus.initial:
      default:
        // stay on splash while initializing
        break;
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
