import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bonye_customer/core/api.dart';
import 'package:bonye_customer/core/podcast_metadata.dart';

void main() {
  test('shared offline audio cannot expose another customer listening history',
      () {
    final downloaded = jsonDecode(jsonEncode(publicPodcastMetadata({
      'id': 12,
      'kind': 'podcast',
      'title': 'تغذیه پت',
      'audio_url': 'https://bonye.pet/audio/12.mp3',
      'user_state': {'favorite': true, 'position_seconds': 215, 'revision': 8},
      'counterparty_id': 42,
    }))) as Json;
    expect(downloaded['id'], 12);
    expect(downloaded['audio_url'], 'https://bonye.pet/audio/12.mp3');
    expect(downloaded.containsKey('user_state'), isFalse);
    expect(downloaded.containsKey('counterparty_id'), isFalse);
  });
  test('old download metadata is sanitized when loaded after account switch',
      () {
    final legacy = <String, dynamic>{
      'id': 2,
      'title': 'آموزش',
      'audio_url': 'https://bonye.pet/2.mp3',
      'user_state': {'completed': true, 'position_seconds': 100}
    };
    expect(publicPodcastMetadata(legacy).keys,
        unorderedEquals(['id', 'title', 'audio_url']));
  });
}
