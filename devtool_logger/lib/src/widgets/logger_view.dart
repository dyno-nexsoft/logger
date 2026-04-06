import 'package:devtools_app_shared/service.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/service_extensions.dart' as extensions;
import 'package:flutter/material.dart';

import '../log_entry.dart';
import '../logger_extension_controller.dart';
import 'log_detail_panel.dart';
import 'log_list_panel.dart';
import 'logger_toolbar.dart';

/// The main view for the logger extension.
///
/// Displays a split-pane layout with a log list on the left
/// and a detail panel on the right, matching the DevTools style.
class LoggerView extends StatefulWidget {
  const LoggerView({super.key});

  @override
  State<LoggerView> createState() => _LoggerViewState();
}

class _LoggerViewState extends State<LoggerView> {
  late final LoggerExtensionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LoggerExtensionController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        ListenableBuilder(
          listenable: serviceManager.connectedState,
          builder: (_, _) => _ConnectedAppHeader(serviceManager.connectedApp),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (_, _) => _LoggerToolbarWrapper(controller: _controller),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (_, _) => _SplitPane(controller: _controller),
          ),
        ),
      ],
    );
  }
}

/// Bridges the [LoggerExtensionController] to the [LoggerToolbar] widget.
///
/// Reads the current filter state from [controller] and forwards user
/// interactions back as setter calls. Extracted from [_LoggerViewState]
/// to avoid a private widget-returning method.
class _LoggerToolbarWrapper extends StatelessWidget {
  final LoggerExtensionController controller;

  const _LoggerToolbarWrapper({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LoggerToolbar(
      searchQuery: controller.searchQuery,
      selectedLevel: controller.selectedLevel,
      useRegex: controller.useRegex,
      isFilterMode: controller.isFilterMode,
      onSearchChanged: (value) => controller.searchQuery = value,
      onLevelChanged: (lvl) => controller.selectedLevel = lvl,
      onRegexChanged: (value) => controller.useRegex = value,
      onFilterModeChanged: (value) => controller.isFilterMode = value,
    );
  }
}

/// The horizontal split between the log list and detail panels.
///
/// Separated from [_LoggerViewState] to keep the build method
/// under the line-count guideline.
class _SplitPane extends StatelessWidget {
  final LoggerExtensionController controller;

  const _SplitPane({required this.controller});

  @override
  Widget build(BuildContext context) {
    final filteredLogs = controller.filteredLogs;
    final selectedId = controller.selectedId;

    return SplitPane(
      axis: _splitAxisFor(context),
      initialFractions: [0.5, 0.5],
      children: [
        LogListPanel(
          logs: filteredLogs,
          selectedId: selectedId,
          isListening: controller.isListening,
          autoScroll: controller.autoScroll,
          preserveLogs: controller.preserveLogs,
          isFilterMode: controller.isFilterMode,
          checkMatch: controller.matchesEntry,
          onLogSelected: (id) => controller.selectedId = id,
          onClearLogs: controller.clearLogs,
          onListeningChanged: (val) => controller.isListening = val,
          onAutoScrollChanged: (val) => controller.autoScroll = val,
          onPreserveChanged: (val) => controller.preserveLogs = val,
        ),
        _buildDetailPanel(filteredLogs, selectedId),
      ],
    );
  }

  Widget _buildDetailPanel(List<LogEntry> logs, String? selectedId) {
    if (selectedId == null) {
      return const DevToolsAreaPane(
        header: AreaPaneHeader(
          roundedTopBorder: false,
          includeTopBorder: false,
          title: Text('Log Detail'),
        ),
        child: _EmptyDetailPlaceholder(),
      );
    }

    try {
      final log = logs.firstWhere((l) => l.id == selectedId);
      return LogDetailPanel(log: log);
    } catch (_) {
      return const DevToolsAreaPane(
        header: AreaPaneHeader(
          roundedTopBorder: false,
          includeTopBorder: false,
          title: Text('Log Detail'),
        ),
        child: _EmptyDetailPlaceholder(),
      );
    }
  }

  Axis _splitAxisFor(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final aspectRatio = screenSize.width / screenSize.height;
    if (screenSize.height <= 600 || aspectRatio >= 1.2) {
      return Axis.horizontal;
    }
    return Axis.vertical;
  }
}

/// Placeholder shown when no log is selected in the detail panel.
class _EmptyDetailPlaceholder extends StatelessWidget {
  const _EmptyDetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        spacing: 16,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.segment_rounded, size: 48),
          Text(
            'Select a log to view details',
            style: TextTheme.of(context).headlineSmall,
          ),
        ],
      ),
    );
  }
}

class _ConnectedAppHeader extends StatelessWidget {
  const _ConnectedAppHeader(this.connectedApp);

  final ConnectedApp? connectedApp;

  @override
  Widget build(BuildContext context) {
    if (connectedApp == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFlutter = connectedApp!.isFlutterAppNow ?? false;
    final os = connectedApp!.operatingSystem.toUpperCase();

    return OutlineDecoration.onlyBottom(
      child: Row(
        children: [
          Icon(
            isFlutter ? Icons.flutter_dash : Icons.terminal,
            size: defaultIconSize,
            color: colorScheme.primary,
          ),
          const SizedBox(width: denseSpacing),
          Text('Connected to: $os', style: theme.boldTextStyle),
          const SizedBox(width: defaultSpacing),
          if (isFlutter)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: densePadding,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(densePadding),
              ),
              child: Text(
                'Flutter',
                style: theme.subtleTextStyle.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 10,
                ),
              ),
            ),
          const Spacer(),
          if (isFlutter) _QuickActionsMenu(),
        ],
      ),
    );
  }
}

class _QuickActionsMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<extensions.ToggleableServiceExtension<bool>>(
      tooltip: 'Quick Actions',
      padding: EdgeInsets.zero,
      iconSize: defaultIconSize,
      icon: const Icon(Icons.menu),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: extensions.debugPaint,
          child: const ListTile(
            leading: Icon(Icons.format_paint),
            title: Text('Toggle Debug Paint'),
          ),
        ),
        PopupMenuItem(
          value: extensions.debugPaintBaselines,
          child: const ListTile(
            leading: Icon(Icons.speed),
            title: Text('Toggle Debug Paint Baselines'),
          ),
        ),
      ],
      onSelected: (extension) async {
        final service = serviceManager.serviceExtensionManager;
        final current = service.getServiceExtensionState(extension.extension);
        final enabled = current.value.enabled;
        await service.setServiceExtensionState(
          extension.extension,
          enabled: !enabled,
          value: !enabled,
        );
      },
    );
  }
}
