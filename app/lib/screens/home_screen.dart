import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../app_lock.dart';
import '../models.dart';
import '../storage.dart';
import 'emergency_screen.dart';
import 'result_screen.dart';
import 'trends_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SavedReport>? _reports;
  Profile? _profile;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final profile = await activeProfile();
    final reports = await loadReports();
    if (mounted) {
      setState(() {
        _profile = profile;
        _reports = reports;
      });
    }
  }

  Future<void> _switchProfile(String id) async {
    await setActiveProfile(id);
    await _refresh();
  }

  Future<String?> _askName(String title, [String initial = '']) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name, e.g. Mum'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProfile() async {
    final name = await _askName('Add a person');
    if (name == null || name.isEmpty) return;
    final profile = await addProfile(name);
    await _switchProfile(profile.id);
  }

  Future<void> _renameProfile(Profile profile) async {
    final name = await _askName('Rename', profile.name);
    if (name == null || name.isEmpty) return;
    await renameProfile(profile.id, name);
    await _refresh();
  }

  Future<void> _deleteProfile(Profile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete ${profile.name}?'),
        content: const Text(
          'All of their reports and emergency details will be removed from this device.',
        ),
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
    await deleteProfile(profile.id);
    await _refresh();
  }

  Future<void> _showProfiles() async {
    final profiles = await loadProfiles();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in profiles)
              ListTile(
                leading: Icon(
                  p.id == _profile?.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(p.name),
                onTap: () {
                  Navigator.pop(sheet);
                  _switchProfile(p.id);
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    Navigator.pop(sheet);
                    if (action == 'rename') _renameProfile(p);
                    if (action == 'delete') _deleteProfile(p);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    if (profiles.length > 1)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('Add a person'),
              onTap: () {
                Navigator.pop(sheet);
                _addProfile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage() async {
    final current = await loadLanguage();
    if (!mounted) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Explain results in'),
        children: [
          for (final l in supportedLanguages)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, l),
              child: Row(
                children: [
                  Expanded(child: Text(l)),
                  if (l == current) const Icon(Icons.check, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await saveLanguage(chosen);
      _showMessage('Results will be explained in $chosen.');
    }
  }

  Future<void> _onMenu(String action) async {
    switch (action) {
      case 'lock_on':
        await _toggleLock(true);
      case 'lock_off':
        await _toggleLock(false);
      case 'language':
        await _pickLanguage();
      case 'emergency':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EmergencyEditScreen()),
        );
    }
  }

  Future<void> _pick(String source) async {
    File? file;
    AppLock.suspended = true;
    try {
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
    } finally {
      AppLock.suspended = false;
    }
    if (file == null || !mounted) return;
    await _analyze(file);
  }

  Future<void> _analyze(File file) async {
    setState(() => _analyzing = true);
    try {
      final analysis = await analyzeReport(
        file,
        language: await loadLanguage(),
      );
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

  Future<void> _toggleLock(bool enable) async {
    if (enable) {
      if (!await AppLock.isAvailable()) {
        _showMessage('Set a screen lock or fingerprint on your phone first.');
        return;
      }
      AppLock.suspended = true;
      final ok = await AppLock.authenticate();
      AppLock.suspended = false;
      if (!ok) return;
    }
    await AppLock.setEnabled(enable);
    _showMessage(enable ? 'App lock is on.' : 'App lock is off.');
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
      appBar: AppBar(
        title: InkWell(
          onTap: _showProfiles,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _profile?.name ?? 'HealthVault',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Trends',
            icon: const Icon(Icons.show_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TrendsScreen()),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Settings',
            onSelected: _onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'emergency', child: Text('Emergency card')),
              PopupMenuItem(value: 'language', child: Text('Language')),
              PopupMenuItem(value: 'lock_on', child: Text('Turn on app lock')),
              PopupMenuItem(
                value: 'lock_off',
                child: Text('Turn off app lock'),
              ),
            ],
          ),
        ],
      ),
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
