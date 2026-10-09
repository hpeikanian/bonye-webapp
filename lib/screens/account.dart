import '../core/language.dart';
import '../core/design.dart';
import '../core/app_updates.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';

class AccountPage extends StatelessWidget {
  final BonyeApi api;
  const AccountPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) => RemoteView(
      load: () => api.request('GET', '/me'),
      builder: (data, reload) => PageBody(children: [
            const SectionTitle('حساب من', 'اطلاعات و همراهان شما'),
            ProfileHeader(
                name: '${data['name'] ?? tr('حساب من')}',
                subtitle:
                    '${data['mobile'] ?? ''} · ${data['member_no'] ?? ''}'),
            Card(
                child: ListTile(
                    leading: const Icon(Icons.language),
                    title: const AppText('زبان اپ'),
                    trailing: const LanguagePicker())),
            if (AppUpdates.supported)
              ListTile(
                  leading: const Icon(Icons.system_update),
                  title: const AppText('به‌روزرسانی اپ'),
                  trailing: const ForwardChevron(),
                  onTap: () => push(
                      context, UpdatePage(updates: UpdateScope.of(context)))),
            RecordCard(data),
            OutlinedButton(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ProfileForm(api: api, profile: data)));
                  if (context.mounted) {
                    reload();
                  }
                },
                child: const AppText('ویرایش پروفایل')),
            ListTile(
                title: const AppText('آدرس‌های من'),
                trailing: const ForwardChevron(),
                onTap: () => push(context, AddressesPage(api: api))),
            ListTile(
                title: const AppText('تنظیمات پیام‌ها'),
                trailing: const ForwardChevron(),
                onTap: () => push(context, PreferencesPage(api: api))),
            ListTile(
                title: const AppText('نشست‌های فعال'),
                trailing: const ForwardChevron(),
                onTap: () => push(context, SessionsPage(api: api))),
            const AppText(
                'ورود به فروشگاه اینترنتی مستقل است؛ رمز یا توکن اپ به مرورگر منتقل نمی‌شود.'),
            OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await api.logout();
                  } catch (e) {
                    if (context.mounted) {
                      showError(context, e);
                    }
                  }
                },
                icon: const Icon(Icons.logout),
                label: const AppText('خروج از حساب')),
          ]));
}

class ProfileForm extends StatefulWidget {
  final BonyeApi api;
  final Json profile;
  const ProfileForm({super.key, required this.api, required this.profile});
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late TextEditingController name, email;
  bool busy = false;
  String key = operationKey();
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.profile['name'] as String? ?? '');
    email =
        TextEditingController(text: widget.profile['email'] as String? ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('ویرایش پروفایل')),
      body: PageBody(children: [
        TextField(
            controller: name,
            enabled: !busy,
            onChanged: (_) => key = operationKey(),
            decoration: AppInputDecoration(
                english: LanguageScope.of(context).english,
                labelText: 'نام و نام خانوادگی')),
        TextField(
            controller: email,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => key = operationKey(),
            decoration: AppInputDecoration(
                english: LanguageScope.of(context).english,
                labelText: 'ایمیل')),
        FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await widget.api.request('PATCH', '/me',
                          body: {
                            'name': name.text.trim(),
                            'email': email.text.trim().isEmpty
                                ? null
                                : email.text.trim()
                          },
                          key: key);
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
            child: const AppText('ذخیره')),
      ]));
}

class AddressesPage extends StatelessWidget {
  final BonyeApi api;
  const AddressesPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('آدرس‌های من')),
      body: RemoteView(
          load: () => api.request('GET', '/me/addresses?limit=100'),
          builder: (data, reload) => PageBody(children: [
                FilledButton(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => AddressForm(api: api)));
                      if (context.mounted) {
                        reload();
                      }
                    },
                    child: const AppText('افزودن آدرس')),
                ...(data['items'] as List)
                    .cast<Json>()
                    .map((a) => Column(children: [
                          RecordCard(a),
                          OutlinedButton(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            AddressForm(api: api, address: a)));
                                if (context.mounted) {
                                  reload();
                                }
                              },
                              child: const AppText('ویرایش آدرس'))
                        ])),
              ])));
}

