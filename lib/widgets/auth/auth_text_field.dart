// lib/widgets/auth/auth_text_field.dart
//
// Label + rounded TextFormField matching the auth mockups.
// Visibility icons come from AppIcons.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.pill = false,
    this.maxLength,
    this.inputFormatters,
    this.radius,
    this.height,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool pill;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  /// Overrides the corner radius (default: [AppRadius.inputField], or
  /// [AppRadius.inputPill] when [pill]).
  final double? radius;

  /// Fixes the field's height (dense layout) — the Login mockup uses ~35.
  final double? height;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final radius = widget.radius ??
        (widget.pill ? AppRadius.inputPill : AppRadius.inputField);
    final height = widget.height;
    // In the dense layout the icons set the box height. Only the box is
    // sized — the error text lays out below it instead of squeezing it.
    final iconBox = height == null
        ? null
        : BoxConstraints.tightFor(width: height + 6, height: height);
    OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          decoration: InputDecoration(
            counterText: '',
            hintText: widget.hint,
            isDense: height != null,
            contentPadding: height == null
                ? null
                : const EdgeInsets.symmetric(horizontal: 12),
            errorStyle: const TextStyle(fontSize: 12, height: 1.3),
            errorMaxLines: 2,
            prefixIconConstraints: iconBox,
            suffixIconConstraints: iconBox,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: Colors.grey.shade500)
                : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? AppIcons.passwordHidden
                          : AppIcons.passwordVisible,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
            border: outline(AppColors.secondary, 1.2),
            enabledBorder: outline(AppColors.secondary, 1.2),
            focusedBorder: outline(AppColors.primary, 1.6),
            errorBorder: outline(AppColors.error, 1.2),
            focusedErrorBorder: outline(AppColors.error, 1.6),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

/// "── OR ──" divider used between email/password actions and Google.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'OR'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }
}
