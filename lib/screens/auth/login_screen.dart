// lib/screens/auth/login_screen.dart
//
// Emae D. Calonia — Flutter Login (Commuter / Driver).
// Logo lockup over an ice-blue panel (72% of the height, rounded bottom)
// on teal; sizes follow the screen. Wide screens (web, tablets) keep the
// stacked layout centred; only short rotated phones put the logo beside
// the card.
// Remember Me, Forgot Password, Login, Continue as Guest, Google, register link.
//
// This screen is UI-only. Wire AuthProvider from the parent (see auth_app.dart).

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../widgets/auth/smart_commute_logo.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/google_signin_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/error_banner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onLogin,
    this.onGoogleSignIn,
    this.onGuestContinue,
    this.onForgotPassword,
    this.onCreateAccount,
  });

  /// TODO: Velez — AuthProvider.login(email, password, rememberMe: rememberMe)
  /// → ApiService.login() → POST /auth/login
  final Future<void> Function(
    String email,
    String password,
    bool rememberMe,
  )? onLogin;

  /// TODO: Velez — google_sign_in idToken then
  /// AuthProvider.loginWithGoogle(idToken) → POST /auth/google
  final Future<void> Function()? onGoogleSignIn;

  /// TODO: Velez — AuthProvider.continueAsGuest() (local only, no HTTP)
  final VoidCallback? onGuestContinue;

  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Velez — trigger AuthProvider.notifyListeners() after POST /auth/login
      await widget.onLogin?.call(
        _emailController.text.trim(),
        _passwordController.text,
        _rememberMe,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Invalid email or password.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogle() async {
    try {
      // TODO: Velez — obtain Google idToken, then POST /auth/google
      await widget.onGoogleSignIn?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Google sign-in failed. Try again.');
      }
    }
  }

  /// Share of the screen height covered by the ice-blue top panel —
  /// the mockup's split sits at ~72%.
  static const double _panelFraction = 0.72;

  /// Cards wider than this look stretched on large phones / foldables.
  static const double _maxCardWidth = 420;

  /// Width of the phone the mockup was drawn for. Every size below is the
  /// mockup's pixel measurement times [_scaleFor] — so a 360-wide phone gets
  /// the same proportions, just smaller.
  static const double _designWidth = 414;

  static double _scaleFor(Size size) =>
      (size.shortestSide / _designWidth).clamp(0.8, 1.2);

  /// Below this height the stacked logo + card can't fit, so the logo
  /// moves beside the card. Only rotated phones are this short — desktop
  /// browsers and tablets keep the stacked mobile design.
  static const double _minStackedHeight = 560;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final isLandscape = size.width > size.height &&
                size.height < _minStackedHeight;
            final scale = _scaleFor(size);
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: size.height * _panelFraction,
                  child: DecoratedBox(
                    key: const Key('loginTopPanel'),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundIceBlue,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(12 * scale),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: isLandscape
                      ? _buildLandscape(size, scale)
                      : _buildPortrait(size, scale),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Logo over card, anchored to the bottom like the mockup (card ends 56px
  /// above the bottom of an 896-tall screen); extra height on taller phones
  /// goes above the logo. Scrolls when it doesn't fit (small phones,
  /// keyboard open).
  Widget _buildPortrait(Size size, double scale) {
    final gutter = (32 * scale).clamp(16.0, 40.0);
    // Vertical spacing follows the screen height, as the mockup's 896.
    final vScale = (size.height / 896).clamp(0.6, 1.2);
    // Shrinks faster than the screen on short phones so the card still fits.
    final logoHeight = (size.height * 0.26 * vScale).clamp(80.0, 240.0);
    final gap = 58 * vScale;
    final bottom = 56 * vScale;
    // Content is bottom-anchored, so top padding only matters when tight.
    const top = 12.0;
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, top, gutter, bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                (viewport.maxHeight - top - bottom).clamp(0.0, double.infinity),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SmartCommuteLogo(height: logoHeight),
              SizedBox(height: gap),
              _constrainedCard(scale),
            ],
          ),
        ),
      ),
    );
  }

  /// Rotated phones are too short to stack, so the logo sits beside the card.
  Widget _buildLandscape(Size size, double scale) {
    final gutter = (size.width * 0.04).clamp(16.0, 32.0);
    final logoHeight = (size.height * 0.35).clamp(80.0, 200.0);
    return Row(
      children: [
        // Centre the logo within the ice-blue panel, not the full height,
        // so the tagline doesn't sit on the panel/teal edge.
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: size.height * (1 - _panelFraction),
            ),
            child: Center(child: SmartCommuteLogo(height: logoHeight)),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(0, gutter, gutter, gutter),
            child: _constrainedCard(scale),
          ),
        ),
      ],
    );
  }

  Widget _constrainedCard(double scale) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxCardWidth),
        child: _buildCard(scale),
      ),
    );
  }

  /// The mockup's buttons are short rounded rectangles, not the app-wide
  /// pills — override the theme for this card only.
  ThemeData _cardTheme(double scale) {
    final theme = Theme.of(context);
    final shape = WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
    );
    final size = WidgetStatePropertyAll(Size.fromHeight(35 * scale));
    const padding = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16),
    );
    return theme.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: theme.elevatedButtonTheme.style!.copyWith(
          minimumSize: size,
          shape: shape,
          padding: padding,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: theme.outlinedButtonTheme.style!.copyWith(
          minimumSize: size,
          shape: shape,
          padding: padding,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(double scale) {
    final fieldHeight = 35 * scale;
    final fieldRadius = 12 * scale;
    return Container(
      key: const Key('loginCard'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        33 * scale,
        20 * scale,
        33 * scale,
        22 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: AppShadows.card,
      ),
      child: Theme(
        data: _cardTheme(scale),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: AppSpacing.sm),
              ],
              AuthTextField(
                label: 'Email',
                hint: 'Email',
                controller: _emailController,
                prefixIcon: AppIcons.person,
                keyboardType: TextInputType.emailAddress,
                height: fieldHeight,
                radius: fieldRadius,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter your email';
                  }
                  if (!v.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              AuthTextField(
                label: 'Password',
                hint: 'Password',
                controller: _passwordController,
                prefixIcon: AppIcons.lock,
                obscureText: true,
                height: fieldHeight,
                radius: fieldRadius,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _rememberMe
                              ? AppIcons.checkboxOn
                              : AppIcons.checkboxOff,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Remember Me',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onForgotPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12 * scale),
              ElevatedButton(
                onPressed: _handleLogin,
                child: const Text('Login'),
              ),
              OutlinedButton(
                onPressed: widget.onGuestContinue,
                child: const Text('Continue as Guest'),
              ),
              SizedBox(height: 6 * scale),
              const OrDivider(),
              SizedBox(height: 12 * scale),
              GoogleSignInButton(height: 35 * scale),
              SizedBox(height: 14 * scale),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onCreateAccount,
                    child: const Text(
                      'Create an account',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
