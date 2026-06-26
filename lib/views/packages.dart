import 'dart:async';

import 'package:fl_clash/services/services.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PackagesView extends ConsumerStatefulWidget {
  const PackagesView({super.key});

  @override
  ConsumerState<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends ConsumerState<PackagesView> {
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

    // Show QR dialog immediately with loading state — no gap between dialogs
    final paid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PaymentQrDialog(
        orderFuture: ApiService().createOrder(
          pkg['id']?.toString() ?? '',
          method,
        ),
        dialogContext: dialogContext,
      ),
    );

    if (paid == true && mounted) {
      // Sync in background — don't block the UI
      MoneyFlyService.syncSubscription(ref).catchError((_) => null);
      await _loadPackages();
    }
  }

  String _name(Map<String, dynamic> pkg) =>
      (pkg['name'] ?? pkg['title'] ?? pkg['package_name'] ?? pkg['subject'] ?? '套餐')
          .toString();

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
                        Icon(Icons.error_outline, size: 48, color: cs.error),
                        const SizedBox(height: 16),
                        Text('加载失败', style: TextStyle(color: cs.error)),
                        const SizedBox(height: 8),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _loadPackages, child: const Text('重试')),
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
                            final pkg = _packages[i] as Map<String, dynamic>;
                            final desc = (pkg['description'] ??
                                    pkg['desc'] ??
                                    pkg['content'] ??
                                    '')
                                .toString();
                            final duration = (pkg['duration'] ??
                                        pkg['period'] ??
                                        pkg['days'])
                                    ?.toString() ??
                                '';
                            final traffic = (pkg['traffic'] ??
                                        pkg['bandwidth'] ??
                                        pkg['flow'])
                                    ?.toString() ??
                                '';
                            final price = pkg['price'] ??
                                pkg['amount'] ??
                                pkg['sale_price'] ??
                                pkg['money'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _name(pkg),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        desc,
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
                                              label: '$duration天',
                                            ),
                                          if (traffic.isNotEmpty)
                                            _Tag(
                                              icon: Icons.data_usage,
                                              label: '$traffic GB',
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (price != null)
                                          Text(
                                            '¥$price',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          )
                                        else
                                          const SizedBox.shrink(),
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
          if (methods.isNotEmpty) {
            final first = methods.first as Map;
            _selected =
                (first['key'] ?? first['pay_type'] ?? first['id']).toString();
          }
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
                      final key =
                          (m['key'] ?? m['pay_type'] ?? m['id']).toString();
                      final name = (m['name'] ?? key).toString();
                      final isSelected = key == _selected;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
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
  final Future<Map<String, dynamic>> orderFuture;
  final BuildContext dialogContext;

  const _PaymentQrDialog(
      {required this.orderFuture, required this.dialogContext});

  @override
  State<_PaymentQrDialog> createState() => _PaymentQrDialogState();
}

class _PaymentQrDialogState extends State<_PaymentQrDialog> {
  Timer? _pollTimer;
  Timer? _countdownTimer;
  bool _paid = false;
  int _secondsLeft = 900;
  Map<String, dynamic>? _order;
  String? _orderError;

  @override
  void initState() {
    super.initState();
    widget.orderFuture.then((order) {
      if (!mounted) return;
      setState(() => _order = order);
      _startPolling();
      _startCountdown();
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _orderError = e.toString());
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final orderId = (_order!['order_no'] ??
                _order!['order_id'] ??
                _order!['id'] ??
                '')
            .toString();
        if (orderId.isEmpty) return;
        final status = await ApiService().getOrderStatus(orderId);
        final isPaid = status['status'] == 'paid' ||
            status['status'] == 'success' ||
            status['paid'] == true ||
            status['is_paid'] == true ||
            status['order_status'] == 'paid';
        if (isPaid) {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() => _paid = true);
            // Close immediately — parent handles sync + reload
            Navigator.of(widget.dialogContext).pop(true);
          }
        }
      } catch (_) {}
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
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
    // Show loading while createOrder is in-flight (no gap between dialogs)
    if (_orderError != null) {
      return AlertDialog(
        title: const Text('扫码支付'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_orderError!, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(widget.dialogContext).pop(false),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    if (_order == null) {
      return const AlertDialog(
        title: Text('扫码支付'),
        content: SizedBox(
          width: 200,
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final order = _order!;
    final qrData = (order['payment_qr_code'] ??
            order['payment_url'] ??
            order['qr_code'] ??
            order['pay_url'] ??
            order['qr_link'] ??
            order['code_url'] ??
            order['pay_info'])
        ?.toString();
    final amount = (order['amount'] ?? order['price'] ?? '').toString();
    final orderId =
        (order['order_no'] ?? order['order_id'] ?? order['id'] ?? '')
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
                  Text('支付成功！正在更新套餐…',
                      style: TextStyle(fontSize: 16)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    color: Colors.white,
                    child: qrData != null && qrData.isNotEmpty
                        ? QrImageView(
                            data: qrData,
                            size: 200,
                            backgroundColor: Colors.white,
                          )
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.qr_code, size: 60),
                                SizedBox(height: 8),
                                Text('二维码加载中…',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
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
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
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
