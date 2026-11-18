// Login screen
import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../widgets/auth/smart_commute_logo.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/google_signin_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/error_banner.dart';

/// Login screen
class LoginScreen extends StatefulWidget {
  /// Create login
  const LoginScreen({
    super.key,
    this.onLogin,
    this.onGuestContinue,
    this.onForgotPassword,
    this.onCreateAccount,
  });

  final Future<void> Function(
    String email,
    String password,
    bool rememberMe,
  )? onLogin;

  final VoidCallback? onGuestContinue;

  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;

  /// Create widget state
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Login state
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  /// Clean up resources
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handle login
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
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

  static const double _panelFraction = 0.72;

  static const double _maxCardWidth = 420;

  static const double _designWidth = 414;

  /// Scale for
  static double _scaleFor(Size size) =>
      (size.shortestSide / _designWidth).clamp(0.8, 1.2);

  static const double _minStackedHeight = 560;

  double _stableWidth = 0;
  double _stableHeight = 0;

  /// Layout size
  Size _layoutSize(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width != _stableWidth || size.height > _stableHeight) {
      _stableWidth = size.width;
      _stableHeight = size.height;
    }
    return Size(_stableWidth, _stableHeight);
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Builder(
          builder: (context) {
            final size = _layoutSize(context);
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

  /// Build portrait
  Widget _buildPortrait(Size size, double scale) {
    final gutter = (32 * scale).clamp(16.0, 40.0);
    final vScale = (size.height / 896).clamp(0.6, 1.2);
    final logoHeight = (size.height * 0.26 * vScale).clamp(80.0, 240.0);
    final gap = 58 * vScale;
    final bottom = 56 * vScale;
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

  /// Build landscape
  Widget _buildLandscape(Size size, double scale) {
    final gutter = (size.width * 0.04).clamp(16.0, 32.0);
    final logoHeight = (size.height * 0.35).clamp(80.0, 200.0);
    return Row(
      children: [
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

  /// Constrained card
  Widget _constrainedCard(double scale) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxCardWidth),
        child: _buildCard(scale),
      ),
    );
  }

  /// Card theme
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

  /// Build card
  Widget _buildCard(double scale) {
    final fieldHeight = 35 * scale;
    final fieldRadius = 12 * scale;
    return Container(
      key: const Key('loginCard'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        33 * scale,
        18 * scale,
        33 * scale,
        20 * scale,
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
              SizedBox(height: 8 * scale),
              OutlinedButton(
                onPressed: widget.onGuestContinue,
                child: const Text('Continue as Guest'),
              ),
              SizedBox(height: 6 * scale),
              const OrDivider(),
              SizedBox(height: 12 * scale),
              GoogleSignInButton(height: 35 * scale),
              SizedBox(height: 12 * scale),
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
