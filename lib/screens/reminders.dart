import '../core/language.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';

class RemindersPage extends StatelessWidget {
  final BonyeApi api;
  const RemindersPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('یادآوری خرید مجدد')),
        body: RemoteView(
          load: () => api.request('GET', '/reminders?limit=100'),
          builder: (data, reload) => PageBody(
            children: [
              const AppText(
                'یادآوری‌ها در حساب بنیه ثبت می‌شوند؛ ارسال اعلان گوشی هنوز در سرور فعال نیست.',
              ),
              FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReminderForm(api: api),
                    ),
                  );
                  if (context.mounted) {
                    reload();
                  }
                },
                child: const AppText('افزودن یادآوری'),
              ),
              ...(data['items'] as List).cast<Json>().map(
                    (r) => Column(
                      children: [
                        RecordCard(r),
                        if (r['active'] == true || r['active'] == 1)
                          OutlinedButton(
                            onPressed: () async {
                              try {
                                await api.request(
                                  'DELETE',
                                  '/reminders/${r['id']}',
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
                            child: const AppText('غیرفعال‌کردن یادآوری'),
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      );
}

class ReminderForm extends StatefulWidget {
  final BonyeApi api;
  const ReminderForm({super.key, required this.api});
  @override
  State<ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<ReminderForm> {
  final days = TextEditingController(text: '30');
  final quantity = TextEditingController();
  int? pet, product;
  String date = DateTime.now().toIso8601String().split('T').first;
  String unit = 'g', key = operationKey();
  bool busy = false;
  @override
  void dispose() {
    days.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<Json> load() async {
    final result = await Future.wait([
      widget.api.request('GET', '/pets?limit=100'),
      widget.api.request('GET', '/products?limit=100'),
    ]);
    return {'pets': result[0]['items'], 'products': result[1]['items']};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('یادآوری جدید')),
        body: RemoteView(
          load: load,
          builder: (data, reload) {
            final products = <int, Json>{
              for (final p in (data['products'] as List).cast<Json>())
                p['product_id'] as int: p,
            };
            return PageBody(
              children: [
                DropdownButtonFormField<int>(
                  value: pet,
                  decoration: AppInputDecoration(
                      english: LanguageScope.of(context).english,
                      labelText: 'پت (اختیاری)'),
                  items: (data['pets'] as List)
                      .cast<Json>()
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['id'] as int,
                          child: AppText('${p['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                            pet = v;
                            key = operationKey();
                          }),
                ),
                DropdownButtonFormField<int>(
                  value: product,
                  decoration: AppInputDecoration(
                      english: LanguageScope.of(context).english,
                      labelText: 'محصول (اختیاری)'),
                  items: products.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: AppText('${e.value['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                            product = v;
                            key = operationKey();
                          }),
                ),
                TextField(
                  controller: days,
                  enabled: !busy,
                  onChanged: (_) => key = operationKey(),
                  keyboardType: TextInputType.number,
                  decoration: AppInputDecoration(
                      english: LanguageScope.of(context).english,
                      labelText: 'فاصله خرید (روز)'),
                ),
                TextField(
                  controller: quantity,
                  enabled: !busy,
                  onChanged: (_) => key = operationKey(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: AppInputDecoration(
                    english: LanguageScope.of(context).english,
                    labelText: 'مصرف روزانه (اختیاری)',
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: AppInputDecoration(
                      english: LanguageScope.of(context).english,
                      labelText: 'واحد مصرف'),
                  items: const [
                    DropdownMenuItem(value: 'g', child: AppText('گرم')),
                    DropdownMenuItem(value: 'tablet', child: AppText('قرص')),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                            unit = v!;
                            key = operationKey();
                          }),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.parse(date),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (d != null && mounted) {
                            setState(() {
                              date = d.toIso8601String().split('T').first;
                              key = operationKey();
                            });
                          }
                        },
                  child: AppText('موعد بعدی: $date'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final repeat =
                              int.tryParse(normalizeDigits(days.text));
                          final daily = quantity.text.isEmpty
                              ? null
                              : double.tryParse(
                                  normalizeDigits(quantity.text),
                                );
                          if (repeat == null ||
                              repeat < 1 ||
                              repeat > 3650 ||
                              (quantity.text.isNotEmpty &&
                                  (daily == null ||
                                      !daily.isFinite ||
                                      daily <= 0))) {
                            showError(
                              context,
                              ApiError('invalid_input', status: 422),
                            );
                            return;
                          }
                          setState(() => busy = true);
                          try {
                            await widget.api.request(
                              'POST',
                              '/reminders',
                              body: {
                                'repeat_days': repeat,
                                'next_date': date,
                                if (pet != null) 'pet_id': pet,
                                if (product != null) 'product_id': product,
                                'daily_qty': daily,
                                'consumption_unit': unit,
                              },
                              key: key,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
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
                  child: const AppText('ثبت یادآوری'),
                ),
              ],
            );
          },
        ),
      );
}
