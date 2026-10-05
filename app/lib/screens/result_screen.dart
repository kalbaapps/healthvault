import 'package:flutter/material.dart';

import '../models.dart';
import '../pdf_brief.dart';
import '../storage.dart';

class ResultScreen extends StatefulWidget {
  final ReportAnalysis analysis;

  /// Set when opened from history; null for a fresh, unsaved result.
  final String? savedId;

  const ResultScreen({super.key, required this.analysis, this.savedId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final String? _savedId = widget.savedId;

  Future<void> _share() async {
    try {
      await shareDoctorBrief(widget.analysis, (await activeProfile()).name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the summary.')),
      );
    }
  }

  Future<void> _save() async {
    await saveReport(widget.analysis);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = _savedId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('It will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await deleteReport(id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.analysis;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(a.reportType, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Share summary for your doctor',
          ),
          if (_savedId != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
        ],
      ),
      bottomNavigationBar: _savedId == null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save to my records'),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          if (a.urgent) _UrgentBanner(reason: a.urgentReason),
          Text('Summary', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(a.summary),
          const SizedBox(height: 24),
          Text('Your results', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final v in a.values) _ValueCard(value: v),
          if (a.questionsForDoctor.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Questions to ask your doctor',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final q in a.questionsForDoctor)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(q)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          Text(
            'This explanation is for information only and is not medical advice. '
            'Always talk to a doctor about your results.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  final String? reason;

  const _UrgentBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Please contact a doctor soon. ${reason ?? ''}',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final LabValue value;

  const _ValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (value.flag) {
      'low' => ('Low', Colors.orange),
      'high' => ('High', Colors.red),
      'normal' => ('Normal', Colors.green),
      _ => ('No range', Colors.grey),
    };
    final reference = value.referenceText;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(value.name, style: theme.textTheme.titleSmall),
                ),
                Chip(
                  label: Text(label),
                  side: BorderSide(color: color),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              '${value.valueText}${value.unit == null ? '' : ' ${value.unit}'}',
              style: theme.textTheme.headlineSmall,
            ),
            if (reference.isNotEmpty)
              Text('Usual range: $reference', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(value.explanation),
          ],
        ),
      ),
    );
  }
}
