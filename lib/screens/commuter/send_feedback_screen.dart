// Send feedback screen
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/transport_model.dart';
import '../../services/api_error.dart';
import '../../services/profile_service.dart';

/// Feedback categories
const Map<String, String> feedbackCategories = {
  'delay': 'Delay',
  'overcrowding': 'Overcrowding',
  'route_issue': 'Route issue',
  'driver_behavior': 'Driver behavior',
  'other': 'Other',
};

const int feedbackMaxLength = 1000;

/// Send feedback screen
class SendFeedbackScreen extends StatefulWidget {
  /// Create send feedback screen
  const SendFeedbackScreen({super.key, required this.service, required this.routes});

  final ProfileService service;
  final List<TransportRoute> routes;

  /// Create widget state
  @override
  State<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

/// Send feedback state
class _SendFeedbackScreenState extends State<SendFeedbackScreen> {
  final _message = TextEditingController();
  String _category = 'other';
  String? _routeId;
  String? _error;
  bool _sending = false;

  /// Clean up resources
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  /// Send it
  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write a short message first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.sendFeedback(category: _category, message: text, routeId: _routeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your feedback was sent to the operator.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final routes = [...widget.routes.where((r) => r.isActive)]..sort((a, b) => a.code.compareTo(b.code));
    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      appBar: AppBar(
        backgroundColor: AppColors.brandTeal,
        foregroundColor: Colors.white,
        title: const Text('Send Feedback'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text('Tell the operator what happened. Your name and email are not shown to them.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            key: const Key('feedbackCategory'),
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category', filled: true, fillColor: Colors.white),
            items: [
              for (final e in feedbackCategories.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'other'),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            key: const Key('feedbackRoute'),
            initialValue: _routeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Route (optional)', filled: true, fillColor: Colors.white),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('No specific route')),
              for (final r in routes)
                DropdownMenuItem<String?>(
                  value: r.id,
                  child: Text('${r.code} · ${r.name}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _routeId = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('feedbackMessage'),
            controller: _message,
            maxLines: 5,
            maxLength: feedbackMaxLength,
            decoration: const InputDecoration(labelText: 'Message', filled: true, fillColor: Colors.white),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          FilledButton(
            key: const Key('feedbackSend'),
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandTeal),
            child: Text(_sending ? 'Sending…' : 'Send feedback'),
          ),
        ],
      ),
    );
  }
}
