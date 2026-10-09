import '../core/language.dart';
import '../core/design.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';
import 'reminders.dart';
import 'orders.dart';

class HomePage extends StatelessWidget {
  final BonyeApi api;
  final VoidCallback onPets, onClub, onLearn;
  const HomePage(
      {super.key,
      required this.api,
      required this.onPets,
      required this.onClub,
      required this.onLearn});
  @override
  Widget build(BuildContext context) => RemoteView(
        load: () => api.request('GET', '/me'),
        builder: (data, reload) => PageBody(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppText('سلام ${data['name'] ?? ''} 👋',
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w700, color: brand)),
              const SizedBox(height: 4),
              const AppText('یک قدم کوچک برای حال خوب همراه کوچکت.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF627365))),
            ]),
            CareHero(
              title: 'تغذیه مناسب، زندگی بهتر',
              subtitle: 'غذا، مراقبت، همراهی',
              action: FilledButton.icon(
                  onPressed: onPets,
                  icon: const Icon(Icons.pets_outlined),
                  label: const AppText('برنامه غذایی پت من')),
            ),
            QuickActions(children: [
              QuickAction(
                  title: 'محصولات',
                  icon: Icons.shopping_bag_outlined,
                  onTap: () => push(context, ProductsPage(api: api))),
              QuickAction(
                  title: 'پت‌های من',
                  icon: Icons.pets_outlined,
                  color: peach,
                  onTap: onPets),
              QuickAction(
                  title: 'آموزش',
                  icon: Icons.school_outlined,
                  color: sky,
                  onTap: onLearn),
              QuickAction(
                  title: 'باشگاه',
                  icon: Icons.card_giftcard_outlined,
                  color: rose,
                  onTap: onClub),
            ]),
            HomeCatalog(api: api),
            InfoCard(
              'شماره عضویت',
              '${data['member_no'] ?? '—'}',
              Icons.card_membership,
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shopping_bag_outlined),
                title: const AppText('خریدهای من'),
                subtitle: const AppText('خریدهای سایت و شعب بنیه'),
                trailing: const ForwardChevron(),
                onTap: () => push(
                  context,
                  OrdersPage(api: api),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_none),
                title: const AppText('یادآوری خرید مجدد'),
                onTap: () => push(context, RemindersPage(api: api)),
              ),
            ),
          ],
        ),
      );
}

class ProductsPage extends StatefulWidget {
  final BonyeApi api;
  const ProductsPage({super.key, required this.api});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('محصولات بنیه')),
        body: RemoteView(
            load: () => widget.api.request('GET', '/products?limit=100'),
            builder: (data, reload) {
              final products = (data['items'] as List).cast<Json>();
              final visible = products
                  .where((product) =>
                      '${product['name'] ?? ''} ${product['sku'] ?? ''}'
                          .toLowerCase()
                          .contains(query.toLowerCase().trim()))
                  .toList();
              return PageBody(children: [
                TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: AppInputDecoration(
                        english: LanguageScope.of(context).english,
                        hintText: 'جستجوی محصولات',
                        prefixIcon: const Icon(Icons.search))),
                const SectionTitle('تغذیه سالم، زندگی بهتر',
                    'غذا و مراقبت برای همراه کوچک شما'),
                const AppText(
                    'قیمت‌ها به ریال هستند. قیمت و موجودی نهایی هنگام پرداخت در سایت مشخص می‌شود.'),
                ...visible.map((product) => ProductCard(
                    key: ValueKey(product['variant_id']),
                    api: widget.api,
                    product: product)),
                if (products.isEmpty)
                  const AppText('هنوز محصولی برای نمایش وجود ندارد.'),
                if (products.isNotEmpty && visible.isEmpty)
                  const AppText('محصولی با این جستجو پیدا نشد.'),
              ]);
            }),
      );
}

class ProductCard extends StatefulWidget {
  final BonyeApi api;
  final Json product;
  final VoidCallback? onPlan;
  const ProductCard({
    super.key,
    required this.api,
    required this.product,
    this.onPlan,
  });
  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  BonyeApi get api => widget.api;
  Json get product => widget.product;
  VoidCallback? get onPlan => widget.onPlan;
  bool buying = false;
  String checkoutKey = operationKey();
  int quantity = 1;
  int get quantityLimit {
    final stock = product['sellable_quantity'];
    final limit = product['quick_buy_max_quantity'];
    var maximum = stock is num ? stock.floor().clamp(0, 100) : 100;
    if (limit is num) maximum = maximum.clamp(0, limit.floor().clamp(0, 100));
    return maximum;
  }