class AddressForm extends StatefulWidget {
  final BonyeApi api;
  final Json? address;
  const AddressForm({super.key, required this.api, this.address});
  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  final fields = <String, TextEditingController>{};
  final form = GlobalKey<FormState>();
  bool isDefault = false, busy = false;
  String key = operationKey();
  @override
  void initState() {
    super.initState();
    for (final f in [
      'label',
      'recipient_name',
      'mobile',
      'province',
      'city',
      'address',
      'postal_code'
    ]) {
      fields[f] =
          TextEditingController(text: widget.address?[f] as String? ?? '');
    }
    isDefault = widget.address?['is_default'] == true;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('آدرس')),
      body: Form(
          key: form,
          onChanged: () => key = operationKey(),
          child: PageBody(children: [
            ...fields.entries.map((e) => TextFormField(
                controller: e.value,
                enabled: !busy,
                decoration: AppInputDecoration(
                    english: LanguageScope.of(context).english,
                    labelText: e.key == 'label' ? 'عنوان آدرس' : labels[e.key]),
                validator: (v) => !['label', 'mobile'].contains(e.key) &&
                        (v == null || v.trim().isEmpty)
                    ? tr('این مورد لازم است.')
                    : null)),
            SwitchListTile(
                title: const AppText('آدرس پیش‌فرض'),
                value: isDefault,
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                          isDefault = v;
                          key = operationKey();
                        })),
            FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) {
                          return;
                        }
                        setState(() => busy = true);
                        try {
                          await widget.api.request(
                              widget.address == null ? 'POST' : 'PATCH',
                              widget.address == null
                                  ? '/me/addresses'
                                  : '/me/addresses/${widget.address!['id']}',
                              body: {
                                for (final e in fields.entries)
                                  e.key:
                                      ['mobile', 'postal_code'].contains(e.key)
                                          ? normalizeDigits(e.value.text.trim())
                                          : e.value.text.trim(),
                                'is_default': isDefault
                              },
                              key: key);
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
                child: const AppText('ذخیره آدرس')),
          ])));
}

class PreferencesPage extends StatelessWidget {
  final BonyeApi api;
  const PreferencesPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('تنظیمات پیام‌ها')),
      body: RemoteView(
          load: () => api.request('GET', '/me/preferences'),
          builder: (data, reload) => PageBody(children: [
                const AppText(
                    'اعلان گوشی در API فعلی ارسال نمی‌شود؛ تنظیمات زیر مربوط به پیامک و ایمیل هستند.'),
                ...{
                  'sms_marketing': 'پیامک پیشنهادها و آموزش',
                  'sms_transactional': 'پیامک اطلاع‌رسانی خرید',
                  'email_marketing': 'ایمیل پیشنهادها و آموزش'
                }.entries.map((e) => SwitchListTile(
                    title: AppText(e.value),
                    value: data[e.key] == true,
                    onChanged: (value) async {
                      try {
                        await api.request('PATCH', '/me/preferences', body: {
                          e.key: value,
                          'consent_version': 'bonye-app-v1'
                        });
                        if (context.mounted) {
                          reload();
                        }
                      } catch (error) {
                        if (context.mounted) {
                          showError(context, error);
                        }
                      }
                    })),
              ])));
}

class SessionsPage extends StatelessWidget {
  final BonyeApi api;
  const SessionsPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('نشست‌های فعال')),
        body: RemoteView(
          load: () => api.request('GET', '/auth/sessions'),
          builder: (data, reload) => PageBody(children: [
            ...(data['items'] as List).cast<Json>().map((s) => Card(
                  child: ListTile(
                    title: AppText('${s['device_name']}'),
                    subtitle: AppText('${s['created_at']}'),
                    trailing: IconButton(
                      tooltip: tr('ابطال نشست'),
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        try {
                          await api.request(
                              'DELETE', '/auth/sessions/${s['id']}');
                          if (context.mounted) {
                            reload();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showError(context, e);
                          }
                        }
                      },
                    ),
                  ),
                )),
            OutlinedButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                            title: const AppText('خروج از همه دستگاه‌ها؟'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const AppText('انصراف')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const AppText('خروج')),
                            ],
                          ));
                  if (ok != true) {
                    return;
                  }
                  try {
                    await api.request('POST', '/auth/revoke-all');
                    await api.forget();
                  } catch (e) {
                    if (context.mounted) {
                      showError(context, e);
                    }
                  }
                },
                child: const AppText('خروج از همه دستگاه‌ها')),
          ]),
        ),
      );
}
