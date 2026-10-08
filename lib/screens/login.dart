import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/brand.dart';
import '../core/language.dart';
import '../core/widgets.dart';

class LoginPage extends StatefulWidget {
  final BonyeApi api;
  const LoginPage({super.key, required this.api});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final mobile = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController(),
      name = TextEditingController();
  bool busy = false, hidePassword = true;
  String purpose = 'login';
  String? challenge;
  Object? error;
  Timer? cooldownTimer;
  int cooldown = 0;

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void startCooldown() {
    cooldownTimer?.cancel();
    cooldown = 60;
    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => cooldown = 0);
      } else {
        setState(() => cooldown--);
      }
    });
  }

  Future<void> requestCode() async {
    final data = await widget.api.challenge(mobile.text, purpose);
    if (!mounted) return;
    setState(() {
      challenge = data['challenge_id'] as String;
      code.clear();
      startCooldown();
    });
  }

  Future<void> submit() async {
    if (challenge != null) {
      if (!RegExp(r'^\d{6}$').hasMatch(normalizeDigits(code.text.trim()))) {
        throw const FormatException('otp');
      }
      await widget.api.verify(challenge!, code.text,
          name: purpose == 'register' ? name.text.trim() : null,
          password: purpose == 'login' ? null : password.text);
      TextInput.finishAutofillContext();
    } else if (purpose == 'login') {
      await widget.api.login(mobile.text, password.text);
      TextInput.finishAutofillContext();
    } else {
      await requestCode();
    }
  }

  @override
  void dispose() {
    cooldownTimer?.cancel();
    mobile.dispose();
    password.dispose();
    code.dispose();
    name.dispose();
    super.dispose();
  }

  Widget formCard(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AutofillGroup(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                AppText(
                    challenge != null
                        ? 'کد به شماره شما ارسال شد'
                        : purpose == 'login'
                            ? 'خوش آمدید'
                            : purpose == 'register'
                                ? 'عضو باشگاه شوید'
                                : 'رمزتان را بازیابی کنید',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                AppText(
                    challenge != null
                        ? mobile.text
                        : 'همراه کوچکت، اولویت ماست.',
                    style: const TextStyle(color: Color(0xFF627365))),
                const SizedBox(height: 18),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final entry in {
                    'login': 'ورود',
                    'register': 'عضویت',
                    'recovery': 'بازیابی'
                  }.entries)
                    ChoiceChip(
                        label: AppText(entry.value),
                        selected: purpose == entry.key,
                        onSelected: busy
                            ? null
                            : (_) => setState(() {
                                  purpose = entry.key;
                                  challenge = null;
                                  error = null;
                                  code.clear();
                                }),
                        showCheckmark: false),
                ]),
                const SizedBox(height: 18),
                TextField(
                    controller: mobile,
                    enabled: !busy && challenge == null,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: AppInputDecoration(
                        english: LanguageScope.of(context).english,
                        labelText: 'شماره موبایل',
                        hintText: '09xxxxxxxxx',
                        prefixIcon: const Icon(Icons.phone_outlined))),
                if (purpose == 'register') ...[
                  const SizedBox(height: 16),
                  TextField(
                      controller: name,
                      enabled: !busy,
                      autofillHints: const [AutofillHints.name],
                      decoration: AppInputDecoration(
                          english: LanguageScope.of(context).english,
                          labelText: 'نام و نام خانوادگی',
                          prefixIcon: const Icon(Icons.person_outline))),
                ],
                if (purpose != 'login' || challenge == null) ...[
                  const SizedBox(height: 16),
                  TextField(
                      controller: password,
                      enabled: !busy,
                      obscureText: hidePassword,
                      autofillHints: [
                        purpose == 'login'
                            ? AutofillHints.password
                            : AutofillHints.newPassword
                      ],
                      decoration: AppInputDecoration(
                          english: LanguageScope.of(context).english,
                          labelText: purpose == 'login'
                              ? 'رمز عبور'
                              : 'رمز جدید (حداقل ۱۲ کاراکتر)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                              tooltip: tr(hidePassword
                                  ? 'نمایش رمز'
                                  : 'پنهان کردن رمز'),
                              onPressed: () =>
                                  setState(() => hidePassword = !hidePassword),
                              icon: Icon(hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined)))),
                ],
                if (challenge != null) ...[
                  const SizedBox(height: 16),
                  TextField(
                      controller: code,
                      enabled: !busy,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: AppInputDecoration(
                          english: LanguageScope.of(context).english,
                          labelText: 'کد پیامکی',
                          prefixIcon:
                              const Icon(Icons.verified_user_outlined))),
                ],
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppText(
                                error is ApiError
                                    ? (error as ApiError).message
                                    : error is FormatException
                                        ? 'کد شش‌رقمی را وارد کنید.'
                                        : 'ورود انجام نشد.',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer)),
                            if (error is ApiError)
                              ExpansionTile(
                                  title: const AppText(
                                      'اطلاعات خطا برای پشتیبانی'),
                                  tilePadding: EdgeInsets.zero,
                                  children: [
                                    SelectableText(
                                        '${(error as ApiError).code}\n${(error as ApiError).requestId ?? ''}',
                                        textDirection: TextDirection.ltr)
                                  ]),
                          ])),
                ],
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: busy ||
                            (challenge == null &&
                                purpose != 'login' &&
                                cooldown > 0)
                        ? null
                        : () => run(submit),
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : AppText(challenge != null
                            ? 'تأیید و ادامه'
                            : purpose == 'login'
                                ? 'ورود به بنیه'
                                : 'دریافت کد تأیید')),
                if (purpose == 'login' && challenge == null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed:
                          busy || cooldown > 0 ? null : () => run(requestCode),
                      child: const AppText('ورود با کد پیامکی')),
                ],
                if (challenge != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                challenge = null;
                                error = null;
                                code.clear();
                              }),
                      child: const AppText('تغییر شماره یا درخواست کد جدید')),
                ],
                if (cooldown > 0 && challenge == null)
                  Text(
                      appLanguage.english
                          ? 'Request a new code in $cooldown seconds'
                          : 'کد جدید را پس از $cooldown ثانیه درخواست کنید',
                      textAlign: TextAlign.center),
              ])),
        ),
      );

  @override
  Widget build(BuildContext context) {
    LanguageScope.of(context);
    return Scaffold(
        body: SafeArea(
            child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Column(children: [
                                const Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: LanguagePicker()),
                                Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 22, horizontal: 24),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF6B826F),
                                        borderRadius:
                                            BorderRadius.circular(32)),
                                    child: const Column(children: [
                                      BrandLockup(light: true, symbolSize: 60),
                                      SizedBox(height: 18),
                                      AppText('مراقبت، از همین‌جا شروع می‌شود.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: accent,
                                              fontSize: 21,
                                              height: 1.5,
                                              fontWeight: FontWeight.w600)),
                                      SizedBox(height: 8),
                                      AppText('غذا، مراقبت، همراهی',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: accent)),
                                    ])),
                                const SizedBox(height: 20),
                                formCard(context),
                                const SizedBox(height: 20),
                                const AppText(
                                    'حساب شما همان حساب باشگاه مشتریان بنیه است. ثبت‌نام و ورود پیامکی به فعال بودن سرویس پیامک بستگی دارد.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Color(0xFF627365),
                                        fontSize: 12)),
                              ]))),
                    ))));
  }
}
