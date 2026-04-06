import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../log_entry.dart';

/// The left panel displaying a table-style log list.
///
/// Shows log entries in rows with TIMESTAMP, LVL (colored dot),
/// and MESSAGE columns. Supports single-row selection to drive
/// the detail panel.
class LogListPanel extends StatefulWidget {
  /// The list of log entries to display.
  final List<LogEntry> logs;

  /// ID of the currently selected log entry, or null if none.
  final String? selectedId;

  /// Whether the controller is currently listening for new logs.
  final bool isListening;

  /// Whether auto-scroll is enabled.
  final bool autoScroll;

  /// Whether logs are preserved across hot reloads.
  final bool preserveLogs;

  /// Whether non-matching logs should be hidden (true) or dimmed (false).
  final bool isFilterMode;

  /// Callback to check if a log entry matches current filters.
  final bool Function(LogEntry) checkMatch;

  /// Called when a log entry row is tapped.
  final ValueChanged<String> onLogSelected;

  /// Called when the clear logs button is pressed.
  final VoidCallback onClearLogs;

  /// Called when the listening state is toggled.
  final ValueChanged<bool> onListeningChanged;

  /// Called when the auto-scroll state is toggled.
  final ValueChanged<bool> onAutoScrollChanged;

  /// Called when the preserve state is toggled.
  final ValueChanged<bool> onPreserveChanged;

  const LogListPanel({
    super.key,
    required this.logs,
    required this.selectedId,
    required this.isListening,
    required this.autoScroll,
    required this.preserveLogs,
    required this.isFilterMode,
    required this.checkMatch,
    required this.onLogSelected,
    required this.onClearLogs,
    required this.onListeningChanged,
    required this.onAutoScrollChanged,
    required this.onPreserveChanged,
  });

  @override
  State<LogListPanel> createState() => _LogListPanelState();
}

class _LogListPanelState extends State<LogListPanel> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant LogListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoScroll && widget.logs.isNotEmpty) {
      final oldLastId = oldWidget.logs.lastOrNull?.id;
      final newLastId = widget.logs.last.id;

      if (newLastId != oldLastId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.autoScrollToBottom();
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DevToolsAreaPane(
      header: AreaPaneHeader(
        roundedTopBorder: false,
        includeTopBorder: false,
        title: const Text('Logs'),
        actions: [
          DevToolsTooltip(
            message: widget.isListening ? 'Pause' : 'Resume',
            child: DevToolsButton.iconOnly(
              icon: widget.isListening ? Icons.pause : Icons.play_arrow,
              onPressed: () => widget.onListeningChanged(!widget.isListening),
              outlined: false,
            ),
          ),
          const SizedBox(width: denseSpacing),
          DevToolsTooltip(
            message: 'Clear all logs',
            child: DevToolsButton.iconOnly(
              icon: Icons.delete_outline,
              onPressed: widget.onClearLogs,
              outlined: false,
            ),
          ),
          const SizedBox(width: denseSpacing),
          DevToolsToggleButton(
            icon: Icons.history,
            isSelected: widget.preserveLogs,
            onPressed: () => widget.onPreserveChanged(!widget.preserveLogs),
            message: 'Preserve logs across hot reloads',
            outlined: false,
          ),
          const SizedBox(width: denseSpacing),
          DevToolsToggleButton(
            icon: Icons.unfold_more,
            isSelected: widget.autoScroll,
            onPressed: () => widget.onAutoScrollChanged(!widget.autoScroll),
            message: 'Auto-scroll to bottom',
            outlined: false,
          ),
        ],
      ),
      child: widget.logs.isEmpty
          ? const _EmptyLogsPlaceholder()
          : ListView.builder(
              controller: _scrollController,
              itemExtent: defaultRowHeight,
              itemCount: widget.logs.length,
              itemBuilder: (context, index) {
                final log = widget.logs[index];
                final isMatched = widget.checkMatch(log);
                return _LogListRow(
                  log: log,
                  index: index,
                  isSelected: widget.selectedId == log.id,
                  isMatched: isMatched,
                  isFilterMode: widget.isFilterMode,
                  onTap: isMatched || !widget.isFilterMode
                      ? () => widget.onLogSelected(log.id)
                      : null,
                );
              },
            ),
    );
  }
}

/// Shown when the filtered log list is empty.
class _EmptyLogsPlaceholder extends StatelessWidget {
  const _EmptyLogsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        spacing: 16,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.segment_rounded, size: 48),
          Text(
            'No logs found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

/// A high-density table-style row for the log list.
class _LogListRow extends StatelessWidget {
  final LogEntry log;
  final int index;
  final bool isSelected;
  final bool isMatched;
  final bool isFilterMode;
  final VoidCallback? onTap;

  const _LogListRow({
    required this.log,
    required this.index,
    required this.isSelected,
    required this.isMatched,
    required this.isFilterMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: false,
      minVerticalPadding: 0,
      contentPadding: EdgeInsets.symmetric(horizontal: defaultSpacing),
      minTileHeight: defaultRowHeight,
      enabled: isFilterMode || isMatched,
      onTap: onTap,
      selected: isSelected,
      title: Text(log.messageString),
      trailing: Text(log.colonTime),
      leading: Icon(Icons.square_rounded, color: log.levelColor),
    );
  }
}
