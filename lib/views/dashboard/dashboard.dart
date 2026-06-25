import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/start_button.dart';
import 'widgets/widgets.dart';

typedef _IsEditWidgetBuilder = Widget Function(bool isEdit);

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final key = GlobalKey<SuperGridState>();
  final _isEditNotifier = ValueNotifier<bool>(false);
  final _addedWidgetsNotifier = ValueNotifier<List<GridItem>>([]);

  @override
  void dispose() {
    _isEditNotifier.dispose();
    _addedWidgetsNotifier.dispose();
    super.dispose();
  }

  Widget _buildIsEdit(_IsEditWidgetBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _isEditNotifier,
      builder: (_, isEdit, _) {
        return builder(isEdit);
      },
    );
  }

  Future<void> _handleConnection() async {
    final coreStatus = ref.read(coreStatusProvider);
    if (coreStatus == CoreStatus.connecting) {
      return;
    }
    final tip = coreStatus == CoreStatus.connected
        ? context.appLocalizations.forceRestartCoreTip
        : context.appLocalizations.restartCoreTip;
    final res = await globalState.showMessage(message: TextSpan(text: tip));
    if (res != true) {
      return;
    }
    globalState.container.read(coreActionProvider.notifier).restartCore();
  }

  List<Widget> _buildActions(bool isEdit) {
    final appLocalizations = context.appLocalizations;
    return [
      if (!isEdit)
        Consumer(
          builder: (_, ref, _) {
            final coreStatus = ref.watch(coreStatusProvider);
            return Tooltip(
              message: appLocalizations.coreStatus,
              child: FadeScaleBox(
                alignment: Alignment.centerRight,
                child: coreStatus == CoreStatus.connected
                    ? IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.harmonizeWith(
                            context.colorScheme.primary,
                          ),
                          foregroundColor: switch (Theme.brightnessOf(
                            context,
                          )) {
                            Brightness.light =>
                              context.colorScheme.onSurfaceVariant,
                            Brightness.dark =>
                              context.colorScheme.onPrimaryFixedVariant,
                          },
                        ),
                        onPressed: _handleConnection,
                        icon: const Icon(Icons.check,
                            fontWeight: FontWeight.w900),
                      )
                    : FilledButton.icon(
                        key: ValueKey(coreStatus),
                        onPressed: _handleConnection,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: switch (coreStatus) {
                            CoreStatus.connecting => null,
                            CoreStatus.connected => Colors.greenAccent,
                            CoreStatus.disconnected =>
                              context.colorScheme.error,
                          },
                          foregroundColor: switch (coreStatus) {
                            CoreStatus.connecting => null,
                            CoreStatus.connected => switch (Theme.brightnessOf(
                                context,
                              )) {
                                Brightness.light =>
                                  context.colorScheme.onSurfaceVariant,
                                Brightness.dark => null,
                              },
                            CoreStatus.disconnected =>
                              context.colorScheme.onError,
                          },
                        ),
                        icon: SizedBox(
                          height: globalState.measure.bodyMediumHeight,
                          width: globalState.measure.bodyMediumHeight,
                          child: switch (coreStatus) {
                            CoreStatus.connecting => Padding(
                                padding: const EdgeInsets.all(2),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: context.colorScheme.onPrimary,
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                            CoreStatus.connected => const Icon(
                                Icons.check_sharp,
                                fontWeight: FontWeight.w900,
                              ),
                            CoreStatus.disconnected => const Icon(
                                Icons.restart_alt_sharp,
                                fontWeight: FontWeight.w900,
                              ),
                          },
                        ),
                        label: Text(switch (coreStatus) {
                          CoreStatus.connecting => appLocalizations.connecting,
                          CoreStatus.connected => appLocalizations.connected,
                          CoreStatus.disconnected =>
                            appLocalizations.disconnected,
                        }),
                      ),
              ),
            );
          },
        ),
      if (isEdit)
        ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, addedChildren, child) {
            if (addedChildren.isEmpty) {
              return Container();
            }
            return child!;
          },
          child: IconButton(
            onPressed: () {
              _showAddWidgetsModal();
            },
            icon: const Icon(Icons.add_circle),
          ),
        ),
      FadeRotationScaleBox(
        child: isEdit
            ? IconButton(
                key: const ValueKey(true),
                icon: const Icon(Icons.save, key: ValueKey('save-icon')),
                onPressed: _handleUpdateIsEdit,
              )
            : IconButton(
                key: const ValueKey(false),
                icon: const Icon(Icons.edit, key: ValueKey('edit-icon')),
                onPressed: _handleUpdateIsEdit,
              ),
      ),
    ];
  }

  void _showAddWidgetsModal() {
    showSheet(
      builder: (_) {
        return ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, value, _) {
            return AdaptiveSheetScaffold(
              body: _AddDashboardWidgetModal(
                items: value,
                onAdd: (gridItem) {
                  key.currentState?.handleAdd(gridItem);
                },
              ),
              title: context.appLocalizations.add,
            );
          },
        );
      },
      context: context,
    );
  }

  Future<void> _handleUpdateIsEdit() async {
    if (_isEditNotifier.value == true) {
      await _handleSave();
    }
    _isEditNotifier.value = !_isEditNotifier.value;
  }

  Future<void> _handleSave() async {
    final currentState = key.currentState;
    if (currentState == null) {
      return;
    }
    if (mounted && currentState.children.isNotEmpty) {
      await currentState.isTransformCompleter;
      final dashboardWidgets = currentState.children
          .map((item) => DashboardWidget.getDashboardWidget(item))
          .toList();
      ref.read(appSettingProvider.notifier).update(
            (state) => state.copyWith(dashboardWidgets: dashboardWidgets),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardStateProvider);
    final columns = max(4 * ((dashboardState.contentWidth / 280).ceil()), 8);
    final spacing = 14.mAp;
    final children = [
      ...dashboardState.dashboardWidgets
          .where(
            (item) => item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addedWidgetsNotifier.value = DashboardWidget.values
          .where(
            (item) =>
                !children.contains(item.widget) &&
                item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget)
          .toList();
    });
    return _buildIsEdit(
      (isEdit) => CommonScaffold(
        title: context.appLocalizations.dashboard,
        actions: _buildActions(isEdit),
        floatingActionButton:
            isEdit || !system.isDesktop ? const StartButton() : null,
        body: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16).copyWith(bottom: 88),
            child: isEdit
                ? SystemBackBlock(
                    child: CommonPopScope(
                      child: SuperGrid(
                        key: key,
                        crossAxisCount: columns,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        children: children,
                        onUpdate: () {
                          _handleSave();
                        },
                      ),
                      onPop: (context) {
                        _handleUpdateIsEdit();
                        return false;
                      },
                    ),
                  )
                : system.isDesktop
                    ? const _DesktopDashboard()
                    : Grid(
                        crossAxisCount: columns,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        children: children,
                      ),
          ),
        ),
      ),
    );
  }
}

