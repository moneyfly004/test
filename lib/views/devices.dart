import 'package:fl_clash/services/services.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DevicesView extends ConsumerStatefulWidget {
  const DevicesView({super.key});

  @override
  ConsumerState<DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends ConsumerState<DevicesView> {
  List<dynamic> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    try {
      final devices = await ApiService().getDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteDevice(String deviceId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确定要删除设备「$name」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Optimistic: remove from local list immediately
    setState(() => _devices.removeWhere((d) => (d['id'] ?? '').toString() == deviceId));
    try {
      await ApiService().deleteDevice(deviceId);
    } catch (e) {
      // Restore on failure
      _loadDevices();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _editRemark(String deviceId, String currentRemark) async {
    final controller = TextEditingController(text: currentRemark);
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑备注'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '备注名称',
            border: OutlineInputBorder(),
          ),
          maxLength: 40,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (remark == null) return;
    // Optimistic: update local list immediately
    setState(() {
      final idx = _devices.indexWhere(
          (d) => (d['id'] ?? '').toString() == deviceId);
      if (idx != -1) {
        _devices[idx] = Map<String, dynamic>.from(_devices[idx] as Map)
          ..['remark'] = remark;
      }
    });
    try {
      await ApiService().remarkDevice(deviceId, remark);
    } catch (e) {
      _loadDevices();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showDetail(Map<String, dynamic> d) {
    final ua = (d['user_agent'] ?? d['ua'] ?? d['browser'] ?? '').toString();
    final ip = (d['ip'] ?? d['ip_address'] ?? d['login_ip'] ?? '').toString();
    final system = (d['system'] ?? d['os_name'] ?? d['type'] ?? '').toString();
    final deviceType =
        (d['device_type'] ?? d['client_type'] ?? d['platform'] ?? '').toString();
    final lastSeen =
        (d['last_seen'] ?? d['last_access'] ?? d['updated_at'] ?? '').toString();
    final createdAt = (d['created_at'] ?? d['bind_time'] ?? '').toString();
    final remark = (d['remark'] ?? '').toString();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('设备详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ip.isNotEmpty) _detailRow('IP 地址', ip),
              if (system.isNotEmpty) _detailRow('操作系统', system),
              if (deviceType.isNotEmpty) _detailRow('设备端', deviceType),
              if (ua.isNotEmpty) _detailRow('UA', ua, copyable: true),
              if (lastSeen.isNotEmpty) _detailRow('最后活跃', lastSeen),
              if (createdAt.isNotEmpty) _detailRow('绑定时间', createdAt),
              if (remark.isNotEmpty) _detailRow('备注', remark),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          copyable
              ? SelectableText(value, style: const TextStyle(fontSize: 13))
              : Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '设备管理',
      actions: [
        IconButton(
          tooltip: '刷新',
          icon: const Icon(Icons.refresh),
          onPressed: _loading ? null : _loadDevices,
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? RefreshIndicator(
                  onRefresh: _loadDevices,
                  child: ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.45,
                        child: const Center(child: Text('暂无设备')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDevices,
                  child: ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (_, i) {
                      final d = _devices[i] as Map<String, dynamic>;
                      final isCurrent = d['is_current'] == true;
                      final id = (d['id'] ?? '').toString();
                      final system = (d['system'] ?? d['os_name'] ?? d['type'] ?? '').toString();
                      final deviceType = (d['device_type'] ?? d['client_type'] ?? d['platform'] ?? '').toString();
                      final name = (d['remark'] ?? d['device_name'] ?? d['name'] ?? '未知设备').toString();
                      final ip = (d['ip'] ?? d['ip_address'] ?? d['login_ip'] ?? '').toString();
                      final ua = (d['user_agent'] ?? d['ua'] ?? d['browser'] ?? '').toString();
                      final lastSeen = (d['last_seen'] ?? d['last_access'] ?? d['updated_at'] ?? '').toString();

                      final subtitleParts = [
                        if (ip.isNotEmpty) ip,
                        if (system.isNotEmpty) system,
                        if (deviceType.isNotEmpty) deviceType,
                        if (lastSeen.isNotEmpty) lastSeen,
                      ];
                      final uaShort = ua.length > 50 ? '${ua.substring(0, 50)}…' : ua;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            _platformIcon(system),
                            color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '当前',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (subtitleParts.isNotEmpty)
                                Text(
                                  subtitleParts.join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (uaShort.isNotEmpty)
                                Text(
                                  uaShort,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                          isThreeLine: ua.isNotEmpty,
                          onTap: () => _showDetail(d),
                          trailing: isCurrent
                              ? null
                              : PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'remark') {
                                      await _editRemark(id, (d['remark'] ?? '').toString());
                                    } else if (value == 'delete') {
                                      await _deleteDevice(id, name);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'remark', child: Text('编辑备注')),
                                    PopupMenuItem(value: 'delete', child: Text('删除设备')),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _platformIcon(String system) {
    final s = system.toLowerCase();
    if (s.contains('android')) return Icons.android;
    if (s.contains('ios') || s.contains('iphone')) return Icons.phone_iphone;
    if (s.contains('macos') || s.contains('mac')) return Icons.laptop_mac;
    if (s.contains('windows')) return Icons.laptop_windows;
    if (s.contains('linux')) return Icons.computer;
    return Icons.devices;
  }
}
