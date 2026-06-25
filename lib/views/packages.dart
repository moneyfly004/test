import 'dart:async';
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purchase(Map<String, dynamic> pkg) async {
    // Show payment method dialog
    final method = await showDialog<String>(
      context: context,
      builder: (_) => _PaymentMethodDialog(packageName: pkg['name'] as String? ?? 'Package'),
    );
    if (method == null) return;

    try {
      final order = await ApiService().createOrder(pkg['id'] as String? ?? '');
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PaymentQrDialog(
          order: order,
          paymentMethod: method,
        ),
      );
      await _loadPackages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CommonScaffold(
      title: 'Package Purchase',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPackages,
              child: ListView.builder(
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
                            pkg['name'] as String? ?? 'Package',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pkg['description'] as String? ?? '',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '¥${pkg['price'] ?? pkg['amount'] ?? ''}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                              ),
                              FilledButton(
                                onPressed: () => _purchase(pkg),
                                child: const Text('Buy Now'),
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
  String _selected = 'alipay';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Purchase ${widget.packageName}', maxLines: 1, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Radio<String>(value: 'alipay', groupValue: _selected, onChanged: (v) => setState(() => _selected = v!)),
            title: const Text('Alipay'),
            trailing: const Icon(Icons.payment),
            onTap: () => setState(() => _selected = 'alipay'),
          ),
          ListTile(
            leading: Radio<String>(value: 'wechat', groupValue: _selected, onChanged: (v) => setState(() => _selected = v!)),
            title: const Text('WeChat Pay'),
            trailing: const Icon(Icons.qr_code),
            onTap: () => setState(() => _selected = 'wechat'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Continue')),
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
  int _secondsLeft = 900; // 15 minutes

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startCountdown();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final orderId = widget.order['order_id'] as String? ?? widget.order['id'] as String? ?? '';
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
    final qrUrl = widget.order['qr_code'] as String?;
    final amount = widget.order['amount'] ?? widget.order['price'] ?? '';
    final orderId = widget.order['order_id'] ?? widget.order['id'] ?? '';

    return AlertDialog(
      title: const Text('Complete Payment'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_paid)
              const Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 64),
                  SizedBox(height: 8),
                  Text('Payment Successful!'),
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
              Text('Amount: ¥$amount', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Order: $orderId', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 8),
              Text('Expires in $_timeLeft', style: TextStyle(color: _secondsLeft < 60 ? Colors.red : null)),
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              const Text('Waiting for payment...', style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
