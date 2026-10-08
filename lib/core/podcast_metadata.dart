import 'api.dart';

/// Downloaded audio is public content. Never persist the previous customer's
/// account state alongside a file that can be viewed after switching accounts.
Json publicPodcastMetadata(Json content) => {
      for (final key in [
        'id',
        'kind',
        'title',
        'excerpt',
        'url',
        'published_at',
        'audio_url',
        'duration_seconds',
        'episode',
      ])
        if (content.containsKey(key)) key: content[key],
    };
