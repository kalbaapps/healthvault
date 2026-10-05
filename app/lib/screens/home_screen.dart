import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../models.dart';
import '../storage.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SavedReport>? _reports;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final reports = await loadReports();
    if (mounted) setState(() => _reports = reports);
  }

  Future<void> _pick(String source) async {
    File? file;
    if (source == 'camera' || source == 'gallery') {
      final picked = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 85,
      );
      if (picked != null) file = File(picked.path);
    } else {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final path = picked.isEmpty ? null : picked.first.path;
      if (path != null) file = File(path);
    }
    if (file == null || !mounted) return;
    await _analyze(file);
  }

  Future<void> _analyze(File file) async {
    setState(() => _analyzing = true);
    try {
      final analysis = await analyzeReport(file);
      if (!mounted) return;
      if (!analysis.isMedicalReport) {
        _showMessage(
          "That doesn't look like a medical report. Try another file.",
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(analysis: analysis),
        ),
      );
      await _refresh();
    } on AnalysisException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not read that report. Please try again.');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showSources() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label, source) in [
              (Icons.photo_camera_outlined, 'Take a photo', 'camera'),
              (Icons.photo_library_outlined, 'Choose from gallery', 'gallery'),
              (Icons.picture_as_pdf_outlined, 'Choose a PDF', 'pdf'),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.pop(sheet);
                  _pick(source);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = _reports;
    return Scaffold(
      appBar: AppBar(title: const Text('HealthVault')),
      floatingActionButton: _analyzing
          ? null
          : FloatingActionButton.extended(
              onPressed: _showSources,
              icon: const Icon(Icons.add),
              label: const Text('Add report'),
            ),
      body: _analyzing
          ? const _Analyzing()
          : reports == null
          ? const Center(child: CircularProgressIndicator())
          : reports.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: reports.length,
              itemBuilder: (context, i) => _ReportTile(
                report: reports[i],
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ResultScreen(
                        analysis: reports[i].analysis,
                        savedId: reports[i].id,
                      ),
                    ),
                  );
                  await _refresh();
                },
              ),
            ),
    );
  }
}

class _Analyzing extends StatelessWidget {
  const _Analyzing();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Reading your report…'),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Understand your medical reports',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a lab report as a photo or PDF. HealthVault explains each result in plain language.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final SavedReport report;
  final VoidCallback onTap;

  const _ReportTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = report.analysis;
    final outOfRange = a.values
        .where((v) => v.flag == 'low' || v.flag == 'high')
        .length;
    final date =
        a.reportDate ?? report.savedAt.toIso8601String().substring(0, 10);
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(a.reportType),
        subtitle: Text('$date · ${a.values.length} results'),
        trailing: outOfRange == 0
            ? const Icon(Icons.check_circle_outline, color: Colors.green)
            : Chip(label: Text('$outOfRange to review')),
      ),
    );
  }
}
