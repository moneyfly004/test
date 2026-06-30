import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;
  bool isStart = false;

  @override
  void initState() {
    super.initState();
    isStart = ref.read(isStartProvider);
    _controller = AnimationController(
      vsync: this,
      value: isStart ? 1 : 0,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
    );
    ref.listenManual(isStartProvider, (prev, next) {
      if (next != isStart) {
        isStart = next;
        updateController();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void handleSwitchStart() {
    isStart = !isStart;
    updateController();
    debouncer.call(FunctionTag.updateStatus, () {
      globalState.container
          .read(setupActionProvider.notifier)
          .updateStatus(isStart, isInit: !ref.read(initProvider));
      // Show connection status notification
      final context = globalState.navigatorKey.currentContext;
      if (context != null) {
        final appLocalizations = context.appLocalizations;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isStart
                  ? appLocalizations.proxyConnected
                  : appLocalizations.proxyDisconnected,
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }, duration: commonDuration);
  }

  void updateController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isStart && mounted) {
        _controller?.forward();
      } else {
        _controller?.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) {
      return Container();
    }
    final runTime = ref.watch(runTimeProvider);
    final suspend = ref.watch(suspendProvider);
    final theme = Theme.of(context);
    final disableAnimations =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (disableAnimations) {
      _controller?.value = isStart ? 1 : 0;
    }
    return RepaintBoundary(
      child: Theme(
        data: theme.copyWith(
          floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
            sizeConstraints: const BoxConstraints(minWidth: 64, maxWidth: 240),
          ),
        ),
        child: Semantics(
          button: true,
          label: suspend
              ? context.appLocalizations.connectProxy
              : context.appLocalizations.connected,
          child: FloatingActionButton.extended(
            clipBehavior: Clip.antiAlias,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            heroTag: null,
            onPressed: handleSwitchStart,
            extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
            backgroundColor: isStart
                ? Colors.green
                : context.colorScheme.primary,
            foregroundColor: isStart
                ? Colors.white
                : context.colorScheme.onPrimary,
            icon: SizedBox(
              width: 24,
              height: 24,
              child: AnimatedIcon(
                icon: AnimatedIcons.play_pause,
                progress: _animation,
              ),
            ),
            label: Text(
              suspend
                  ? context.appLocalizations.connectProxy
                  : utils.getTimeText(runTime),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isStart ? Colors.white : context.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
