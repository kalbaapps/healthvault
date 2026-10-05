import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _key = 'pending_reports';

/// A report photo or PDF waiting to be read because the phone was offline.
class PendingReport {
  final String id;
  final String profileId;
  final String filePath;
  final String language;
  final DateTime createdAt;

  const PendingReport({
    required this.id,
    required this.profileId,
    required this.filePath,
    required this.language,
    required this.createdAt,
  });

  factory PendingReport.fromJson(Map<String, dynamic> j) => PendingReport(
    id: j['id'] as String,
    profileId: j['profileId'] as String? ?? defaultProfileId,
    filePath: j['filePath'] as String,
    language: j['language'] as String? ?? 'English',
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'filePath': filePath,
    'language': language,
    'createdAt': createdAt.toIso8601String(),
  };
}

Future<List<PendingReport>> loadPending() async {
  final raw = (await SharedPreferences.getInstance()).getStringList(_key) ?? [];
  final items = <PendingReport>[];
  for (final item in raw) {
    try {
      items.add(
        PendingReport.fromJson(jsonDecode(item) as Map<String, dynamic>),
      );
    } catch (_) {
      // Skip an entry that can no longer be read.
    }
  }
  items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return items;
}

Future<void> _write(List<PendingReport> items) async {
  await (await SharedPreferences.getInstance()).setStringList(
    _key,
    items.map((i) => jsonEncode(i.toJson())).toList(),
  );
}

/// Copies [source] into app storage (the picker's file may be a temporary
/// cache) and remembers it for later. [dir] exists for tests.
Future<PendingReport> addPending(
  File source, {
  required String profileId,
  required String language,
  Directory? dir,
}) async {
  final folder =
      dir ??
      Directory('${(await getApplicationSupportDirectory()).path}/pending');
  await folder.create(recursive: true);

  final id = DateTime.now().microsecondsSinceEpoch.toString();
  final dot = source.path.lastIndexOf('.');
  final extension = dot == -1 ? '' : source.path.substring(dot);
  final copy = await source.copy('${folder.path}/$id$extension');

  final item = PendingReport(
    id: id,
    profileId: profileId,
    filePath: copy.path,
    language: language,
    createdAt: DateTime.now(),
  );
  await _write([...await loadPending(), item]);
  return item;
}

/// Forgets a queued report and deletes its stored copy.
Future<void> removePending(String id) async {
  final items = await loadPending();
  for (final item in items.where((i) => i.id == id)) {
    try {
      final file = File(item.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The record is removed even if the file cannot be deleted.
    }
  }
  await _write(items.where((i) => i.id != id).toList());
}
