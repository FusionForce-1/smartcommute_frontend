// lib/widgets/auth/consent_checkbox.dart
//
// "I confirm that I have read, consent and agree to SmartCommute's User
// Agreement and Privacy Policy" — the register screen's consent box. Each
// link opens its document in a popup.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../constants/legal_text.dart';

class ConsentCheckbox extends StatefulWidget {
  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<ConsentCheckbox> createState() => _ConsentCheckboxState();
}

class _ConsentCheckboxState extends State<ConsentCheckbox> {
  late final _agreementTap = TapGestureRecognizer()
    ..onTap = () => showLegalDoc(context, userAgreement);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => showLegalDoc(context, privacyPolicy);

  @override
  void dispose() {
    _agreementTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.secondary, fontSize: 12, height: 1.4);
    const link = TextStyle(fontWeight: FontWeight.w700);
    return InkWell(
      onTap: () => widget.onChanged(!widget.value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              key: const Key('consentCheckbox'),
              value: widget.value,
              onChanged: (v) => widget.onChanged(v ?? false),
              activeColor: AppColors.secondary,
              side: const BorderSide(color: AppColors.secondary, width: 1.4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  const TextSpan(
                    text: "I confirm that I have read, consent and agree to SmartCommute's ",
                  ),
                  TextSpan(text: 'User Agreement', style: link, recognizer: _agreementTap),
                  const TextSpan(text: ' and '),
                  TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacyTap),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [doc] in a scrollable popup.
Future<void> showLegalDoc(BuildContext context, LegalDoc doc) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              doc.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.secondary),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last updated ${doc.updated}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(doc.intro, style: const TextStyle(fontSize: 13, height: 1.5)),
              for (final (heading, points) in doc.sections) ...[
                const SizedBox(height: 14),
                Text(
                  heading,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(fontSize: 13, height: 1.5)),
                        Expanded(
                          child: Text(point, style: const TextStyle(fontSize: 13, height: 1.5)),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
