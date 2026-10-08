import 'language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

const brand = Color(0xFF3F5544);
const accent = Color(0xFFE8D8C7);
String plainText(Object? value) => (value ?? '')
    .toString()
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&#8217;', '’');
String money(Object? amount) => '${amount ?? '0'} ریال';
Future<void> externalLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw ApiError('invalid_link');
  }
  if (!await launchUrl(uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_self' : null)) {
    throw ApiError('link_failed');
  }
}

void showError(BuildContext context, Object error) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: AppText(
        error is ApiError
            ? error.message
            : 'عملیات انجام نشد؛ دوباره تلاش کنید.',
      ),
    ),
  );
}

void push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children
                          .expand((w) => [w, const SizedBox(height: 16)])
                          .toList())))
        ],
      );
}

class SectionTitle extends StatelessWidget {
  final String title, subtitle;
  final bool translateTitle;
  const SectionTitle(this.title, this.subtitle,
      {super.key, this.translateTitle = true});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            translate: translateTitle,
            style: Theme.of(
              context,
            )
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: brand),
          ),
          const SizedBox(height: 8),
          AppText(
            subtitle,
            style: const TextStyle(color: Color(0xFF627365), height: 1.7),
          ),
        ],
      );
}

class InfoCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const InfoCard(this.title, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: brand.withValues(alpha: .08),
                child: Icon(icon, color: brand),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(title),
                    const SizedBox(height: 6),
                    AppText(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class RemoteView extends StatefulWidget {
  final Future<Json> Function() load;
  final Widget Function(Json data, VoidCallback reload) builder;
  const RemoteView({super.key, required this.load, required this.builder});
  @override
  State<RemoteView> createState() => _RemoteViewState();
}

class _RemoteViewState extends State<RemoteView> {
  late Future<Json> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  void reload() {
    final next = widget.load();
    setState(() {
      future = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 48, color: brand),
                    const SizedBox(height: 16),
                    AppText(
                      snapshot.error is ApiError
                          ? (snapshot.error as ApiError).message
                          : 'دریافت اطلاعات انجام نشد.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: reload,
                      child: const AppText('تلاش دوباره'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              reload();
              await future;
            },
            child: widget.builder(snapshot.data!, reload),
          );
        },
      );
}

const labels = <String, String>{
  'branch_name': 'شعبه خرید',
  'returned_quantity': 'تعداد مرجوعی',
  'paid_amount': 'مبلغ پرداخت‌شده',
  'id': 'شناسه',
  'name': 'نام',
  'title': 'عنوان',
  'description': 'شرح',
  'details': 'جزئیات',
  'code': 'کد',
  'status': 'وضعیت',
  'points': 'امتیاز',
  'direction': 'نوع گردش',
  'created_at': 'تاریخ ثبت',
  'expires_at': 'انقضا',
  'invoice_no': 'شماره فاکتور',
  'invoice_date': 'تاریخ فاکتور',
  'total': 'جمع',
  'net_total': 'جمع خالص',
  'grand_total': 'مبلغ نهایی',
  'currency': 'واحد پول',
  'amount': 'مبلغ',
  'value': 'مقدار',
  'type': 'نوع',
  'min_spend': 'حداقل خرید',
  'max_discount': 'سقف تخفیف',
  'used_count': 'تعداد استفاده',
  'usage_limit': 'سقف استفاده',
  'discount': 'تخفیف',
  'quantity': 'تعداد',
  'qty': 'تعداد',
  'sku': 'کد کالا',
  'unit_price': 'قیمت واحد',
  'next_date': 'موعد بعدی',
  'repeat_days': 'فاصله روزها',
  'daily_qty': 'مصرف روزانه',
  'consumption_unit': 'واحد مصرف',
  'rewarded_referrals': 'معرفی‌های موفق',
  'points_per_qualified_referral': 'امتیاز معرفی موفق',
  'qualification_min_spend': 'حداقل خرید واجد شرایط',
  'member_no': 'شماره عضویت',
  'address': 'آدرس',
  'mobile': 'موبایل',
  'email': 'ایمیل',
  'city': 'شهر',
  'postal_code': 'کد پستی',
  'recipient_name': 'گیرنده',
  'recipient_mobile': 'موبایل گیرنده',
  'province': 'استان',
  'line1': 'آدرس',
  'birth_date': 'تولد',
  'point_multiplier': 'ضریب امتیاز',
  'active': 'فعال',
  'reference_type': 'نوع مرجع',
  'reference_id': 'شناسه مرجع',
  'tier': 'سطح عضویت',
  'benefits': 'مزایا',
  'min_points': 'حداقل امتیاز',
  'net_amount': 'مبلغ خالص',
  'sales_channel': 'محل خرید',
  'items': 'اقلام خرید',
  'usage': 'سابقه استفاده',
  'discount_amount': 'مبلغ تخفیف',
  'redeemed_points': 'امتیاز تبدیل‌شده',
  'weight_kg': 'وزن (کیلوگرم)',
  'measured_on': 'تاریخ اندازه‌گیری',
  'label': 'عنوان آدرس',
  'is_default': 'آدرس پیش‌فرض',
  'has_referrer': 'معرف ثبت‌شده',
  'lead_days': 'روزهای یادآوری زودتر',
  'last_purchase_date': 'تاریخ آخرین خرید',
};
String displayValue(dynamic value) {
  if (value == null) {
    return '—';
  }
  if (value is bool) {
    return tr(value ? 'بله' : 'خیر');
  }
  if (value is Map) {
    return value.entries
        .where((e) =>
            labels.containsKey(e.key) &&
            !['id', 'reference_id', 'reference_type'].contains(e.key))
        .map((e) => '${tr(labels[e.key]!)}: ${[
              'name',
              'title',
              'address',
              'line1',
              'email',
              'mobile',
              'recipient_name',
              'sku',
              'code'
            ].contains(e.key) ? plainText(e.value) : displayValue(e.value)}')
        .join('\n');
  }
  if (value is List) {
    return value.map(displayValue).join('\n');
  }
  const names = {
    'IRR': 'ریال',
    'percent': 'درصد',
    'fixed': 'مبلغ ثابت',
    'purchase_coupon': 'کوپن خرید',
    'g': 'گرم',
    'tablet': 'قرص',
    'direct': 'مستقیم',
    'branch': 'شعبه',
    'woocommerce': 'سایت',
    'dog': 'سگ',
    'cat': 'گربه'
  };
  return names.containsKey(value.toString())
      ? tr(names[value.toString()]!)
      : plainText(value);
}

class RecordCard extends StatelessWidget {
  final Json record;
  const RecordCard(this.record, {super.key});
  @override
  Widget build(BuildContext context) {
    LanguageScope.of(context);
    final entries = record.entries
        .where((e) =>
            e.value != null &&
            labels.containsKey(e.key) &&
            !['id', 'reference_id', 'reference_type'].contains(e.key))
        .toList();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1)),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 2,
                              child: AppText(labels[entries[i].key]!,
                                  style: const TextStyle(
                                      color: Color(0xFF627365), fontSize: 13))),
                          const SizedBox(width: 16),
                          Expanded(
                              flex: 3,
                              child: SelectableText(
                                  [
                                    'name',
                                    'title',
                                    'address',
                                    'line1',
                                    'email',
                                    'mobile',
                                    'recipient_name',
                                    'sku',
                                    'code'
                                  ].contains(entries[i].key)
                                      ? plainText(entries[i].value)
                                      : displayValue(entries[i].value),
                                  textDirection: [
                                    'mobile',
                                    'email',
                                    'postal_code',
                                    'code',
                                    'sku'
                                  ].contains(entries[i].key)
                                      ? TextDirection.ltr
                                      : null,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      height: 1.6))),
                        ]),
                  ],
                ])));
  }
}

