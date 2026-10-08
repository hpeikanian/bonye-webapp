import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:bonye_customer/core/podcast_files_web.dart';

void main() {
  test('web cache lists only audio-backed records and strips account state', () async {
    const id = 987654321;
    final cache = await PodcastFiles.cache();
    await PodcastFiles.remove(id);
    try {
      await cache.put(PodcastFiles.key(id, 'json').toJS,
          web.Response(jsonEncode({
            'id': id,
            'title': 'Public episode',
            'user_state': {'favorite': true, 'position_seconds': 42},
            'customer_id': 99,
          }).toJS)).toDart;
      expect((await PodcastFiles.list()).where((e) => e['id'] == id), isEmpty);
      await cache.put(PodcastFiles.key(id, 'audio').toJS,
          web.Response(Uint8List.fromList([1, 2, 3]).toJS)).toDart;
      final row = (await PodcastFiles.list()).singleWhere((e) => e['id'] == id);
      expect(row['title'], 'Public episode');
      expect(row.containsKey('user_state'), isFalse);
      expect(row.containsKey('customer_id'), isFalse);
      final uri = await PodcastFiles.localUri(id);
      expect(uri?.scheme, 'blob');
      PodcastFiles.releaseUri(uri);
      await PodcastFiles.remove(id);
      expect(await PodcastFiles.localUri(id), isNull);
    } finally {
      await PodcastFiles.remove(id);
    }
  });
}
