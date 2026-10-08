import '../core/language.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../core/api.dart';
import '../core/podcast_files.dart';
import '../core/widgets.dart';

class ContentPage extends StatefulWidget {
  final BonyeApi api;
  const ContentPage({super.key, required this.api});
  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  String kind = 'podcasts';
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(children: [
                const Icon(Icons.auto_stories_outlined, color: brand),
                const SizedBox(width: 12),
                Expanded(
                    child: AppText('آموزش و مراقبت',
                        style: Theme.of(context).textTheme.titleLarge))
              ])),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'podcasts', label: AppText('پادکست')),
                ButtonSegment(value: 'articles', label: AppText('آموزش')),
                ButtonSegment(value: 'downloads', label: AppText('دانلودها')),
              ],
              selected: {kind},
              onSelectionChanged: (v) => setState(() => kind = v.first),
            ),
          ),
          Expanded(
            child: kind == 'downloads'
                ? DownloadedPage(api: widget.api)
                : ContentList(key: ValueKey(kind), api: widget.api, kind: kind),
          ),
        ],
      );
}

class ContentList extends StatefulWidget {
  final BonyeApi api;
  final String kind;
  const ContentList({super.key, required this.api, required this.kind});
  @override
  State<ContentList> createState() => _ContentListState();
}

class _ContentListState extends State<ContentList> {
  final List<Json> items = [];
  int? nextPage = 1;
  bool busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.api.request(
        'GET',
        '/content/${widget.kind}?page=${reset ? 1 : nextPage}&limit=25',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (reset) {
          items.clear();
        }
        for (final row in (data['items'] as List).cast<Json>()) {
          if (!items.any((i) => i['id'] == row['id'])) {
            items.add(row);
          }
        }
        nextPage = data['pagination']?['next_page'] as int?;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () => load(reset: true),
        child: PageBody(
          children: [
            SectionTitle(
              widget.kind == 'podcasts' ? 'شنیدنی‌های بنیه' : 'آموزش و مراقبت',
              'برای شناخت بهتر همراه کوچکت.',
            ),
            ...items.map(
              (item) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(
                    widget.kind == 'podcasts'
                        ? Icons.headphones
                        : Icons.menu_book,
                    color: brand,
                  ),
                  title: AppText(plainText(item['title']), translate: false),
                  subtitle: AppText(
                    plainText(item['excerpt']),
                    translate: false,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const ForwardChevron(),
                  onTap: () => push(
                    context,
                    ContentDetail(
                      api: widget.api,
                      kind: widget.kind,
                      id: item['id'] as int,
                    ),
                  ),
                ),
              ),
            ),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (error != null)
              AppText(
                error is ApiError
                    ? (error as ApiError).message
                    : 'دریافت محتوا انجام نشد.',
              ),
            if (!busy && items.isEmpty && error == null)
              const AppText('هنوز محتوایی منتشر نشده است.'),
            if (!busy && (nextPage != null || error != null))
              OutlinedButton(
                onPressed: () => load(reset: items.isEmpty),
                child: AppText(error == null ? 'نمایش بیشتر' : 'تلاش دوباره'),
              ),
          ],
        ),
      );
}

