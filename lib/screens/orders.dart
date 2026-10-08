import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/language.dart';
import '../core/widgets.dart';

String orderChannel(Json order) {
  final channel =
      (order['purchase_origin'] ?? order['sales_channel'] ?? '').toString();
  if (['app', 'اپ', 'mobile_app'].contains(channel)) return tr('خرید از اپ');
  if (['website', 'woocommerce', 'وب‌سایت', 'سایت', 'online']
      .contains(channel)) {
    return tr('خرید آنلاین از سایت');
  }
  if (['branch', 'شعبه'].contains(channel)) return tr('خرید حضوری از شعبه');
  if (['direct', 'مستقیم', 'store', 'حضوری'].contains(channel)) {
    return tr('خرید حضوری');
  }
  return channel.isEmpty ? tr('کانال خرید مشخص نشده') : channel;
}

class OrdersPage extends StatelessWidget {
  final BonyeApi api;
  const OrdersPage({super.key, required this.api});
  @override
  Widget build(BuildContext context) => RecordsPage(
      api, '/orders', 'خریدهای من',
      recordBuilder: (order) => Card(
              child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: AppText('${order['invoice_no'] ?? '—'}', translate: false),
            subtitle: AppText(
                '${orderChannel(order)}\n${order['branch_name'] ?? ''}\n${order['invoice_date'] ?? ''} · ${tr(money(order['net_amount']))}',
                translate: false),
            isThreeLine: true,
            trailing: const ForwardChevron(),
            onTap: () =>
                push(context, OrderDetail(api: api, id: order['id'] as int)),
          )));
}

class OrderDetail extends StatelessWidget {
  final BonyeApi api;
  final int id;
  const OrderDetail({super.key, required this.api, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('جزئیات خرید')),
      body: RemoteView(
        load: () => api.request('GET', '/orders/$id'),
        builder: (order, reload) => PageBody(children: [
          SectionTitle(orderChannel(order), '${order['branch_name'] ?? ''}',
              translateTitle: false),
          RecordCard(order),
          if (order['branch_name'] == null && order['branch_id'] != null)
            const AppText('نام شعبه هنوز از سرور دریافت نشده است.'),
          const SectionTitle('اقلام خرید', ''),
          ...((order['items'] as List?) ?? []).cast<Json>().map(RecordCard.new),
        ]),
      ));
}
