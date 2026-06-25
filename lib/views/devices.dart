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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteDevice(String deviceId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text('Remove "$name"? This device will be disconnected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().deleteDevice(deviceId);
      await _loadDevices();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editRemark(String deviceId, String currentRemark) async {
    final controller = TextEditingController(text: currentRemark);
    final remark = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Device Remark'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Remark',
            border: OutlineInputBorder(),
          ),
          maxLength: 40,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (remark == null) return;
    try {
      await ApiService().remarkDevice(deviceId, remark);
      await _loadDevices();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'Device Management',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDevices),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? const Center(child: Text('No devices'))
          : RefreshIndicator(
              onRefresh: _loadDevices,
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (_, i) {
                  final d = _devices[i] as Map<String, dynamic>;
                  final isCurrent = d['is_current'] == true;
                  final id = (d['id'] ?? '').toString();
                  final system =
                      (d['system'] ?? d['os_name'] ?? d['type'] ?? '')
                          .toString();
                  final name =
                      (d['remark'] ??
                              d['device_name'] ??
                              d['name'] ??
                              'Unknown')
                          .toString();
                  final ip = (d['ip'] ?? d['ip_address'] ?? '').toString();
                  final lastSeen = (d['last_seen'] ?? d['last_access'] ?? '')
                      .toString();
                  return ListTile(
                    leading: Icon(
                      _platformIcon(system),
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        system,
                        ip,
                        lastSeen,
                      ].where((v) => v.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrent
                        ? Chip(
                            label: const Text('Current'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          )
                        : PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'remark') {
                                await _editRemark(
                                  id,
                                  (d['remark'] ?? '').toString(),
                                );
                              }
                              if (value == 'delete') {
                                await _deleteDevice(id, name);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'remark',
                                child: Text('Edit remark'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Remove'),
                              ),
                            ],
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
