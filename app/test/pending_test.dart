import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/models.dart';
import 'package:healthvault/pending.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('hv_pending_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<File> sample(String name) async {
    final file = File('${temp.path}/$name');
    await file.writeAsString('report bytes');
    return file;
  }

  test('queues a copy of the file with its profile and language', () async {
    final source = await sample('scan.jpg');
    final item = await addPending(
      source,
      profileId: 'mum',
      language: 'Tamil',
      dir: Directory('${temp.path}/queue'),
    );

    // The picker's temporary file can disappear; the queued copy must not.
    await source.delete();
    expect(await File(item.filePath).readAsString(), 'report bytes');
    expect(item.filePath.endsWith('.jpg'), isTrue);

    final queued = await loadPending();
    expect(queued.single.profileId, 'mum');
    expect(queued.single.language, 'Tamil');
  });

  test('keeps the order reports were queued in', () async {
    final dir = Directory('${temp.path}/queue');
    final a = await addPending(
      await sample('a.pdf'),
      profileId: defaultProfileId,
      language: 'English',
      dir: dir,
    );
    final b = await addPending(
      await sample('b.pdf'),
      profileId: defaultProfileId,
      language: 'English',
      dir: dir,
    );

    expect((await loadPending()).map((p) => p.id), [a.id, b.id]);
  });

  test('removing a queued report deletes its stored file', () async {
    final item = await addPending(
      await sample('scan.png'),
      profileId: defaultProfileId,
      language: 'English',
      dir: Directory('${temp.path}/queue'),
    );

    await removePending(item.id);

    expect(await loadPending(), isEmpty);
    expect(await File(item.filePath).exists(), isFalse);
  });

  test('removing an unknown id changes nothing', () async {
    await addPending(
      await sample('scan.png'),
      profileId: defaultProfileId,
      language: 'English',
      dir: Directory('${temp.path}/queue'),
    );

    await removePending('does-not-exist');

    expect(await loadPending(), hasLength(1));
  });
}
