import 'package:fl_clash/services/services.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';

class DevicesView extends StatefulWidget {
  const DevicesView({super.key});

  @override
  State<DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<DevicesView> {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
                      return ListTile(
                        leading: Icon(
                          _platformIcon(d['system'] as String? ?? ''),
                          color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                        ),
                        title: Text(
                          d['remark'] as String? ?? d['name'] as String? ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${d['system'] ?? ''} · ${d['ip'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isCurrent
                            ? Chip(
                                label: const Text('Current'),
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              )
                            : IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteDevice(
                                  d['id'] as String? ?? '',
                                  d['remark'] as String? ?? d['name'] as String? ?? 'device',
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
