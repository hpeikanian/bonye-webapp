import '../core/language.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';
import 'home.dart';

class PetsPage extends StatelessWidget {
  final BonyeApi api;
  const PetsPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) => RemoteView(
        load: () => api.request('GET', '/pets?limit=100'),
        builder: (data, reload) => PageBody(
          children: [
            const BrandFeature(
                title: 'پت‌های من',
                subtitle: 'هر پت، پرونده و برنامه غذایی خودش را دارد.',
                icon: Icons.pets_outlined),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => PetForm(api: api)),
                );
                if (context.mounted) {
                  reload();
                }
              },
              icon: const Icon(Icons.add),
              label: const AppText('افزودن پت'),
            ),
            ...(data['items'] as List).cast<Json>().map(
                  (pet) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFFDCE4D8),
                          child: Text(pet['species'] == 'cat' ? '🐱' : '🐶',
                              style: const TextStyle(fontSize: 26))),
                      title: AppText('${pet['name']}', translate: false),
                      subtitle: AppText(
                        '${pet['species'] == 'cat' ? 'گربه' : 'سگ'} · ${pet['weight_kg'] ?? '—'} کیلوگرم',
                      ),
                      trailing: const ForwardChevron(),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PetPage(api: api, pet: pet),
                          ),
                        );
                        if (context.mounted) {
                          reload();
                        }
                      },
                    ),
                  ),
                ),
            if ((data['items'] as List).isEmpty)
              const AppText('اولین پتت را معرفی کن تا پرونده‌اش ساخته شود.'),
          ],
        ),
      );
}

class PetForm extends StatefulWidget {
  final BonyeApi api;
  final Json? pet;
  const PetForm({super.key, required this.api, this.pet});
  @override
  State<PetForm> createState() => _PetFormState();
}

