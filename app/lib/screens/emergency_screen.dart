import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';

/// Read-only card. Reachable from the lock screen, so it is visible without unlocking.
class EmergencyCardScreen extends StatelessWidget {
  const EmergencyCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency card')),
      body: FutureBuilder<(Profile, EmergencyInfo)>(
        future: () async {
          final profile = await activeProfile();
          return (profile, await loadEmergencyInfo(profile.id));
        }(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (profile, info) = snapshot.data!;
          if (info.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No emergency details have been added yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final rows = <(String, String)>[
            ('Name', profile.name),
            ('Blood type', info.bloodType),
            ('Allergies', info.allergies),
            ('Conditions', info.conditions),
            ('Medications', info.medications),
            ('Emergency contact', _contact(info)),
          ].where((r) => r.$2.isNotEmpty).toList();
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              for (final (label, value) in rows)
                Card(
                  child: ListTile(
                    title: Text(label),
                    subtitle: Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _contact(EmergencyInfo info) => [
    info.contactName,
    info.contactPhone,
  ].where((s) => s.isNotEmpty).join(' · ');
}

class EmergencyEditScreen extends StatefulWidget {
  const EmergencyEditScreen({super.key});

  @override
  State<EmergencyEditScreen> createState() => _EmergencyEditScreenState();
}

class _EmergencyEditScreenState extends State<EmergencyEditScreen> {
  final _blood = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  final _medications = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String _profileName = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await activeProfile();
    final info = await loadEmergencyInfo(profile.id);
    if (!mounted) return;
    setState(() {
      _profileName = profile.name;
      _blood.text = info.bloodType;
      _allergies.text = info.allergies;
      _conditions.text = info.conditions;
      _medications.text = info.medications;
      _contactName.text = info.contactName;
      _contactPhone.text = info.contactPhone;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _blood,
      _allergies,
      _conditions,
      _medications,
      _contactName,
      _contactPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await saveEmergencyInfo(
      EmergencyInfo(
        bloodType: _blood.text.trim(),
        allergies: _allergies.text.trim(),
        conditions: _conditions.text.trim(),
        medications: _medications.text.trim(),
        contactName: _contactName.text.trim(),
        contactPhone: _contactPhone.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c, {int lines = 1}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            minLines: lines,
            maxLines: lines + 2,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text('Emergency card · $_profileName')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Anyone holding this phone can open this card from the lock '
                      'screen without your fingerprint or PIN. Only add what you '
                      'are happy for a first responder to see.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                field('Blood type', _blood),
                field('Allergies', _allergies, lines: 2),
                field('Medical conditions', _conditions, lines: 2),
                field('Current medications', _medications, lines: 2),
                field('Emergency contact name', _contactName),
                field('Emergency contact phone', _contactPhone),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
    );
  }
}
