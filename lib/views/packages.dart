import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/services/services.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';

class PackagesView extends StatefulWidget {
  const PackagesView({super.key});

  @override
  State<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends State<PackagesView> {
  List<dynamic> _packages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _loading = true);
    try {
      final packages = await ApiService().getPackages();
      if (mounted) setState(() => _packages = packages);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purchase(Map<String, dynamic> pkg) async {
    final method = await showDialog<String>(
      context: context,
      builder: (_) => _PaymentMethodDialog(
        packageName: _packageName(pkg),
      ),
    );
    if (method == null) return;

    try {
      final order = await ApiService().createOrder(
        pkg['id']?.toString() ?? '',
        method,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PaymentQrDialog(order: order, paymentMethod: method),
      );
      await _loadPackages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  String _packageName(Map<String, dynamic> pkg) {
    return (pkg['name'] ??
            pkg['title'] ??
            pkg['package_name'] ??
            pkg['subject'] ??
            context.appLocalizations.packages)
        .toString();
  }

  String _packageDescription(Map<String, dynamic> pkg) {
    return (pkg['description'] ?? pkg['desc'] ?? pkg['content'] ?? '')
        .toString();
  }

  String _packagePrice(Map<String, dynamic> pkg) {
    final price =
        pkg['price'] ?? pkg['amount'] ?? pkg['sale_price'] ?? pkg['money'];
    if (price == null || price.toString().isEmpty) return '';
    return '¥$price';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CommonScaffold(
      title: context.appLocalizations.packages,
      actions: [
        IconButton(
          tooltip: context.appLocalizations.update,
          onPressed: _loading ? null : _loadPackages,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPackages,
              child: _packages.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.45,
                          child: Center(
                            child: Text(context.appLocalizations.noData),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _packages.length,
                      itemBuilder: (_, i) {
                        final pkg = _packages[i] as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _packageName(pkg),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _packageDescription(pkg),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: cs.outline),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _packagePrice(pkg),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: cs.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    FilledButton(
                                      onPressed: () => _purchase(pkg),
                                      child: Text(context.appLocalizations.go),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _PaymentMethodDialog extends StatefulWidget {
  final String packageName;

  const _PaymentMethodDialog({required this.packageName});

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  List<dynamic> _methods = [];
  String? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    try {
      final methods = await ApiService().getPaymentMethods();
      if (mounted) {
        setState(() {
          _methods = methods;
          _selected = methods.isNotEmpty
              ? ((methods.first as Map)['key'] ??
                      (methods.first as Map)['pay_type'] ??
                      (methods.first as Map)['id'])
                  .toString()
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return AlertDialog(
      title: Text(
        '${appLocalizations.go} ${widget.packageName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: _loading
          ? const SizedBox(
              width: 260,
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final raw in _methods)
                  Builder(
                    builder: (_) {
                      final method = raw as Map;
                      final key =
                          (method['key'] ?? method['pay_type'] ?? method['id'])
                              .toString();
                      final name = (method['name'] ?? key).toString();
                      return ListTile(
                        leading: Icon(
                          key == _selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: key == _selected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.qr_code_2),
                        onTap: () => setState(() => _selected = key),
                      );
                    },
                  ),
                if (_methods.isEmpty) Text(appLocalizations.noData),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: Text(appLocalizations.confirm),
        ),
      ],
    );
  }
}

class _PaymentQrDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final String paymentMethod;

  const _PaymentQrDialog({required this.order, required this.paymentMethod});

  @override
  State<_PaymentQrDialog> createState() => _PaymentQrDialogState();
}

class _PaymentQrDialogState extends State<_PaymentQrDialog> {
  Timer? _pollTimer;
  bool _paid = false;
  int _secondsLeft = 900;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startCountdown();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final orderId = (widget.order['order_no'] ??
                widget.order['order_id'] ??
                widget.order['id'] ??
                '')
            .toString();
        final status = await ApiService().getOrderStatus(orderId);
        if (status['status'] == 'paid' || status['paid'] == true) {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() => _paid = true);
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) Navigator.of(context).pop(true);
          }
        }
      } catch (_) {}
    });
  }

  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _secondsLeft <= 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted) Navigator.of(context).pop(false);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _timeLeft {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final qrValue = widget.order['payment_qr_code'] ??
        widget.order['payment_url'] ??
        widget.order['qr_code'];
    final qrUrl = qrValue?.toString();
    final amount = widget.order['amount'] ?? widget.order['price'] ?? '';
    final orderId = widget.order['order_no'] ??
        widget.order['order_id'] ??
        widget.order['id'] ??
        '';

    return AlertDialog(
      title: Text(appLocalizations.confirm),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_paid)
              Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 8),
                  Text(appLocalizations.update),
                ],
              )
            else ...[
              Container(
                width: 200,
                height: 200,
                color: Colors.grey[200],
                child: qrUrl != null
                    ? Image.network(qrUrl, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.qr_code, size: 80)),
              ),
              const SizedBox(height: 12),
              Text(
                'Amount: ¥$amount',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Order: $orderId',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),
              Text(
                'Expires in $_timeLeft',
                style: TextStyle(color: _secondsLeft < 60 ? Colors.red : null),
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(
                appLocalizations.loading,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(appLocalizations.cancel),
        ),
      ],
    );
  }
}
