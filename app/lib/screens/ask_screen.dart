import 'package:flutter/material.dart';

import '../api.dart';
import '../ask_context.dart';
import '../models.dart';
import '../storage.dart';

/// Chat about the saved reports of the active profile.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <ChatTurn>[];
  List<SavedReport> _reports = const [];
  Profile? _profile;
  bool _ready = false;
  bool _sending = false;

  static const _suggestions = [
    'How have my results changed?',
    'Which results are outside the usual range?',
    'What should I ask my doctor?',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final reports = await loadReports();
    final profile = await activeProfile();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _profile = profile;
      _ready = true;
    });
    if (!await hasAskConsent() && mounted) await _askConsent();
  }

  Future<void> _askConsent() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        title: const Text('Before you ask'),
        content: const Text(
          'To answer, your question and the test results from your saved reports '
          '(not your name) are sent to an AI service. Do not type names or ID '
          'numbers into your questions.\n\n'
          'The answers are for information only and are not medical advice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('I agree'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await setAskConsent();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty || _sending) return;

    final history = List<ChatTurn>.of(_turns);
    setState(() {
      _turns.add(ChatTurn(fromUser: true, text: question));
      _sending = true;
      _input.clear();
    });
    _scrollToEnd();

    String answer;
    try {
      answer = await askQuestion(
        question: question,
        language: await loadLanguage(),
        history: history,
        reports: _reports,
      );
    } on AnalysisException catch (e) {
      answer = e.message;
    } catch (_) {
      answer = 'Something went wrong. Please try again.';
    }

    if (!mounted) return;
    setState(() {
      _turns.add(ChatTurn(fromUser: false, text: answer));
      _sending = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: Text('Ask · ${_profile?.name ?? ''}')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _turns.isEmpty
                      ? _EmptyChat(
                          hasReports: _reports.isNotEmpty,
                          suggestions: _suggestions,
                          onPick: _send,
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          itemCount: _turns.length + (_sending ? 1 : 0),
                          itemBuilder: (context, i) => i == _turns.length
                              ? const _Bubble(text: '…', fromUser: false)
                              : _Bubble(
                                  text: _turns[i].text,
                                  fromUser: _turns[i].fromUser,
                                ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Information only, not medical advice.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 600,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _send,
                          decoration: const InputDecoration(
                            hintText: 'Ask about your results',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _sending ? null : () => _send(_input.text),
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final bool hasReports;
  final List<String> suggestions;
  final ValueChanged<String> onPick;

  const _EmptyChat({
    required this.hasReports,
    required this.suggestions,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              hasReports
                  ? 'Ask a question about your saved reports'
                  : 'Save a report first, then ask questions about it',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (hasReports)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in suggestions)
                    ActionChip(label: Text(s), onPressed: () => onPick(s)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool fromUser;

  const _Bubble({required this.text, required this.fromUser});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: fromUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(text),
      ),
    );
  }
}
