import 'dart:async';

import 'package:fl_clash/services/services.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PackagesView extends StatefulWidget {
  const PackagesView({super.key});

  @override
  State<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends State<PackagesView> {
  List<dynamic> _packages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final packages = await ApiService().getPackages();
      if (mounted) setState(() => _packages = packages);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purchase(Map<String, dynamic> pkg) async {
    final method = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _PaymentMethodDialog(
        packageName: _name(pkg),
        dialogContext: dialogContext,
      ),
    );
    if (method == null || !mounted) return;
    try {
      final order = await ApiService().createOrder(
        pkg['id']?.toString() ?? '',
        method,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            _PaymentQrDialog(order: order, dialogContext: dialogContext),
      );
      await _loadPackages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _name(Map<String, dynamic> pkg) =>
      (pkg['name'] ?? pkg['title'] ?? pkg['package_name'] ?? pkg['subject'] ?? '套餐')
          .toString();

  String _desc(Map<String, dynamic> pkg) =>
      (pkg['description'] ?? pkg['desc'] ?? pkg['content'] ?? '').toString();

  String _price(Map<String, dynamic> pkg) {
    final p = pkg['price'] ?? pkg['amount'] ?? pkg['sale_price'] ?? pkg['money'];
    if (p == null || p.toString().isEmpty) return '';
    return '¥$p';
  }

  String _duration(Map<String, dynamic> pkg) {
    final d = pkg['duration'] ?? pkg['period'] ?? pkg['days'];
    if (d == null) return '';
    return '$d天';
  }

  String _traffic(Map<String, dynamic> pkg) {
    final t = pkg['traffic'] ?? pkg['bandwidth'] ?? pkg['flow'];
    if (t == null) return '';
    return '$t GB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CommonScaffold(
      title: '套餐购买',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: _loading ? null : _loadPackages,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: cs.error),
                        const SizedBox(height: 16),
                        Text('加载失败', style: TextStyle(color: cs.error)),
                        const SizedBox(height: 8),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadPackages,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPackages,
                  child: _packages.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.45,
                              child: const Center(child: Text('暂无可用套餐')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _packages.length,
                          itemBuilder: (_, i) {
                            final pkg =
                                _packages[i] as Map<String, dynamic>;
                            final duration = _duration(pkg);
                            final traffic = _traffic(pkg);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _name(pkg),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    if (_desc(pkg).isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _desc(pkg),
                                        style: TextStyle(
                                            fontSize: 13, color: cs.outline),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (duration.isNotEmpty ||
                                        traffic.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (duration.isNotEmpty)
                                            _Tag(
                                              icon: Icons.access_time,
                                              label: duration,
                                            ),
                                          if (traffic.isNotEmpty)
                                            _Tag(
                                              icon: Icons.data_usage,
                                              label: traffic,
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _price(pkg),
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
                                          child: const Text('立即购买'),
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

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer)),
        ],
      ),
    );
  }
}

class _PaymentMethodDialog extends StatefulWidget {
  final String packageName;
  final BuildContext dialogContext;

  const _PaymentMethodDialog(
      {required this.packageName, required this.dialogContext});

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '购买「${widget.packageName}」',
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
                if (_methods.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('暂无可用支付方式'),
                  )
                else
                  for (final raw in _methods)
                    Builder(builder: (_) {
                      final m = raw as Map;
                      final key = (m['key'] ?? m['pay_type'] ?? m['id'])
                          .toString();
                      final name = (m['name'] ?? key).toString();
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          key == _selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: key == _selected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(name),
                        trailing: const Icon(Icons.qr_code_2),
                        onTap: () => setState(() => _selected = key),
                      );
                    }),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(widget.dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(widget.dialogContext).pop(_selected),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _PaymentQrDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final BuildContext dialogContext;

  const _PaymentQrDialog(
      {required this.order, required this.dialogContext});

  @override
  State<_PaymentQrDialog> createState() => _PaymentQrDialogState();
}

class _PaymentQrDialogState extends State<_PaymentQrDialog> {
  Timer? _pollTimer;
  Timer? _countdownTimer;
  bool _paid = false;
  int _secondsLeft = 900;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startCountdown();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final orderId = (widget.order['order_no'] ??
                widget.order['order_id'] ??
                widget.order['id'] ??
                '')
            .toString();
        if (orderId.isEmpty) return;
        final status = await ApiService().getOrderStatus(orderId);
        if (status['status'] == 'paid' || status['paid'] == true) {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() => _paid = true);
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) Navigator.of(widget.dialogContext).pop(true);
          }
        }
      } catch (_) {}
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _secondsLeft <= 0) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _countdownTimer?.cancel();
        if (mounted) Navigator.of(widget.dialogContext).pop(false);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _timeLeft {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl = (widget.order['payment_qr_code'] ??
            widget.order['payment_url'] ??
            widget.order['qr_code'])
        ?.toString();
    final amount =
        (widget.order['amount'] ?? widget.order['price'] ?? '').toString();
    final orderId = (widget.order['order_no'] ??
            widget.order['order_id'] ??
            widget.order['id'] ??
            '')
        .toString();

    return AlertDialog(
      title: const Text('扫码支付'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: _paid
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 64),
                  SizedBox(height: 12),
                  Text('支付成功！', style: TextStyle(fontSize: 16)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    color: Colors.white,
                    child: qrUrl != null && qrUrl.isNotEmpty
                        ? QrImageView(
                            data: qrUrl,
                            size: 200,
                            backgroundColor: Colors.white,
                          )
                        : const Center(child: Icon(Icons.qr_code, size: 80)),
                  ),
                  const SizedBox(height: 12),
                  if (amount.isNotEmpty)
                    Text(
                      '金额：¥$amount',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  if (orderId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '订单号：$orderId',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '剩余时间：$_timeLeft',
                    style: TextStyle(
                        color: _secondsLeft < 60 ? Colors.red : null),
                  ),
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  const Text('等待支付确认…',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
      ),
      actions: [
        if (!_paid)
          TextButton(
            onPressed: () => Navigator.of(widget.dialogContext).pop(false),
            child: const Text('取消'),
          ),
      ],
    );
  }
}