class ContentDetail extends StatelessWidget {
  final BonyeApi api;
  final String kind;
  final int id;
  const ContentDetail({
    super.key,
    required this.api,
    required this.kind,
    required this.id,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: AppText(kind == 'podcasts' ? 'پادکست آموزشی' : 'آموزش')),
        body: RemoteView(
          load: () => api.request('GET', '/content/$kind/$id'),
          builder: (data, reload) => kind == 'podcasts'
              ? PodcastPlayer(
                  key: ValueKey(data['id']),
                  api: api,
                  content: data,
                )
              : PageBody(
                  children: [
                    SectionTitle(
                      plainText(data['title']),
                      plainText(data['published_at']),
                    ),
                    HtmlWidget(
                      data['content_html'] as String? ?? '',
                      onTapUrl: (url) async {
                        try {
                          await externalLink(url);
                          return true;
                        } catch (e) {
                          if (context.mounted) {
                            showError(context, e);
                          }
                          return false;
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await api.request(
                            'PUT',
                            '/content/articles/$id/state',
                            body: {
                              'revision': data['user_state']?['revision'] ?? 0,
                              'favorite':
                                  data['user_state']?['favorite'] != true,
                            },
                          );
                          if (context.mounted) {
                            reload();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showError(context, e);
                          }
                        }
                      },
                      icon: Icon(
                        data['user_state']?['favorite'] == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                      label: const AppText('علاقه‌مندی'),
                    ),
                  ],
                ),
        ),
      );
}

class DownloadedPage extends StatefulWidget {
  final BonyeApi api;
  const DownloadedPage({super.key, required this.api});
  @override
  State<DownloadedPage> createState() => _DownloadedPageState();
}

class _DownloadedPageState extends State<DownloadedPage> {
  late Future<List<Json>> future;
  @override
  void initState() {
    super.initState();
    future = PodcastFiles.list();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
        future: future,
        builder: (context, s) => PageBody(
          children: [
            const SectionTitle(
              'پادکست‌های دانلودشده',
              'پخش فایل‌های ذخیره‌شده بدون اینترنت امکان‌پذیر است.',
            ),
            if (s.hasError)
              const AppText('خواندن فایل‌های دانلودشده انجام نشد.'),
            if (!s.hasData && !s.hasError)
              const Center(child: CircularProgressIndicator()),
            ...?s.data?.map(
              (item) => Card(
                child: ListTile(
                  title: AppText(plainText(item['title']), translate: false),
                  onTap: () => push(
                    context,
                    Scaffold(
                      appBar: AppBar(title: const AppText('پادکست دانلودشده')),
                      body: PodcastPlayer(api: widget.api, content: item),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: tr('حذف دانلود'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await PodcastFiles.remove(item['id'] as int);
                      if (mounted) {
                        setState(() => future = PodcastFiles.list());
                      }
                    },
                  ),
                ),
              ),
            ),
            if (s.hasData && s.data!.isEmpty)
              const AppText('هنوز پادکستی دانلود نکرده‌اید.'),
          ],
        ),
      );
}

class PodcastPlayer extends StatefulWidget {
  final BonyeApi api;
  final Json content;
  const PodcastPlayer({super.key, required this.api, required this.content});
  @override
  State<PodcastPlayer> createState() => _PodcastPlayerState();
}

class _PodcastPlayerState extends State<PodcastPlayer>
    with WidgetsBindingObserver {
  final player = AudioPlayer();
  late Json state;
  Timer? timer;
  bool loading = true, downloading = false, saving = false, downloaded = false;
  String? error, syncMessage;
  Uri? localAudioUri;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = Map<String, dynamic>.from(
      widget.content['user_state'] as Json? ?? {},
    );
    initialize();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (player.playing) {
        save();
      }
    });
  }

  Future<void> initialize() async {
    try {
      try {
        localAudioUri =
            await PodcastFiles.localUri(widget.content['id'] as int);
      } catch (_) {
        // Storage restrictions must not prevent online listening.
        localAudioUri = null;
      }
      downloaded = localAudioUri != null;
      final tag = MediaItem(
        id: '${widget.content['id']}',
        title: plainText(widget.content['title']),
        album: 'آموزش‌های بنیه',
      );
      await player.setAudioSource(
        AudioSource.uri(
          localAudioUri ?? Uri.parse(widget.content['audio_url'] as String),
          tag: tag,
        ),
      );
      final seconds = (state['position_seconds'] as num? ?? 0).toInt();
      if (seconds > 0 && seconds < (player.duration?.inSeconds ?? 0)) {
        await player.seek(Duration(seconds: seconds));
      }
    } catch (_) {
      error = 'پخش صوت ممکن نشد؛ اتصال و فایل پادکست را بررسی کنید.';
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> save({bool? favorite, bool leaving = false}) async {
    if (saving || loading || error != null) {
      return;
    }
    saving = true;
    final duration = player.duration?.inSeconds;
    var position = player.position.inSeconds;
    final declared = (widget.content['duration_seconds'] as num?)?.floor();
    if (declared != null && position > declared) {
      position = declared;
    }
    try {
      final r = await widget.api.request(
        'PUT',
        '/content/podcasts/${widget.content['id']}/state',
        body: {
          'revision': state['revision'] ?? 0,
          'position_seconds': position,
          'completed': duration != null && position >= duration - 2,
          if (favorite != null) 'favorite': favorite,
        },
      );
      state = r;
      syncMessage = null;
    } on ApiError catch (e) {
      syncMessage = 'سابقه شنیدن هنوز همگام نشده است.';
      if (e.status == 409) {
        try {
          final latest = await widget.api.request(
            'GET',
            '/content/podcasts/${widget.content['id']}',
          );
          state = Map<String, dynamic>.from(latest['user_state'] as Json);
          syncMessage =
              'سابقه دستگاه دیگر دریافت شد؛ ذخیره بعدی با ادامه شنیدن انجام می‌شود.';
        } catch (_) {
          /* Keep unsynced message. */
        }
      }
    } finally {
      saving = false;
      if (mounted && !leaving) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused) {
      unawaited(save());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(save(leaving: true).whenComplete(() async {
      await player.dispose();
      PodcastFiles.releaseUri(localAudioUri);
    }));
    super.dispose();
  }

  String clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => PageBody(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: brand,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Icon(Icons.graphic_eq, size: 80, color: accent),
            ),
          ),
          SectionTitle(
            plainText(widget.content['title']),
            plainText(widget.content['excerpt']),
          ),
          if (loading) const Center(child: CircularProgressIndicator()),
          if (error != null) AppText(error!),
          if (!loading && error == null) ...[
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = player.duration ?? Duration.zero;
                return Column(
                  children: [
                    Slider(
                      value: position.inMilliseconds
                          .toDouble()
                          .clamp(0, total.inMilliseconds.toDouble())
                          .toDouble(),
                      max: total.inMilliseconds > 0
                          ? total.inMilliseconds.toDouble()
                          : 1,
                      onChanged: (v) =>
                          player.seek(Duration(milliseconds: v.round())),
                    ),
                    AppText(
                      '${clock(position)} / ${clock(total)}',
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                );
              },
            ),
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: tr('۱۵ ثانیه عقب'),
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => player.seek(
                      Duration(
                        seconds: (player.position.inSeconds - 15)
                            .clamp(0, 6048000)
                            .toInt(),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    iconSize: 42,
                    tooltip: tr(player.playing ? 'توقف' : 'پخش'),
                    icon: Icon(
                      snapshot.data?.playing == true
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: () async {
                      try {
                        if (player.playing) {
                          await player.pause();
                          await save();
                        } else {
                          if (player.processingState ==
                              ProcessingState.completed) {
                            await player.seek(Duration.zero);
                          }
                          unawaited(
                            player.play().catchError((Object e) {
                              if (context.mounted) {
                                showError(context, e);
                              }
                            }),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showError(context, e);
                        }
                      }
                    },
                  ),
                  IconButton(
                    tooltip: tr('۱۵ ثانیه جلو'),
                    icon: const Icon(Icons.forward_10),
                    onPressed: () => player.seek(
                      Duration(
                        seconds: (player.position.inSeconds + 15)
                            .clamp(
                              0,
                              player.duration?.inSeconds ?? 6048000,
                            )
                            .toInt(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DropdownButtonFormField<double>(
              value: player.speed,
              decoration: AppInputDecoration(
                  english: LanguageScope.of(context).english,
                  labelText: 'سرعت پخش'),
              items: [.75, 1.0, 1.25, 1.5, 2.0]
                  .map(
                      (v) => DropdownMenuItem(value: v, child: AppText('$v ×')))
                  .toList(),
              onChanged: (v) async {
                await player.setSpeed(v!);
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () => save(favorite: state['favorite'] != true),
              icon: Icon(
                state['favorite'] == true
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
              label: const AppText('علاقه‌مندی'),
            ),
            FilledButton.icon(
              onPressed: downloading || downloaded
                  ? null
                  : () async {
                      setState(() => downloading = true);
                      try {
                        await PodcastFiles.download(widget.content);
                        if (mounted) {
                          setState(() => downloaded = true);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showError(context, e);
                        }
                      } finally {
                        if (mounted) {
                          setState(() => downloading = false);
                        }
                      }
                    },
              icon: const Icon(Icons.download),
              label: AppText(
                downloaded
                    ? 'ذخیره‌شده برای پخش آفلاین'
                    : downloading
                        ? 'در حال دانلود…'
                        : 'دانلود برای پخش آفلاین',
              ),
            ),
          ],
          if (syncMessage != null) AppText(syncMessage!),
        ],
      );
}