class _PetFormState extends State<PetForm> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, breed, weight, conditions;
  late String species, sex, activity, stage;
  String? birth;
  int? bcs;
  bool? neutered;
  bool busy = false;
  String key = operationKey();
  @override
  void initState() {
    super.initState();
    final p = widget.pet ?? <String, dynamic>{};
    name = TextEditingController(text: p['name'] as String? ?? '');
    breed = TextEditingController(text: p['breed'] as String? ?? '');
    weight = TextEditingController(text: '${p['weight_kg'] ?? ''}');
    conditions = TextEditingController(
      text: (p['special_conditions'] as List? ?? []).join('،'),
    );
    species = p['species'] as String? ?? 'dog';
    sex = p['sex'] as String? ?? 'unknown';
    activity = p['activity'] as String? ?? 'normal';
    stage = p['life_stage'] as String? ?? 'adult';
    birth = p['birth_date'] as String?;
    bcs = p['body_condition'] as int?;
    neutered = p['neutered'] as bool?;
  }

  @override
  void dispose() {
    name.dispose();
    breed.dispose();
    weight.dispose();
    conditions.dispose();
    super.dispose();
  }

  Widget dropdown(
    String label,
    String value,
    Map<String, String> values,
    void Function(String) change,
  ) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: AppInputDecoration(
            english: LanguageScope.of(context).english, labelText: label),
        items: values.entries
            .map((e) => DropdownMenuItem(value: e.key, child: AppText(e.value)))
            .toList(),
        onChanged: busy
            ? null
            : (v) => setState(() {
                  change(v!);
                  key = operationKey();
                }),
      );
  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    final payload = <String, dynamic>{
      'name': name.text.trim(),
      'species': species,
      'breed': breed.text.trim(),
      'birth_date': birth,
      'sex': sex,
      'weight_kg': weight.text.isEmpty
          ? null
          : double.parse(normalizeDigits(weight.text)),
      'body_condition': bcs,
      'activity': activity,
      'life_stage': stage,
      'neutered': neutered,
      'special_conditions': conditions.text
          .split(RegExp('[،,\n]'))
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList(),
    };
    try {
      await widget.api.request(
        widget.pet == null ? 'POST' : 'PATCH',
        widget.pet == null ? '/pets' : '/pets/${widget.pet!['id']}',
        body: payload,
        key: key,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: AppText(widget.pet == null ? 'معرفی پت' : 'ویرایش پت')),
        body: Form(
          key: form,
          onChanged: () => key = operationKey(),
          child: AbsorbPointer(
            absorbing: busy,
            child: PageBody(
              children: [
                TextFormField(
                  controller: name,
                  decoration: AppInputDecoration(
                      english: LanguageScope.of(context).english,
                      labelText: 'نام پت'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? tr('نام پت را بنویسید.')
                      : null,
                ),
                dropdown(
                    'نوع پت',
                    species,
                    {
                      'dog': 'سگ',
                      'cat': 'گربه',
                    },
                    (v) => species = v),
                TextFormField(
                  controller: breed,
                  decoration: AppInputDecoration(
                      english: LanguageScope.of(context).english,
                      labelText: 'نژاد'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse(birth ?? '') ?? DateTime.now(),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (date != null && mounted) {
                      setState(() {
                        birth = date.toIso8601String().split('T').first;
                        key = operationKey();
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: AppText(
                      birth == null ? 'انتخاب تاریخ تولد' : 'تولد: $birth'),
                ),
                TextFormField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: AppInputDecoration(
                    english: LanguageScope.of(context).english,
                    labelText: 'وزن فعلی (کیلوگرم)',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return null;
                    }
                    final n = double.tryParse(normalizeDigits(v));
                    return n == null || !n.isFinite || n <= 0 || n > 200
                        ? tr('وزن معتبر وارد کنید.')
                        : null;
                  },
                ),
                dropdown(
                    'جنسیت',
                    sex,
                    {
                      'unknown': 'نامشخص',
                      'male': 'نر',
                      'female': 'ماده',
                    },
                    (v) => sex = v),
                dropdown(
                    'مرحله زندگی',
                    stage,
                    {
                      'young': 'در حال رشد',
                      'adult': 'بالغ',
                      'senior': 'سالمند',
                    },
                    (v) => stage = v),
                dropdown(
                    'فعالیت',
                    activity,
                    {
                      'low': 'کم',
                      'normal': 'معمول',
                      'high': 'زیاد',
                    },
                    (v) => activity = v),
                DropdownButtonFormField<bool>(
                  value: neutered,
                  decoration: AppInputDecoration(
                      english: LanguageScope.of(context).english,
                      labelText: 'عقیم شده؟'),
                  items: const [
                    DropdownMenuItem(value: true, child: AppText('بله')),
                    DropdownMenuItem(value: false, child: AppText('خیر')),
                  ],
                  onChanged: (v) => setState(() {
                    neutered = v;
                    key = operationKey();
                  }),
                ),
                DropdownButtonFormField<int>(
                  value: bcs,
                  decoration: AppInputDecoration(
                    english: LanguageScope.of(context).english,
                    labelText: 'امتیاز وضعیت بدنی (BCS)',
                  ),
                  items: List.generate(
                    9,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: AppText('${i + 1} از ۹'),
                    ),
                  ),
                  onChanged: (v) => setState(() {
                    bcs = v;
                    key = operationKey();
                  }),
                ),
                const AppText(
                  'BCS بهتر است با راهنمایی دامپزشک تعیین شود. مقدار نامعلوم را حدس نزنید.',
                ),
                TextFormField(
                  controller: conditions,
                  maxLines: 3,
                  decoration: AppInputDecoration(
                    english: LanguageScope.of(context).english,
                    labelText: 'بیماری، حساسیت، بارداری یا شرایط خاص',
                    helperText:
                        'موارد را با ویرگول جدا کنید؛ اگر هیچ‌کدام نیست، خالی بگذارید.',
                  ),
                ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: AppText(busy ? 'در حال ذخیره…' : 'ذخیره پرونده'),
                ),
              ],
            ),
          ),
        ),
      );
}

class PetPage extends StatelessWidget {
  final BonyeApi api;
  final Json pet;
  const PetPage({super.key, required this.api, required this.pet});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: AppText('${pet['name']}', translate: false)),
        body: PageBody(
          children: [
            InfoCard(
              'وزن فعلی',
              '${pet['weight_kg'] ?? '—'} کیلوگرم',
              Icons.monitor_weight_outlined,
            ),
            FilledButton(
              onPressed: () => push(context, FeedingPage(api: api, pet: pet)),
              child: const AppText('پیشنهاد غذا و برنامه مصرف'),
            ),
            OutlinedButton(
              onPressed: () => push(context, PetForm(api: api, pet: pet)),
              child: const AppText('ویرایش مشخصات'),
            ),
            OutlinedButton(
              onPressed: () => push(context, WeightForm(api: api, pet: pet)),
              child: const AppText('ثبت وزن جدید'),
            ),
            ListTile(
              title: const AppText('سابقه وزن'),
              trailing: const ForwardChevron(),
              onTap: () => push(
                context,
                RecordsPage(api, '/pets/${pet['id']}/weights', 'سابقه وزن'),
              ),
            ),
            ListTile(
              title: const AppText('برنامه‌های غذایی قبلی'),
              trailing: const ForwardChevron(),
              onTap: () => push(context, PlanHistory(api: api, pet: pet)),
            ),
          ],
        ),
      );
}

class WeightForm extends StatefulWidget {
  final BonyeApi api;
  final Json pet;
  const WeightForm({super.key, required this.api, required this.pet});
  @override
  State<WeightForm> createState() => _WeightFormState();
}

