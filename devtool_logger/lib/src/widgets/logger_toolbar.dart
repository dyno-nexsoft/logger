import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../log_level_color.dart';

/// A toolbar for the logger extension with search, regex toggle,
/// level filter chips, preserve toggle, and clear action.
///
/// Matches the DevTools-style toolbar layout with [FilterChip]s
/// for log levels displayed inline.
class LoggerToolbar extends StatelessWidget {
  /// The current search query text.
  final String searchQuery;

  /// The currently selected log level filter.
  final Level selectedLevel;

  /// Whether regex search mode is enabled.
  final bool useRegex;

  /// Whether logs are being filtered (hidden) or just searched (dimmed).
  final bool isFilterMode;

  /// Called when the search query changes.
  final ValueChanged<String> onSearchChanged;

  /// Called when a level filter chip is selected.
  final ValueChanged<Level> onLevelChanged;

  /// Called when the regex toggle is tapped.
  final ValueChanged<bool> onRegexChanged;

  /// Called when the search/filter mode is toggled.
  final ValueChanged<bool> onFilterModeChanged;

  const LoggerToolbar({
    super.key,
    required this.searchQuery,
    required this.selectedLevel,
    required this.useRegex,
    required this.isFilterMode,
    required this.onSearchChanged,
    required this.onLevelChanged,
    required this.onRegexChanged,
    required this.onFilterModeChanged,
  });

  /// The log levels displayed as filter chips in the toolbar.
  static const _filterLevels = [
    Level.trace,
    Level.debug,
    Level.info,
    Level.warning,
    Level.error,
    Level.fatal,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: denseSpacing,
      children: [
        Expanded(
          child: _SearchField(
            query: searchQuery,
            useRegex: useRegex,
            isFilterMode: isFilterMode,
            onChanged: onSearchChanged,
            onRegexToggled: () => onRegexChanged(!useRegex),
            onFilterModeToggled: () => onFilterModeChanged(!isFilterMode),
          ),
        ),
        ..._filterLevels.map(
          (level) => _LevelFilterChip(
            level: level,
            isSelected: selectedLevel == level,
            onSelected: () {
              if (selectedLevel == level) {
                onLevelChanged(Level.all);
              } else {
                onLevelChanged(level);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// A search text field with an inline regex toggle icon.
///
/// Properly owns its [TextEditingController] to avoid memory leaks.
class _SearchField extends StatefulWidget {
  final String query;
  final bool useRegex;
  final bool isFilterMode;
  final ValueChanged<String> onChanged;
  final VoidCallback onRegexToggled;
  final VoidCallback onFilterModeToggled;

  const _SearchField({
    required this.query,
    required this.useRegex,
    required this.isFilterMode,
    required this.onChanged,
    required this.onRegexToggled,
    required this.onFilterModeToggled,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query && widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultTextFieldHeight,
      child: DevToolsClearableTextField(
        controller: _controller,
        onChanged: widget.onChanged,
        hintText: widget.isFilterMode ? 'Filter logs' : 'Search logs',
        prefixIcon: const Icon(Icons.search, size: defaultIconSize),
        additionalSuffixActions: [
          InputDecorationSuffixButton(
            onPressed: widget.onRegexToggled,
            icon: Icons.emergency,
            tooltip: 'Use Regular Expression',
          ),
          InputDecorationSuffixButton(
            onPressed: widget.onFilterModeToggled,
            icon: widget.isFilterMode ? Icons.filter_alt : Icons.search,
            tooltip: widget.isFilterMode
                ? 'Filter mode: Hiding non-matches'
                : 'Search mode: Dimming non-matches',
          ),
        ],
      ),
    );
  }
}

/// A single filter chip for a log level.
///
/// Uses [FilterChip] to toggle between active and inactive states
/// with a color matching the log level severity.
class _LevelFilterChip extends StatelessWidget {
  final Level level;
  final bool isSelected;
  final VoidCallback onSelected;

  const _LevelFilterChip({
    required this.level,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(
        level.label,
        style: theme.subtleTextStyle.copyWith(color: Colors.white),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      color: WidgetStatePropertyAll(level.color),
    );
  }
}
