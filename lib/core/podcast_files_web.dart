import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:http/http.dart' as http;
import 'api.dart';
import 'podcast_metadata.dart';

/// Only public audio and reviewed metadata enter this cache, never user state.
class PodcastFiles {
  static Future<web.Cache> cache() =>
      web.window.caches.open('bonye.public.podcasts.v1').toDart;
  static String key(int id, String suffix) =>
      '${web.window.location.origin}/__bonye_podcasts/$id.$suffix';

  static Future<Uri?> localUri(int id) async {
    final c = await cache();
    final response = await c.match(key(id, 'audio').toJS).toDart;
    if (response == null) return null;
    final blob = await response.blob().toDart;
    return Uri.parse(web.URL.createObjectURL(blob));
  }

  static void releaseUri(Uri? uri) {
    if (uri?.scheme == 'blob') web.URL.revokeObjectURL(uri.toString());
  }

  static Future<List<Json>> list() async {
    final c = await cache();
    final result = <Json>[];
    for (final request in (await c.keys().toDart).toDart) {
      if (!request.url.endsWith('.json')) continue;
      final response = await c.match(request).toDart;
      if (response == null) continue;
      try {
        final item = jsonDecode((await response.text().toDart).toDart) as Json;
        if (await c.match(key(item['id'] as int, 'audio').toJS).toDart !=
            null) {
          result.add(publicPodcastMetadata(item));
        }
      } catch (_) {
        // Ignore incomplete or obsolete public cache entries.
      }
    }
    return result;
  }

  static Future<void> download(Json content) async {
    final url = Uri.tryParse(content['audio_url'] as String? ?? '');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw ApiError('invalid_link');
    }
    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', url))
          .timeout(const Duration(seconds: 30));
      // Safari can reclaim browser storage; limit buffering in browser memory.
      const limit = 64 * 1024 * 1024;
      if (response.statusCode != 200 || (response.contentLength ?? 0) > limit) {
        throw ApiError('download_failed');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 30))) {
        if (bytes.length + chunk.length > limit) {
          throw ApiError('download_too_large');
        }
        bytes.add(chunk);
      }
      final c = await cache();
      final id = content['id'] as int;
      await c
          .put(
              key(id, 'audio').toJS,
              web.Response(
                  bytes.takeBytes().toJS,
                  web.ResponseInit(
                      headers: web.Headers()
                        ..set('Content-Type',
                            response.headers['content-type'] ?? 'audio/mpeg'))))
          .toDart;
      await c
          .put(key(id, 'json').toJS,
              web.Response(jsonEncode(publicPodcastMetadata(content)).toJS))
          .toDart;
    } finally {
      client.close();
    }
  }

  static Future<void> remove(int id) async {
    final c = await cache();
    await c.delete(key(id, 'json').toJS).toDart;
    await c.delete(key(id, 'audio').toJS).toDart;
  }
}
