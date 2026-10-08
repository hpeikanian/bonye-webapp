import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'translations.dart';

class LanguageController extends ChangeNotifier {
  LanguageController({this.storage = const FlutterSecureStorage()});
  final FlutterSecureStorage storage;
  static const preferenceKey = 'bonye.language.v1';
  Locale _locale = const Locale('fa');
  Locale get locale => _locale;
  bool get english => _locale.languageCode == 'en';
  Future<void> restore() async {
    try {
      final saved = await storage.read(key: preferenceKey);
      if (saved == 'en' || saved == 'fa') _locale = Locale(saved!);
    } catch (_) {
      // Storage unavailable: keep the usable Persian default.
    }
  }

  Future<bool> select(String code) async {
    if (!['fa', 'en'].contains(code)) return false;
    _locale = Locale(code);
    notifyListeners();
    try {
      await storage.write(key: preferenceKey, value: code);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final appLanguage = LanguageController();

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope(
      {super.key, required LanguageController controller, required super.child})
      : super(notifier: controller);
  static LanguageController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier ??
      appLanguage;
}

String tr(String value, {bool? english}) {
  if (!(english ?? appLanguage.english)) return value;
  final exact = englishCopy[value];
  if (exact != null) return exact;
  // Only reviewed UI templates are translated. Captured user data is unchanged.
  final templates = <String, String Function(Match)>{
    r'^سلام (.*) 👋$': (m) => 'Hello ${m[1]}',
    r'^غذای مناسب (.*)$': (m) => 'Food for ${m[1]}',
    r'^تولد: (.*)$': (m) => 'Born: ${m[1]}',
    r'^تاریخ اندازه‌گیری: (.*)$': (m) => 'Measured on: ${m[1]}',
    r'^موعد بعدی: (.*)$': (m) => 'Next date: ${m[1]}',
    r'^(.*) از ۹$': (m) => '${m[1]} of 9',
    r'^(.*) وعده$': (m) => '${m[1]} meals',
    r'^موجودی قابل فروش: (.*) بسته$': (m) => 'Available: ${m[1]} packs',
    r'^(.*) امتیاز به کوپن خرید تبدیل شود\؟$': (m) =>
        'Redeem ${m[1]} points for a shopping coupon?',
    r'^درخواست‌ها زیاد شده؛ (.*) ثانیه دیگر تلاش کنید\.$': (m) =>
        'Too many requests. Try again in ${m[1]} seconds.',
    r'^(گربه|سگ) · (.*) کیلوگرم$': (m) => '${englishCopy[m[1]]} · ${m[2]} kg',
    r'^(.*) کیلوگرم$': (m) => '${m[1]} kg',
    r'^(.*) کیلوکالری$': (m) => '${m[1]} kcal',
    r'^(.*) گرم$': (m) => '${m[1]} g',
    r'^(.*) ریال$': (m) => '${m[1]} IRR',
  };
  for (final entry in templates.entries) {
    final match = RegExp(entry.key).firstMatch(value);
    if (match != null) return entry.value(match);
  }
  return value;
}

class AppText extends StatelessWidget {
  const AppText(this.data,
      {super.key,
      this.style,
      this.textAlign,
      this.textDirection,
      this.maxLines,
      this.overflow,
      this.softWrap,
      this.translate = true});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final bool translate;
  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    return Text(translate ? tr(data, english: language.english) : data,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap);
  }
}

class AppInputDecoration extends InputDecoration {
  AppInputDecoration(
      {bool? english,
      String? labelText,
      String? hintText,
      String? helperText,
      super.prefixIcon,
      super.suffixIcon})
      : super(
            labelText:
                labelText == null ? null : tr(labelText, english: english),
            hintText: hintText == null ? null : tr(hintText, english: english),
            helperText:
                helperText == null ? null : tr(helperText, english: english),
            helperMaxLines: 3);
}

class ForwardChevron extends StatelessWidget {
  const ForwardChevron({super.key});
  @override
  Widget build(BuildContext context) =>
      Icon(Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left
          : Icons.chevron_right);
}

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.onDark = false});
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.of(context);
    return PopupMenuButton<String>(
      tooltip: tr('زبان اپ', english: controller.english),
      initialValue: controller.locale.languageCode,
      onSelected: (code) async {
        final saved = await controller.select(code);
        if (!saved && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(controller.english
                  ? 'Language changed for this session; it could not be saved.'
                  : 'زبان برای این بار تغییر کرد؛ ذخیره انتخاب انجام نشد.')));
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'fa', child: Text('فارسی')),
        PopupMenuItem(value: 'en', child: Text('English'))
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.language,
              size: 20, color: onDark ? const Color(0xFFE8D8C7) : null),
          const SizedBox(width: 6),
          Text(controller.english ? 'EN' : 'FA',
              style: TextStyle(color: onDark ? const Color(0xFFE8D8C7) : null))
        ]),
      ),
    );
  }
}
