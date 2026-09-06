// lib/screens/debug_test_screen.dart
//
// TEMPORARY FILE — delete this once you've confirmed ApiService works.
// Not part of F1-F8, just a scratchpad so you can see real responses
// (or real errors) without building AuthProvider/UI screens first.
//
// To use: add a temporary route to this screen, or just replace your
// home screen in main.dart with `home: const DebugTestScreen()` for now.

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class DebugTestScreen extends StatefulWidget {
  const DebugTestScreen({super.key});

  @override
  State<DebugTestScreen> createState() => _DebugTestScreenState();
}

class _DebugTestScreenState extends State<DebugTestScreen> {
  final ApiService _apiService = ApiService();
  String _output = 'Tap a button to test an endpoint.';
  bool _isLoading = false;

  // Wraps every test button so we don't repeat try/catch six times.
  // This is exactly the kind of error handling your REAL screens will
  // need too — DioException carries useful info in .response and .type.
  Future<void> _runTest(String label, Future<dynamic> Function() call) async {
    setState(() {
      _isLoading = true;
      _output = 'Calling $label...';
    });

    try {
      final result = await call();
      setState(() {
        _output = '✅ $label SUCCESS:\n\n$result';
      });
    } on DioException catch (e) {
      // This branch tells you WHICH kind of failure happened —
      // read this output carefully, it's the fastest way to diagnose
      // "wrong URL" vs "backend down" vs "CORS blocked" vs "401/403".
      setState(() {
        _output = '❌ $label FAILED\n\n'
            'Type: ${e.type}\n'
            'Status code: ${e.response?.statusCode}\n'
            'Message: ${e.message}\n'
            'Response body: ${e.response?.data}';
      });
    } catch (e) {
      setState(() {
        _output = '❌ $label FAILED (non-Dio error)\n\n$e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Debug Test (temporary)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Start with GUEST-SAFE endpoints first — these need no
            // login at all, so they isolate "is the connection even
            // working" from "is auth working."
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _runTest('getRoutes()', () => _apiService.getRoutes()),
              child: const Text('1. Test getRoutes() — guest-safe'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _runTest(
                      'getAnnouncements()', () => _apiService.getAnnouncements()),
              child: const Text('2. Test getAnnouncements() — guest-safe'),
            ),
            const SizedBox(height: 8),
            // Only test login AFTER the two above succeed — if guest
            // endpoints fail, login will fail too, for the same reason
            // (wrong URL / backend down), so fix that first.
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _runTest(
                      'login()',
                      () => _apiService.login('testuser', 'testpassword123'),
                    ),
              child: const Text('3. Test login() — needs a REAL test account'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Result:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_output),
              ),
            ),
          ],
        ),
      ),
    );
  }
}