class _DesktopDashboard extends ConsumerWidget {
  const _DesktopDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final isStart = ref.watch(isStartProvider);
    final coreStatus = ref.watch(coreStatusProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    final traffics = ref.watch(trafficsProvider).list;
    final currentTraffic = traffics.isEmpty ? const Traffic() : traffics.last;
    final totalTraffic = ref.watch(totalTrafficProvider);
    final groups = ref.watch(currentGroupsStateProvider).value;
    final statusText = switch (coreStatus) {
      CoreStatus.connected => appLocalizations.connected,
      CoreStatus.connecting => appLocalizations.connecting,
      CoreStatus.disconnected => appLocalizations.disconnected,
    };
    final statusColor = switch (coreStatus) {
      CoreStatus.connected => Colors.green.harmonizeWith(colorScheme.primary),
      CoreStatus.connecting => colorScheme.tertiary,
      CoreStatus.disconnected => colorScheme.error,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHero(
            isStart: isStart,
            statusText: statusText,
            statusColor: statusColor,
            profileName: currentProfile?.label ?? appLocalizations.noInfo,
            uploadSpeed: currentTraffic.up.traffic.show,
            downloadSpeed: currentTraffic.down.traffic.show,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 900;
              final metricCards = [
                _MetricCard(
                  icon: Icons.cloud_upload_outlined,
                  label: appLocalizations.upload,
                  value: totalTraffic.up.traffic.show,
                  color: colorScheme.primary,
                ),
                _MetricCard(
                  icon: Icons.cloud_download_outlined,
                  label: appLocalizations.download,
                  value: totalTraffic.down.traffic.show,
                  color: colorScheme.secondary,
                ),
                _MetricCard(
                  icon: Icons.account_tree_outlined,
                  label: appLocalizations.proxyGroup,
                  value: groups.length.toString(),
                  color: colorScheme.tertiary,
                ),
              ];
              return Flex(
                direction: isCompact ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < metricCards.length; index++) ...[
                    if (index > 0)
                      SizedBox(
                          width: isCompact ? 0 : 12,
                          height: isCompact ? 12 : 0),
                    Expanded(
                        flex: isCompact ? 0 : 1, child: metricCards[index]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 900;
              final children = [
                const NetworkSpeed(),
                const TrafficUsage(),
              ];
              return Flex(
                direction: isCompact ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0)
                      SizedBox(
                          width: isCompact ? 0 : 16,
                          height: isCompact ? 16 : 0),
                    Expanded(flex: isCompact ? 0 : 1, child: children[index]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardHero extends ConsumerWidget {
  final bool isStart;
  final String statusText;
  final Color statusColor;
  final String profileName;
  final String uploadSpeed;
  final String downloadSpeed;

  const _DashboardHero({
    required this.isStart,
    required this.statusText,
    required this.statusColor,
    required this.profileName,
    required this.uploadSpeed,
    required this.downloadSpeed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.opacity80,
            colorScheme.secondaryContainer.opacity60,
            colorScheme.surfaceContainerHighest,
          ],
        ),
        shape: RoundedSuperellipseBorder(
          side: BorderSide(color: colorScheme.outlineVariant.opacity60),
          borderRadius: BorderRadius.circular(32),
        ),
        shadows: [
          BoxShadow(
            color: colorScheme.shadow.opacity12,
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          return Flex(
            direction: isCompact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: isCompact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: isCompact ? 0 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusPill(text: statusText, color: statusColor),
                    const SizedBox(height: 18),
                    Text(
                      isStart ? appLocalizations.start : appLocalizations.stop,
                      style: context.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isCompact ? 0 : 28, height: isCompact ? 24 : 0),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SpeedTile(
                    icon: Icons.arrow_upward_rounded,
                    label: appLocalizations.upload,
                    value: '$uploadSpeed/s',
                  ),
                  _SpeedTile(
                    icon: Icons.arrow_downward_rounded,
                    label: appLocalizations.download,
                    value: '$downloadSpeed/s',
                  ),
                  const StartButton(),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: color.opacity15,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: context.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SpeedTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: 168,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: colorScheme.surface.opacity80,
        shape: RoundedSuperellipseBorder(
          side: BorderSide(color: colorScheme.outlineVariant.opacity60),
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 14),
          Text(label, style: context.textTheme.labelMedium?.toLighter),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest.opacity80,
        shape: RoundedSuperellipseBorder(
          side: BorderSide(color: colorScheme.outlineVariant.opacity60),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: ShapeDecoration(
              color: color.opacity15,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.textTheme.labelMedium?.toLighter),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDashboardWidgetModal extends StatelessWidget {
  final List<GridItem> items;
  final Function(GridItem item) onAdd;

  const _AddDashboardWidgetModal({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DeferredPointerHandler(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Grid(
          crossAxisCount: 8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: items
              .map(
                (item) => item.wrap(
                  builder: (child) {
                    return _AddedContainer(
                      onAdd: () {
                        onAdd(item);
                      },
                      child: child,
                    );
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AddedContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onAdd;

  const _AddedContainer({required this.child, required this.onAdd});

  @override
  State<_AddedContainer> createState() => _AddedContainerState();
}

class _AddedContainerState extends State<_AddedContainer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_AddedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {}
  }

  Future<void> _handleAdd() async {
    widget.onAdd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ActivateBox(child: widget.child),
        Positioned(
          top: -8,
          right: -8,
          child: DeferPointer(
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton.filled(
                iconSize: 20,
                padding: const EdgeInsets.all(2),
                onPressed: _handleAdd,
                icon: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
