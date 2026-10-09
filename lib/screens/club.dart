import '../core/language.dart';
import '../core/design.dart';
import 'home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/widgets.dart';
import 'reminders.dart';
import 'orders.dart';

class ClubPage extends StatelessWidget {
  final BonyeApi api;
  const ClubPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) => RemoteView(
        load: () async {
          final records = await Future.wait(
              [api.request('GET', '/club'), api.request('GET', '/me')]);
          return {...records[0], 'member': records[1]};
        },
        builder: (data, reload) => PageBody(
          children: [
            const SectionTitle('باشگاه بنیه',
                'خرید، امتیاز و مزایای شما؛ یک حساب مشترک در سایت و شعب.'),
            Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF274C3B), brand]),
                    borderRadius: BorderRadius.circular(28)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('bonYe!',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                color: accent,
                                fontFamily: 'Cormorant',
                                fontSize: 32,
                                fontWeight: FontWeight.w900)),
                        const Spacer(),
                        const Icon(Icons.workspace_premium_outlined,
                            color: accent, size: 36)
                      ]),
                      const SizedBox(height: 20),
                      AppText('${data['tier']?['name'] ?? tr('عضو باشگاه')}',
                          translate: false,
                          style: const TextStyle(
                              color: accent,
                              fontSize: 17,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      AppText('${data['member']?['name'] ?? ''}',
                          translate: false,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      AppText('${data['member']?['member_no'] ?? ''}',
                          translate: false,
                          style: const TextStyle(color: accent, fontSize: 12)),
                      const SizedBox(height: 12),
                      const AppText('امتیاز شما',
                          style: TextStyle(color: Color(0xFFE4EBDF))),
                      Text('${data['points'] ?? 0}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700)),
                    ])),
            if (data['tier']?['next_threshold'] is num &&
                (data['tier']['next_threshold'] as num) > 0) ...[
              LinearProgressIndicator(
                  value: ((data['points'] as num? ?? 0) /
                          (data['tier']['next_threshold'] as num))
                      .clamp(0.0, 1.0)
                      .toDouble(),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8)),
              AppText(
                  '${data['points'] ?? 0} / ${data['tier']['next_threshold']}',
                  translate: false),
            ],
            QuickActions(children: [
              QuickAction(
                  title: 'گردش امتیاز',
                  icon: Icons.stars_outlined,
                  color: peach,
                  onTap: () => push(
                      context,
                      RecordsPage(
                          api, '/club/points/transactions', 'گردش امتیاز'))),
              QuickAction(
                  title: 'پاداش‌ها',
                  icon: Icons.card_giftcard_outlined,
                  onTap: () => push(
                      context, RecordsPage(api, '/club/rewards', 'پاداش‌ها'))),
              QuickAction(
                  title: 'معرفی دوستان',
                  icon: Icons.people_outline,
                  color: sky,
                  onTap: () => push(context, ReferralPage(api: api))),
              QuickAction(
                  title: 'کوپن‌های من',
                  icon: Icons.confirmation_number_outlined,
                  color: rose,
                  onTap: () => push(context,
                      RecordsPage(api, '/club/coupons', 'کوپن‌های من'))),
            ]),
            CareHero(
                title: 'غذا، مراقبت، همراهی',
                subtitle: '',
                action: FilledButton(
                    onPressed: () => push(context, ProductsPage(api: api)),
                    child: const AppText('مشاهده محصولات'))),
            InfoCard(
              'اعتبار خرید',
              money(data['credit']?['amount']),
              Icons.confirmation_number_outlined,
            ),
            const AppText(
              'اعتبار باشگاه کوپن خرید است و امکان برداشت نقدی ندارد.',
            ),
            ...<String, String>{
              '/club/tier': 'سطح و مزایا',
              '/club/points/transactions': 'گردش امتیاز',
              '/club/credit/transactions': 'گردش اعتبار',
              '/club/coupons': 'کوپن‌های من',
              '/club/rewards': 'پاداش‌ها',
              '/club/activity': 'فعالیت‌های باشگاه',
              '/orders': 'خریدهای من',
              '/reminders': 'یادآوری خرید مجدد',
            }.entries.map(
                  (e) => Card(
                    child: ListTile(
                      title: AppText(e.value),
                      trailing: const ForwardChevron(),
                      onTap: () => push(
                        context,
                        e.key == '/reminders'
                            ? RemindersPage(api: api)
                            : e.key == '/orders'
                                ? OrdersPage(api: api)
                                : RecordsPage(api, e.key, e.value),
                      ),
                    ),
                  ),
                ),
            FilledButton(
              onPressed: () => push(context, ConvertPoints(api: api)),
              child: const AppText('تبدیل امتیاز به اعتبار خرید'),
            ),
            OutlinedButton(
              onPressed: () => push(context, ReferralPage(api: api)),
              child: const AppText('معرفی دوستان'),
            ),
          ],
        ),
      );
}

