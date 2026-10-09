import 'core/language.dart';
import 'core/app_updates.dart';
import 'core/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core/api.dart';
import 'core/widgets.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/pets.dart';
import 'screens/club.dart';
import 'screens/content.dart';
import 'screens/account.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'pet.bonye.customer.audio',
      androidNotificationChannelName: 'bonYe! Podcasts',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/bonye_notification',
    );
  }
  await appLanguage.restore();
  final api = BonyeApi();
  await api.restore();
  runApp(BonyeApp(api: api));
}

class BonyeApp extends StatefulWidget {
  final BonyeApi api;
  const BonyeApp({super.key, required this.api});
  @override
  State<BonyeApp> createState() => _BonyeAppState();
}

class _BonyeAppState extends State<BonyeApp> {
  final navigator = GlobalKey<NavigatorState>();
  late bool wasSignedIn;
  BonyeApi get api => widget.api;
  @override
  void initState() {
    super.initState();
    wasSignedIn = api.signedIn;
    api.addListener(sessionChanged);
  }

  void sessionChanged() {
    if (wasSignedIn && !api.signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          navigator.currentState?.popUntil((route) => route.isFirst);
        }
      });
    }
    wasSignedIn = api.signedIn;
  }

  @override
  void dispose() {
    api.removeListener(sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: appLanguage,
        builder: (context, child) => LanguageScope(
          controller: appLanguage,
          child: MaterialApp(
            navigatorKey: navigator,
            builder: (context, child) =>
                UpdateHost(navigator: navigator, child: child!),
            title: 'bonYe!',
            debugShowCheckedModeBanner: false,
            locale: appLanguage.locale,
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'NotoSansArabic',
              primaryTextTheme: const TextTheme(
                  labelLarge: TextStyle(fontFamily: 'NotoSansArabic')),
              colorScheme: ColorScheme.fromSeed(
                      seedColor: brand, brightness: Brightness.light)
                  .copyWith(
                      primary: brand,
                      secondary: const Color(0xFF6B826F),
                      surface: const Color(0xFFFFFCF6),
                      onSurface: const Color(0xFF283B2D),
                      outline: const Color(0xFF8B9989)),
              scaffoldBackgroundColor: const Color(0xFFF5F0E7),
              textTheme: const TextTheme(
                  headlineSmall: TextStyle(
                      fontSize: 28, height: 1.4, fontWeight: FontWeight.w700),
                  titleLarge: TextStyle(
                      fontSize: 21, height: 1.4, fontWeight: FontWeight.w600),
                  bodyMedium: TextStyle(fontSize: 14, height: 1.6)),
              appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFFF5F0E7),
                  foregroundColor: brand,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  centerTitle: false),
              cardTheme: CardTheme(
                  elevation: 0,
                  color: const Color(0xFFFFFCF6),
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Color(0xFFE4E5DA)))),
              inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFFFAF8F2),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFD6DCCF))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFD6DCCF)))),
              filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      textStyle: const TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontSize: 15,
                          fontWeight: FontWeight.w600))),
              outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)))),
              navigationBarTheme: const NavigationBarThemeData(
                  backgroundColor: Color(0xFFFFFCF6),
                  indicatorColor: Color(0xFFDCE4D8),
                  height: 76),
              listTileTheme: const ListTileThemeData(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  iconColor: brand),
              dividerTheme: const DividerThemeData(color: Color(0xFFDDE2D6)),
            ),
            home: ListenableBuilder(
              listenable: api,
              builder: (context, child) => api.signedIn
                  ? CustomerShell(key: const ValueKey('customer'), api: api)
                  : LoginPage(api: api),
            ),
          ),
        ),
      );
}

class CustomerShell extends StatefulWidget {
  final BonyeApi api;
  const CustomerShell({super.key, required this.api});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final pages = [
      HomePage(
          api: api,
          onPets: () => setState(() => selected = 1),
          onClub: () => setState(() => selected = 2),
          onLearn: () => setState(() => selected = 3)),
      PetsPage(api: api),
      ClubPage(api: api),
      ContentPage(api: api),
      AccountPage(api: api),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BonyeLogo(size: 36),
            SizedBox(width: 10),
            AppText('bonYe!', textDirection: TextDirection.ltr)
          ],
        ),
        actions: [
          const LanguagePicker(),
          IconButton(
            tooltip: tr('محصولات'),
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: () => push(context, ProductsPage(api: api)),
          ),
        ],
      ),
      body: KeyedSubtree(key: ValueKey(selected), child: pages[selected]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => setState(() => selected = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: tr('خانه'),
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            label: tr('پت‌های من'),
          ),
          NavigationDestination(
            icon: Icon(Icons.stars_outlined),
            label: tr('باشگاه'),
          ),
          NavigationDestination(
            icon: Icon(Icons.headphones_outlined),
            label: tr('آموزش'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: tr('حساب من'),
          ),
        ],
      ),
    );
  }
}