class _WeightFormState extends State<WeightForm> {
  final weight = TextEditingController();
  String date = DateTime.now().toIso8601String().split('T').first;
  String key = operationKey();
  bool busy = false;
  @override
  void dispose() {
    weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('ثبت وزن')),
        body: PageBody(
          children: [
            TextField(
              controller: weight,
              enabled: !busy,
              onChanged: (_) => key = operationKey(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: AppInputDecoration(
                  english: LanguageScope.of(context).english,
                  labelText: 'وزن به کیلوگرم'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(date),
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
                      );
                      if (d != null && mounted) {
                        setState(() {
                          date = d.toIso8601String().split('T').first;
                          key = operationKey();
                        });
                      }
                    },
              child: AppText('تاریخ اندازه‌گیری: $date'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final n = double.tryParse(normalizeDigits(weight.text));
                      if (n == null || !n.isFinite || n <= 0 || n > 200) {
                        showError(
                          context,
                          ApiError('invalid_weight', status: 422),
                        );
                        return;
                      }
                      setState(() => busy = true);
                      try {
                        await widget.api.request(
                          'POST',
                          '/pets/${widget.pet['id']}/weights',
                          body: {'weight_kg': n, 'measured_on': date},
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
              child: const AppText('ثبت اندازه‌گیری'),
            ),
          ],
        ),
      );
}

class FeedingPage extends StatelessWidget {
  final BonyeApi api;
  final Json pet;
  const FeedingPage({super.key, required this.api, required this.pet});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('برنامه غذایی')),
        body: RemoteView(
          load: () => api.request('GET', '/pets/${pet['id']}/suggestions'),
          builder: (data, reload) => PageBody(
            children: [
              SectionTitle(
                'غذای مناسب ${pet['name']}',
                'محاسبه مصرف بر اساس اطلاعات پرونده و انرژی تأییدشده محصول انجام می‌شود.',
              ),
              if (data['status'] != 'available')
                AppText(
                  <String, String>{
                        'veterinary_guidance_required':
                            'شرایط این پت به راهنمایی دامپزشک نیاز دارد؛ مقدار مصرف خودکار ارائه نمی‌شود.',
                        'pet_assessment_required':
                            'برای دریافت برنامه، مشخصات و ارزیابی پت را تکمیل کنید.',
                      }[data['status']] ??
                      'اطلاعات تغذیه‌ای تأییدشده محصول هنوز آماده نیست.',
                ),
              ...(data['items'] as List).cast<Json>().map(
                    (product) => ProductCard(
                      api: api,
                      product: product,
                      onPlan: () => push(
                        context,
                        CreatePlan(api: api, pet: pet, product: product),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
}

class CreatePlan extends StatefulWidget {
  final BonyeApi api;
  final Json pet, product;
  const CreatePlan({
    super.key,
    required this.api,
    required this.pet,
    required this.product,
  });
  @override
  State<CreatePlan> createState() => _CreatePlanState();
}

class _CreatePlanState extends State<CreatePlan> {
  int meals = 2;
  bool busy = false;
  Json? result;
  String key = operationKey();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('مقدار مصرف')),
        body: PageBody(
          children: [
            AppText('${widget.product['name'] ?? widget.product['sku']}'),
            DropdownButtonFormField<int>(
              value: meals,
              decoration: AppInputDecoration(
                  english: LanguageScope.of(context).english,
                  labelText: 'تعداد وعده در روز'),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                    value: i + 1, child: AppText('${i + 1} وعده')),
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                        meals = v!;
                        key = operationKey();
                        result = null;
                      }),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        final r = await widget.api.request(
                          'POST',
                          '/pets/${widget.pet['id']}/feeding-plans',
                          body: {
                            'variant_id': widget.product['variant_id'],
                            'meals_per_day': meals,
                          },
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
              child: AppText(busy ? 'در حال محاسبه…' : 'محاسبه و ذخیره برنامه'),
            ),
            if (result != null) PlanView(result!['plan'] as Json),
            const AppText(
              'این برنامه تخمین نیاز غذایی است. سهم تشویقی و سایر غذاها، تغییر وزن و وضعیت بدنی را با دامپزشک بررسی کنید.',
            ),
          ],
        ),
      );
}

class PlanView extends StatelessWidget {
  final Json plan;
  const PlanView(this.plan, {super.key});
  String range(String field) => (plan[field] as List? ?? [])
      .map((v) => (v as num).toStringAsFixed(0))
      .join(tr(' تا '));
  @override
  Widget build(BuildContext context) => Column(
        children: [
          InfoCard(
            'مصرف روزانه',
            '${range('daily_food_grams_range')} گرم',
            Icons.restaurant,
          ),
          InfoCard(
            'هر وعده',
            '${range('grams_per_meal_range')} گرم',
            Icons.schedule,
          ),
          InfoCard(
            'انرژی روزانه',
            '${range('daily_kcal_range')} کیلوکالری',
            Icons.bolt,
          ),
          AppText('${plan['guidance'] ?? ''}',
              style: const TextStyle(height: 1.8)),
        ],
      );
}

class PlanHistory extends StatelessWidget {
  final BonyeApi api;
  final Json pet;
  const PlanHistory({super.key, required this.api, required this.pet});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('سابقه برنامه غذایی')),
        body: RemoteView(
          load: () =>
              api.request('GET', '/pets/${pet['id']}/feeding-plans?limit=100'),
          builder: (data, reload) => PageBody(
            children: [
              ...(data['items'] as List).cast<Json>().map(
                    (r) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            AppText('${r['created_at'] ?? ''}'),
                            PlanView(r['plan'] as Json),
                          ],
                        ),
                      ),
                    ),
                  ),
              if ((data['items'] as List).isEmpty)
                const AppText('هنوز برنامه‌ای ذخیره نشده است.'),
            ],
          ),
        ),
      );
}