class ConvertPoints extends StatefulWidget {
  final BonyeApi api;
  const ConvertPoints({super.key, required this.api});
  @override
  State<ConvertPoints> createState() => _ConvertPointsState();
}

class _ConvertPointsState extends State<ConvertPoints> {
  final points = TextEditingController();
  bool busy = false;
  String key = operationKey();
  Json? result;
  @override
  void dispose() {
    points.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('تبدیل امتیاز')),
        body: PageBody(
          children: [
            const AppText(
              'نرخ تبدیل و شرایط کوپن با قوانین فعلی باشگاه تعیین می‌شود.',
            ),
            TextField(
              controller: points,
              enabled: !busy,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                key = operationKey();
                result = null;
              },
              decoration: AppInputDecoration(
                  english: LanguageScope.of(context).english,
                  labelText: 'تعداد امتیاز'),
            ),
            FilledButton(
              onPressed: busy || result != null
                  ? null
                  : () async {
                      final n = int.tryParse(normalizeDigits(points.text));
                      if (n == null || n < 1) {
                        showError(
                          context,
                          ApiError('invalid_points', status: 422),
                        );
                        return;
                      }
                      final approved = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const AppText('تبدیل امتیاز'),
                          content: AppText('$n امتیاز به کوپن خرید تبدیل شود؟'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const AppText('انصراف'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const AppText('تبدیل'),
                            ),
                          ],
                        ),
                      );
                      if (approved != true || !mounted) {
                        return;
                      }
                      setState(() => busy = true);
                      try {
                        final r = await widget.api.request(
                          'POST',
                          '/club/credit/convert',
                          body: {'points': n},
                          key: key,
                        );
                        if (mounted) {
                          setState(() => result = r);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showError(context, e);
                        }
                      } finally {
                        if (mounted) {
                          setState(() => busy = false);
                        }
                      }
                    },
              child: const AppText('تبدیل به کوپن'),
            ),
            if (result != null) RecordCard(result!),
          ],
        ),
      );
}

class ReferralPage extends StatefulWidget {
  final BonyeApi api;
  const ReferralPage({super.key, required this.api});
  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final code = TextEditingController();
  bool busy = false;
  String joinKey = operationKey();
  final createKey = operationKey();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('معرفی دوستان')),
        body: RemoteView(
          load: () => widget.api.request('GET', '/club/referrals'),
          builder: (data, reload) => PageBody(
            children: [
              RecordCard(data),
              if (data['code'] != null)
                OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: data['code'] as String),
                  ),
                  icon: const Icon(Icons.copy),
                  label: const AppText('کپی کد معرفی'),
                ),
              if (data['code'] == null)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await widget.api.request(
                              'POST',
                              '/club/referrals/code',
                              key: createKey,
                            );
                            if (mounted) {
                              reload();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showError(context, e);
                            }
                          } finally {
                            if (mounted) {
                              setState(() => busy = false);
                            }
                          }
                        },
                  child: const AppText('دریافت کد معرفی'),
                ),
              if (data['has_referrer'] != true) ...[
                TextField(
                  controller: code,
                  enabled: !busy,
                  onChanged: (_) => joinKey = operationKey(),
                  decoration: AppInputDecoration(
                    english: LanguageScope.of(context).english,
                    labelText: 'کد کسی که شما را معرفی کرده',
                  ),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await widget.api.request(
                              'POST',
                              '/club/referrals/join',
                              body: {'code': code.text.trim()},
                              key: joinKey,
                            );
                            if (mounted) {
                              reload();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showError(context, e);
                            }
                          } finally {
                            if (mounted) {
                              setState(() => busy = false);
                            }
                          }
                        },
                  child: const AppText('ثبت معرف'),
                ),
              ],
            ],
          ),
        ),
      );
}