  void selectQuantity(int value) {
    if (buying || value < 1 || value > quantityLimit || value == quantity) {
      return;
    }
    setState(() {
      quantity = value;
      checkoutKey = operationKey();
    });
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product['variant_id'] != product['variant_id']) {
      quantity = 1;
      checkoutKey = operationKey();
    } else if (quantity > quantityLimit && quantityLimit > 0) {
      quantity = quantityLimit;
      checkoutKey = operationKey();
    }
  }

  Future<void> buy() async {
    if (buying || quantityLimit < 1) return;
    setState(() => buying = true);
    try {
      final result = await api.request(
          'POST', '/products/${product['variant_id']}/checkout-link',
          body: {'quantity': quantity}, key: checkoutKey);
      final url = Uri.tryParse((result['url'] ?? '').toString());
      if (url == null ||
          url.scheme != 'https' ||
          url.host != Uri.parse(api.base).host ||
          url.port != Uri.parse(api.base).port ||
          url.userInfo.isNotEmpty) {
        throw ApiError('invalid_link');
      }
      await externalLink(
          checkoutLanguageUrl(url, appLanguage.english).toString());
      checkoutKey = operationKey();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => buying = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                    color: const Color(0xFFF2EFE5),
                    borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child:
                            Uri.tryParse((product['image_url'] ?? '').toString())
                                        ?.scheme ==
                                    'https'
                                ? Image.network(product['image_url'] as String,
                                    fit: BoxFit.contain,
                                    semanticLabel: product['name']?.toString(),
                                    errorBuilder: (_, __, ___) => const Center(
                                        child:
                                            SoftIcon(Icons.shopping_bag_outlined,
                                                size: 72)))
                                : const Center(
                                    child: SoftIcon(Icons.shopping_bag_outlined,
                                        size: 72)))),
              ),
              const SizedBox(height: 16),
              AppText(
                '${product['name'] ?? product['sku']}',
                translate: false,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              AppText(
                '${product['pack_quantity'] ?? ''} ${tr((product['pack_unit'] ?? '').toString())}',
              ),
              AppText(money(product['price']?['amount'])),
              AppText(
                  'موجودی قابل فروش: ${product['sellable_quantity'] ?? 0} بسته'),
              const SizedBox(height: 12),
              if (product['quick_buy_available'] == true && quantityLimit > 0)
                Row(children: [
                  const Expanded(child: AppText('تعداد بسته')),
                  IconButton.outlined(
                    tooltip: tr('کاهش تعداد'),
                    onPressed: !buying && quantity > 1
                        ? () => selectQuantity(quantity - 1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                      width: 48, child: Center(child: AppText('$quantity'))),
                  IconButton.outlined(
                    tooltip: tr('افزایش تعداد'),
                    onPressed: !buying && quantity < quantityLimit
                        ? () => selectQuantity(quantity + 1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onPlan != null)
                    FilledButton(
                      onPressed: onPlan,
                      child: const AppText('دریافت برنامه غذایی'),
                    ),
                  FilledButton(
                    onPressed: !buying &&
                            quantityLimit > 0 &&
                            product['quick_buy_available'] == true
                        ? buy
                        : null,
                    child: const AppText('خرید فوری'),
                  ),
                  if (product['quick_buy_available'] != true)
                    const AppText(
                        'خرید فوری هنوز فعال نیست؛ از صفحه سایت خرید کنید.'),
                  OutlinedButton(
                    onPressed: product['purchase_link_available'] != true
                        ? null
                        : () async {
                            try {
                              final result = await api.request(
                                'GET',
                                '/products/${product['variant_id']}/purchase-link',
                              );
                              await externalLink(result['url'] as String);
                            } catch (e) {
                              if (context.mounted) {
                                showError(context, e);
                              }
                            }
                          },
                    child: const AppText('مشاهده در سایت'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

/// Locale is presentation-only; preserve the server's checkout ticket fragment.
Uri checkoutLanguageUrl(Uri url, bool english) => url.replace(queryParameters: {
      ...url.queryParameters,
      'bonye_lang': english ? 'en' : 'fa'
    });

class HomeCatalog extends StatefulWidget {
  const HomeCatalog({super.key, required this.api});
  final BonyeApi api;
  @override
  State<HomeCatalog> createState() => _HomeCatalogState();
}

class _HomeCatalogState extends State<HomeCatalog> {
  late Future<Json> future;
  @override
  void initState() {
    super.initState();
    future = widget.api.request('GET', '/products?limit=6');
  }

  Widget preview(Json product) => SizedBox(
      width: 156,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => push(context, ProductsPage(api: widget.api)),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: Uri.tryParse('${product['image_url'] ?? ''}')
                                    ?.scheme ==
                                'https'
                            ? Image.network(product['image_url'] as String,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                    child:
                                        SoftIcon(Icons.shopping_bag_outlined)))
                            : const Center(
                                child: SoftIcon(Icons.shopping_bag_outlined))),
                    const SizedBox(height: 8),
                    AppText('${product['name'] ?? product['sku'] ?? ''}',
                        translate: false,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    AppText(money(product['price']?['amount']),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ])),
        ),
      ));

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final products = (snapshot.data?['items'] as List? ?? []).cast<Json>();
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(
                    child: AppText('محصولات بنیه',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                TextButton(
                    onPressed: () =>
                        push(context, ProductsPage(api: widget.api)),
                    child: const AppText('مشاهده همه')),
              ]),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: products
                          .take(6)
                          .map((product) => Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(end: 12),
                              child: preview(product)))
                          .toList())),
            ]);
      });
}
