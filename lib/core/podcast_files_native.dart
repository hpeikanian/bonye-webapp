import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'podcast_metadata.dart';

class PodcastFiles {
  static Future<Directory> directory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/podcasts')..createSync(recursive: true);
  }

  static Future<File> audio(int id) async =>
      File('${(await directory()).path}/$id.audio');
  static Future<Uri?> localUri(int id) async {
    final file = await audio(id);
    return await file.exists() ? Uri.file(file.path) : null;
  }

  static void releaseUri(Uri? uri) {}

  static Future<List<Json>> list() async {
    final d = await directory();
    final result = <Json>[];
    for (final f in d.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.json'),
        )) {
      try {
        final item = jsonDecode(await f.readAsString()) as Json;
        if (await (await audio(item['id'] as int)).exists()) {
          result.add(publicPodcastMetadata(item));
        }
      } catch (_) {
        /* Ignore incomplete metadata. */
      }
    }
    return result;
  }

  static Future<void> download(Json content) async {
    final id = content['id'] as int;
    final url = Uri.parse(content['audio_url'] as String);
    if (url.scheme != 'https') {
      throw ApiError('invalid_link');
    }
    final target = await audio(id);
    final temp = File('${target.path}.part');
    final client = http.Client();
    IOSink? sink;
    try {
      final response = await client
          .send(http.Request('GET', url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > 250 * 1024 * 1024) {
        throw ApiError('download_failed');
      }
      sink = temp.openWrite();
      var total = 0;
      await for (final bytes in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        total += bytes.length;
        if (total > 250 * 1024 * 1024) {
          throw ApiError('download_too_large');
        }
        sink.add(bytes);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      await temp.rename(target.path);
      await File(
        '${(await directory()).path}/$id.json',
      ).writeAsString(jsonEncode(publicPodcastMetadata(content)));
    } finally {
      await sink?.close();
      client.close();
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }

  static Future<void> remove(int id) async {
    final f = await audio(id);
    if (await f.exists()) {
      await f.delete();
    }
    final meta = File('${(await directory()).path}/$id.json');
    if (await meta.exists()) {
      await meta.delete();
    }
  }
}
