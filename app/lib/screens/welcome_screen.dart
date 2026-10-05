import 'package:flutter/material.dart';

import '../storage.dart';

/// Shows [child] straight away for returning users; on first launch asks for a
/// name and the language results should be explained in.
class WelcomeGate extends StatefulWidget {
  final Widget child;

  const WelcomeGate({super.key, required this.child});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    isOnboarded().then((v) {
      if (mounted) setState(() => _onboarded = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = _onboarded;
    if (onboarded == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (onboarded) return widget.child;
    return WelcomeScreen(onDone: () => setState(() => _onboarded = true));
  }
}

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onDone;

  const WelcomeScreen({super.key, required this.onDone});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _name = TextEditingController();
  String _language = supportedLanguages.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim();
    if (name.isNotEmpty) {
      final profile = await activeProfile();
      await renameProfile(profile.id, name);
    }
    await saveLanguage(_language);
    await setOnboarded();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.health_and_safety_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to HealthVault',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep your medical reports in one private place and understand '
              'them in your own language. Your reports are stored on this phone.',
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(
                labelText: 'Explain my results in',
                helperText: 'Reports can be in English or any language. Results are written in this one.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final l in supportedLanguages)
                  DropdownMenuItem(value: l, child: Text(l)),
              ],
              onChanged: (v) => setState(() => _language = v ?? _language),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: _start, child: const Text('Get started')),
          ],
        ),
      ),
    );
  }
}
