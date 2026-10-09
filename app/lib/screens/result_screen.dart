import 'package:flutter/material.dart';

import '../checkup.dart';
import '../dates.dart';
import '../models.dart';
import '../pdf_brief.dart';
import '../range_bar.dart';
import '../reminders.dart';
import '../storage.dart';

class ResultScreen extends StatefulWidget {
  final ReportAnalysis analysis;

  /// Set when opened from history; null for a fresh, unsaved result.
  final String? savedId;

  /// The planned check-up of a saved report (ignored for a fresh result).
  final DateTime? nextCheckAt;

  const ResultScreen({
    super.key,
    required this.analysis,
    this.savedId,
    this.nextCheckAt,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final String? _savedId = widget.savedId;
  late DateTime? _nextCheck = widget.savedId != null
      ? widget.nextCheckAt
      : defaultNextCheck(widget.analysis, DateTime.now());

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
    await saveReportWithCheckup(
      widget.analysis,
      nextCheckAt: _nextCheck,
      suggest: false,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Opens the date picker. With [next] it starts from a fresh suggestion
  /// (after the current check-up) instead of the date already set.
  Future<void> _pickCheckDate({bool next = false}) async {
    final today = dateOnly(DateTime.now());
    final current = _nextCheck;
    final keepCurrent = !next && current != null && !current.isBefore(today);
    final picked = await showDatePicker(
      context: context,
      helpText: next ? 'Add the next check-up' : 'Next check-up',
      initialDate: keepCurrent
          ? current
          : addMonths(today, widget.analysis.followUpMonths ?? 3),
      firstDate: today,
      lastDate: addMonths(today, 60),
    );
    if (picked == null || !mounted) return;
    await _setCheck(dateOnly(picked));
  }

  Future<void> _setCheck(DateTime? date) async {
    setState(() => _nextCheck = date);
    if (date != null) {
      final allowed = await reminders.requestPermission();
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow notifications in Settings to get the reminder.',
            ),
          ),
        );
      }
    }
    // A fresh result is saved, with its date, when the user taps Save.
    final id = _savedId;
    if (id == null) return;
    await setNextCheck(id, date);
    await scheduleCheckup(reportId: id, analysis: widget.analysis, date: date);
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
    await cancelCheckupReminders(id);
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
          if (a.foodSuggestions.isNotEmpty ||
              a.exerciseSuggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('What may help', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (a.foodSuggestions.isNotEmpty)
              _TipsCard(
                icon: Icons.restaurant_outlined,
                title: 'Food',
                tips: a.foodSuggestions,
              ),
            if (a.exerciseSuggestions.isNotEmpty)
              _TipsCard(
                icon: Icons.directions_walk,
                title: 'Activity',
                tips: a.exerciseSuggestions,
              ),
          ],
          if (a.seeDoctor) _DoctorCard(reason: a.seeDoctorReason),
          _CheckupCard(
            next: _nextCheck,
            onChange: _pickCheckDate,
            onAddNext: () => _pickCheckDate(next: true),
            onClear: () => _setCheck(null),
          ),
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
            if (value.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: RangeBar(
                  value: value.value!,
                  low: value.referenceLow,
                  high: value.referenceHigh,
                  flag: value.flag,
                ),
              ),
            const SizedBox(height: 8),
            Text(value.explanation),
          ],
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> tips;

  const _TipsCard({
    required this.icon,
    required this.title,
    required this.tips,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final String? reason;

  const _DoctorCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.medical_services_outlined,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Please see a doctor. ${reason ?? ''}\n\n'
                'These tips are general and do not replace a doctor\'s advice.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckupCard extends StatelessWidget {
  final DateTime? next;
  final VoidCallback onChange;
  final VoidCallback onAddNext;
  final VoidCallback onClear;

  const _CheckupCard({
    required this.next,
    required this.onChange,
    required this.onAddNext,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = next;
    final status = date == null ? null : checkupStatus(date, DateTime.now());
    final due =
        status != null &&
        (status.urgency == CheckupUrgency.today ||
            status.urgency == CheckupUrgency.overdue);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Next check-up', style: theme.textTheme.titleSmall),
                      Text(
                        date == null
                            ? 'No reminder set'
                            : status!.short.isEmpty
                            ? formatDay(date)
                            : '${formatDay(date)} · ${status.short}',
                      ),
                      if (date != null)
                        Text(
                          'You will get a reminder 2 days before, 1 day before '
                          'and on the day. Ask your doctor what is right for you.',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onChange,
                  child: Text(date == null ? 'Set a date' : 'Change'),
                ),
                if (date != null)
                  IconButton(
                    tooltip: 'Turn off reminder',
                    onPressed: onClear,
                    icon: const Icon(Icons.notifications_off_outlined),
                  ),
              ],
            ),
            if (due)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: FilledButton.tonalIcon(
                  onPressed: onAddNext,
                  icon: const Icon(Icons.add),
                  label: const Text('Add next check-up date'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
