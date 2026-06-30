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
  final Map<String, TextEditingController> _remarkCtrls = {};
  final Set<String> _savingRemarkIds = {};
  final Set<String> _deletingDeviceIds = {};
  final Set<String> _editingRemarkIds = {};
  final Map<String, int> _remarkSaveVersions = {};

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    for (final c in _remarkCtrls.values) {
      c.dispose();
    }
    _remarkCtrls.clear();
    super.dispose();
  }

  Future<void> _loadDevices({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
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
      builder: (dialogContext) => AlertDialog(
        title: Text(context.appLocalizations.deleteDevice),
        content: Text(context.appLocalizations.confirmDeleteDevice(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.appLocalizations.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
              foregroundColor: context.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.appLocalizations.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingDeviceIds.add(deviceId));
    setState(
      () => _devices.removeWhere((d) => (d['id'] ?? '').toString() == deviceId),
    );
    try {
      await ApiService().deleteDevice(deviceId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.appLocalizations.deleteFailed(e.toString())),
          ),
        );
      }
      await _loadDevices();
    } finally {
      if (mounted) setState(() => _deletingDeviceIds.remove(deviceId));
    }
  }

  Future<void> _saveRemark(String deviceId, String remark) async {
    final saveVersion = (_remarkSaveVersions[deviceId] ?? 0) + 1;
    _remarkSaveVersions[deviceId] = saveVersion;
    final idx = _devices.indexWhere(
      (d) => (d['id'] ?? '').toString() == deviceId,
    );
    if (idx != -1 && (_devices[idx]['remark'] ?? '').toString() == remark) {
      return;
    }
    setState(() {
      if (idx != -1) {
        _devices[idx] = Map<String, dynamic>.from(_devices[idx] as Map)
          ..['remark'] = remark;
      }
      _savingRemarkIds.add(deviceId);
    });
    try {
      await ApiService().remarkDevice(deviceId, remark);
      if (!mounted || _remarkSaveVersions[deviceId] != saveVersion) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.appLocalizations.remarkSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.appLocalizations.saveRemarkFailed(e.toString()),
            ),
          ),
        );
      }
      await _loadDevices();
    } finally {
      if (mounted && _remarkSaveVersions[deviceId] == saveVersion) {
        setState(() => _savingRemarkIds.remove(deviceId));
      }
    }
  }

  void _syncRemarkController(
    String deviceId,
    TextEditingController controller,
    String remark,
  ) {
    if (_editingRemarkIds.contains(deviceId)) return;
    if (controller.text == remark) return;
    controller.value = TextEditingValue(
      text: remark,
      selection: TextSelection.collapsed(offset: remark.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: context.appLocalizations.devices,
      actions: [
        IconButton(
          tooltip: context.appLocalizations.refresh,
          icon: const Icon(Icons.refresh),
          onPressed: _loading ? null : () => _loadDevices(silent: true),
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
                    child: Center(
                      child: Text(context.appLocalizations.noDevices),
                    ),
                  ),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => _loadDevices(silent: true),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.appLocalizations.refresh),
                    ),
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
              Expanded(
                flex: 2,
                child: Text(
                  context.appLocalizations.deviceName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  context.appLocalizations.deviceType,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  context.appLocalizations.ipRegion,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 85,
                child: Text(
                  context.appLocalizations.updatedAt,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  context.appLocalizations.remark,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 40),
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
    final name =
        (d['device_name'] ?? d['name'] ?? context.appLocalizations.unknown)
            .toString();
    final software = (d['software_name'] ?? '').toString();
    final displayName = software.isNotEmpty && !name.startsWith(software)
        ? '$software - $name'
        : name;
    final deviceType = _typeLabel(d);
    final ip = (d['ip'] ?? d['ip_address'] ?? '').toString();
    final country = _parseCountry(d['location']);
    final remark = (d['remark'] ?? '').toString();
    final remarkCtrl = _remarkCtrls[id] ??= TextEditingController(text: remark);
    final isSavingRemark = _savingRemarkIds.contains(id);
    final isDeleting = _deletingDeviceIds.contains(id);
    _syncRemarkController(id, remarkCtrl, remark);
    final lastSeen =
        (d['last_seen'] ?? d['last_access'] ?? d['updated_at'] ?? '')
            .toString();

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
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_parseUa(d).isNotEmpty)
                    Text(
                      _parseUa(d),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
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
                  Text(
                    _parseOs(d),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ip,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (country.isNotEmpty)
                    Text(
                      country,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 85,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                lastSeen.length >= 16 ? lastSeen.substring(5, 16) : lastSeen,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: remarkCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: context.appLocalizations.inputRemark,
                    hintStyle: const TextStyle(fontSize: 11),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.opacity30,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: cs.primary),
                    ),
                  ),
                  enabled: !isSavingRemark,
                  onTap: () => _editingRemarkIds.add(id),
                  onSubmitted: (v) => _saveRemark(id, v.trim()),
                  onEditingComplete: () {
                    _editingRemarkIds.remove(id);
                    _saveRemark(id, remarkCtrl.text.trim());
                  },
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: isDeleting
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: cs.error,
                    tooltip: context.appLocalizations.deleteDevice,
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
        final name =
            (d['device_name'] ?? d['name'] ?? context.appLocalizations.unknown)
                .toString();
        final software = (d['software_name'] ?? '').toString();
        final displayName = software.isNotEmpty && !name.startsWith(software)
            ? '$software - $name'
            : name;
        final deviceType = _typeLabel(d);
        final ip = (d['ip'] ?? d['ip_address'] ?? '').toString();
        final country = _parseCountry(d['location']);
        final os = _parseOs(d);
        final remark = (d['remark'] ?? '').toString();
        final remarkCtrl = _remarkCtrls[id] ??= TextEditingController(
          text: remark,
        );
        final isSavingRemark = _savingRemarkIds.contains(id);
        final isDeleting = _deletingDeviceIds.contains(id);
        _syncRemarkController(id, remarkCtrl, remark);
        final lastSeen =
            (d['last_seen'] ?? d['last_access'] ?? d['updated_at'] ?? '')
                .toString();

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
                      child: Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: isDeleting
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: cs.error,
                              tooltip: context.appLocalizations.deleteDevice,
                              onPressed: () => _deleteDevice(id, name),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _infoRow(context.appLocalizations.deviceType, deviceType),
                if (os.isNotEmpty)
                  _infoRow(context.appLocalizations.system, os),
                if (ip.isNotEmpty) _infoRow('IP', ip),
                if (country.isNotEmpty)
                  _infoRow(context.appLocalizations.region, country),
                if (lastSeen.isNotEmpty)
                  _infoRow(
                    context.appLocalizations.updated,
                    lastSeen.length >= 16
                        ? lastSeen.substring(5, 16)
                        : lastSeen,
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: TextField(
                    controller: remarkCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: context.appLocalizations.inputRemark,
                      hintStyle: const TextStyle(fontSize: 11),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      suffixIcon: isSavingRemark
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    enabled: !isSavingRemark,
                    onTap: () => _editingRemarkIds.add(id),
                    onSubmitted: (v) => _saveRemark(id, v.trim()),
                    onEditingComplete: () {
                      _editingRemarkIds.remove(id);
                      _saveRemark(id, remarkCtrl.text.trim());
                    },
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
      'desktop' => currentAppLocalizations.desktopDevice,
      'mobile' => currentAppLocalizations.mobileDevice,
      'tablet' => currentAppLocalizations.tabletDevice,
      _ => t.isNotEmpty ? t : currentAppLocalizations.unknown,
    };
  }

  String _parseOs(Map<String, dynamic> d) =>
      (d['os_name'] ?? d['os_version'] ?? '').toString();

  String _parseUa(Map<String, dynamic> d) {
    final ua = (d['user_agent'] ?? d['ua'] ?? '').toString();
    return ua.length > 60 ? '${ua.substring(0, 60)}…' : ua;
  }

  // location is a JSON string: {"country":"Thailand","country_code":"TH",...}
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
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
