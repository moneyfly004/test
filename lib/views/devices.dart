import 'dart:convert';

import 'package:fl_clash/common/common.dart';
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
    setState(() =>
        _devices.removeWhere((d) => (d['id'] ?? '').toString() == deviceId));
    try {
      await ApiService().deleteDevice(deviceId);
    } catch (_) {
      _loadDevices();
    }
  }

  void _saveRemark(String deviceId, String remark) {
    setState(() {
      final idx =
          _devices.indexWhere((d) => (d['id'] ?? '').toString() == deviceId);
      if (idx != -1) {
        _devices[idx] =
            Map<String, dynamic>.from(_devices[idx] as Map)..['remark'] = remark;
      }
    });
    ApiService().remarkDevice(deviceId, remark).catchError((_) => _loadDevices());
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
                  child: _buildDeviceTable(),
                ),
    );
  }

  Widget _buildDeviceTable() {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width > 700;

    if (isWide) return _buildWideTable(cs);
    return _buildCompactTable(cs);
  }

  // Desktop/tablet: full table columns
  Widget _buildWideTable(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Expanded(flex: 2, child: Text('设备名称', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600))),
              const Expanded(flex: 1, child: Text('类型', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600))),
              const SizedBox(width: 120, child: Text('IP / 地区', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600))),
              const SizedBox(width: 120, child: Text('备注', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600))),
              const SizedBox(width: 60),
            ],
          ),
        ),
        for (var i = 0; i < _devices.length; i++) ...[
          _buildWideRow(cs, _devices[i] as Map<String, dynamic>, i),
          const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _buildWideRow(ColorScheme cs, Map<String, dynamic> d, int index) {
    final id = (d['id'] ?? '').toString();
    final name = (d['device_name'] ?? d['name'] ?? '未知').toString();
    final software = (d['software_name'] ?? '').toString();
    final displayName = software.isNotEmpty && !name.startsWith(software)
        ? '$software - $name'
        : name;
    final deviceType = _typeLabel(d);
    final ip = (d['ip'] ?? d['ip_address'] ?? '').toString();
    final country = _parseCountry(d['location']);
    final remark = (d['remark'] ?? '').toString();
    final remarkCtrl = TextEditingController(text: remark);

    return Container(
      color: index.isEven ? cs.surfaceContainerHighest.opacity30 : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (_parseUa(d).isNotEmpty)
                    Text(_parseUa(d), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deviceType, style: const TextStyle(fontSize: 12)),
                  Text(_parseOs(d), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ip, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (country.isNotEmpty)
                    Text(country, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: remarkCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '输入备注…',
                    hintStyle: const TextStyle(fontSize: 11),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: cs.outlineVariant)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: cs.outlineVariant.opacity30)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: cs.primary)),
                  ),
                  onSubmitted: (v) => _saveRemark(id, v.trim()),
                  onEditingComplete: () => _saveRemark(id, remarkCtrl.text.trim()),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: cs.error,
              tooltip: '删除设备',
              onPressed: () => _deleteDevice(id, name),
            ),
          ),
        ],
      ),
    );
  }

  // Mobile: compact card layout
  Widget _buildCompactTable(ColorScheme cs) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _devices.length,
      itemBuilder: (_, i) {
        final d = _devices[i] as Map<String, dynamic>;
        final id = (d['id'] ?? '').toString();
        final name = (d['device_name'] ?? d['name'] ?? '未知').toString();
        final software = (d['software_name'] ?? '').toString();
        final displayName = software.isNotEmpty && !name.startsWith(software) ? '$software - $name' : name;
        final deviceType = _typeLabel(d);
        final ip = (d['ip'] ?? d['ip_address'] ?? '').toString();
        final country = _parseCountry(d['location']);
        final os = _parseOs(d);
        final remark = (d['remark'] ?? '').toString();
        final remarkCtrl = TextEditingController(text: remark);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(displayName,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: cs.error,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteDevice(id, name),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _infoRow('类型', deviceType),
                if (os.isNotEmpty) _infoRow('系统', os),
                if (ip.isNotEmpty) _infoRow('IP', ip),
                if (country.isNotEmpty) _infoRow('地区', country),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: TextField(
                    controller: remarkCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '输入备注…',
                      hintStyle: const TextStyle(fontSize: 11),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onSubmitted: (v) => _saveRemark(id, v.trim()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _typeLabel(Map<String, dynamic> d) {
    final t = (d['device_type'] ?? d['type'] ?? '').toString();
    return switch (t) {
      'desktop' => '桌面',
      'mobile'  => '手机',
      'tablet'  => '平板',
      _         => t.isNotEmpty ? t : '未知',
    };
  }

  String _parseOs(Map<String, dynamic> d) =>
      (d['os_name'] ?? d['os_version'] ?? '').toString();

  String _parseUa(Map<String, dynamic> d) {
    final ua = (d['user_agent'] ?? d['ua'] ?? '').toString();
    return ua.length > 60 ? '${ua.substring(0, 60)}…' : ua;
  }

  // location is a JSON string: {"country":"泰国","country_code":"TH",...}
  String _parseCountry(dynamic location) {
    if (location == null) return '';
    try {
      final Map<String, dynamic> map;
      if (location is String) {
        map = json.decode(location) as Map<String, dynamic>;
      } else if (location is Map<String, dynamic>) {
        map = location;
      } else {
        return '';
      }
      return (map['country'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