class RecordsPage extends StatefulWidget {
  final BonyeApi api;
  final String path, title;
  final Widget Function(Json)? recordBuilder;
  const RecordsPage(this.api, this.path, this.title,
      {super.key, this.recordBuilder});
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final List<Json> items = [];
  String? cursor;
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
        '${widget.path}${!reset && cursor != null ? '?cursor=${Uri.encodeQueryComponent(cursor!)}' : ''}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (reset) {
          items.clear();
        }
        final rows = data['items'];
        if (rows is List) {
          for (final row in rows.cast<Json>()) {
            if (!items.any((i) => i['id'] != null && i['id'] == row['id'])) {
              items.add(row);
            }
          }
        } else {
          items.add(data);
        }
        cursor = data['pagination']?['next_cursor'] as String?;
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: AppText(widget.title)),
        body: RefreshIndicator(
          onRefresh: () => load(reset: true),
          child: PageBody(
            children: [
              ...items.map((item) =>
                  widget.recordBuilder?.call(item) ?? RecordCard(item)),
              if (busy) const Center(child: CircularProgressIndicator()),
              if (error != null)
                AppText(
                  error is ApiError
                      ? (error as ApiError).message
                      : 'دریافت اطلاعات انجام نشد.',
                ),
              if (!busy && items.isEmpty && error == null)
                const AppText('هنوز اطلاعاتی ثبت نشده است.'),
              if (!busy && (cursor != null || error != null))
                OutlinedButton(
                  onPressed: () => load(reset: items.isEmpty),
                  child: AppText(error != null ? 'تلاش دوباره' : 'نمایش بیشتر'),
                ),
            ],
          ),
        ),
      );
}

class BrandFeature extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Widget? action;
  const BrandFeature(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      this.action});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
            color: const Color(0xFF6B826F),
            borderRadius: BorderRadius.circular(30)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: accent, size: 30)),
          const SizedBox(height: 20),
          AppText(title,
              style: const TextStyle(
                  color: accent,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.5)),
          const SizedBox(height: 10),
          AppText(subtitle,
              style: const TextStyle(color: Color(0xFFFFFCF6), height: 1.8)),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ]),
      );
}

class ActionTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const ActionTile(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: brand, size: 30),
                    const SizedBox(height: 18),
                    AppText(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    AppText(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF627365), fontSize: 12))
                  ]))));
}
