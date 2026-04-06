import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../log_entry.dart';

/// The right panel displaying detailed information about a selected log entry.
///
/// Shows sections matching the DevTools UI:
/// - **MESSAGE PAYLOAD**: The raw log message text.
/// - **STRUCTURE**: A tree view of any structured data in the message.
/// - **ERROR**: The error object if present.
/// - **STACK TRACE**: A frame-by-frame view parsed from the raw trace.
class LogDetailPanel extends StatelessWidget {
  /// The log entry to display details for.
  final LogEntry log;

  const LogDetailPanel({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return DevToolsAreaPane(
      header: AreaPaneHeader(
        roundedTopBorder: false,
        includeTopBorder: false,
        title: const Text('Log Detail'),
        actions: [
          DevToolsTooltip(
            message: 'Copy log to clipboard',
            child: DevToolsButton.iconOnly(
              icon: Icons.copy_outlined,
              onPressed: () => _copyToClipboard(context),
              outlined: false,
            ),
          ),
        ],
      ),
      child: SelectionArea(child: _DetailContent(log: log)),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final buffer = StringBuffer()
      ..writeln('Level: ${log.levelLabel}')
      ..writeln('Time: ${log.time}')
      ..writeln('Message: ${log.messageString}');

    if (log.errorString != null) {
      buffer.writeln('Error: ${log.errorString}');
    }
    if (log.stackTraceString != null) {
      buffer.writeln('StackTrace: ${log.stackTraceString}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        width: 220,
      ),
    );
  }
}

/// Scrollable body containing all detail sections.
class _DetailContent extends StatelessWidget {
  final LogEntry log;

  const _DetailContent({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailSection(
            title: 'MESSAGE PAYLOAD',
            child: _CodeBlock(
              text: log.messageString,
              color: colorScheme.onSurface,
            ),
          ),
          PaddedDivider.vertical(),
          _DetailSection(
            title: 'STRUCTURE',
            child: _StructureView(
              messageString: log.messageString,
              parsedJson: log.parsedJson,
            ),
          ),
          if (log.errorString != null) ...[
            PaddedDivider.vertical(),
            _DetailSection(
              title: 'ERROR',
              child: _CodeBlock(
                text: log.errorString!,
                color: colorScheme.error,
                backgroundColor: colorScheme.errorContainer.withValues(
                  alpha: 0.1,
                ),
              ),
            ),
          ],
          if (log.parsedStackFrames.isNotEmpty) ...[
            PaddedDivider.vertical(),
            _DetailSection(
              title: 'STACK TRACE',
              child: _StackTraceView(
                frames: log.parsedStackFrames,
                isolateId: log.isolateId,
              ),
            ),
          ] else if (log.stackTraceString != null) ...[
            PaddedDivider.vertical(),
            _DetailSection(
              title: 'STACK TRACE',
              child: _CodeBlock(
                text: log.stackTraceString!,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A section header with a title label and content below.
class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: denseSpacing),
        child,
      ],
    );
  }
}

/// A styled monospace text container used for message, error, and stack trace.
class _CodeBlock extends StatelessWidget {
  final String text;
  final Color color;
  final Color? backgroundColor;

  const _CodeBlock({
    required this.text,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(defaultSpacing),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(denseSpacing),
      ),
      child: Text(text, style: theme.fixedFontStyle.copyWith(color: color)),
    );
  }
}

class _StructureView extends StatelessWidget {
  final String messageString;
  final Object? parsedJson;

  const _StructureView({required this.messageString, required this.parsedJson});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (parsedJson is Map || parsedJson is List) {
      return Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(denseSpacing),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(denseSpacing),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: _JsonTreeNode(data: parsedJson),
      );
    }

    return _CodeBlock(text: messageString, color: colorScheme.onSurfaceVariant);
  }
}

/// Renders a list of [ParsedStackFrame]s as a nicely formatted frame table.
class _StackTraceView extends StatelessWidget {
  final List<ParsedStackFrame> frames;
  final String isolateId;

  const _StackTraceView({required this.frames, required this.isolateId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(denseSpacing),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < frames.length; i++) ...[
            _StackFrameRow(
              frame: frames[i],
              isFirst: i == 0,
              isolateId: isolateId,
            ),
            if (i < frames.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
          ],
        ],
      ),
    );
  }
}

/// A single row in the stack trace view.
class _StackFrameRow extends StatelessWidget {
  final ParsedStackFrame frame;
  final bool isFirst;
  final String isolateId;

  const _StackFrameRow({
    required this.frame,
    required this.isFirst,
    required this.isolateId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final symbolStyle = theme.fixedFontStyle.copyWith(
      fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
      color: isFirst ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
    );

    final locationStyle = theme.fixedFontStyle.copyWith(
      fontSize: 11,
      color: isFirst ? colorScheme.primary : colorScheme.subtleTextColor,
    );

    return InkWell(
      onTap: () => _onFrameTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: defaultSpacing,
          vertical: denseSpacing,
        ),
        child: Row(
          spacing: denseSpacing,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FrameBadge(
              index: frame.index,
              style: locationStyle,
              isFirst: isFirst,
              colorScheme: colorScheme,
            ),
            Expanded(
              child: _LocationChip(
                frame: frame,
                style: locationStyle,
                isFirst: isFirst,
                colorScheme: colorScheme,
              ),
            ),
            if (frame.symbol.isNotEmpty)
              Text(
                frame.symbol,
                style: symbolStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onFrameTap(BuildContext context) async {
    final packageUri = '${frame.packagePrefix}${frame.path}';
    if (packageUri.isEmpty) return;

    String? fileUri = serviceManager.resolvedUriManager.lookupFileUri(
      isolateId,
      packageUri,
    );

    if (fileUri == null) {
      await serviceManager.resolvedUriManager.fetchFileUris(isolateId, [
        packageUri,
      ]);
      fileUri = serviceManager.resolvedUriManager.lookupFileUri(
        isolateId,
        packageUri,
      );
    }

    if (fileUri == null) return;

    int line = 1;
    int column = 1;
    if (frame.lineCol.isNotEmpty) {
      final parts = frame.lineCol.split(':');
      if (parts.isNotEmpty) line = int.tryParse(parts[0]) ?? 1;
      if (parts.length >= 2) column = int.tryParse(parts[1]) ?? 1;
    }

    serviceManager.service?.navigateToCode(
      fileUriString: fileUri,
      line: line,
      column: column,
      source: 'devtools.logger',
    );
  }
}

class _FrameBadge extends StatelessWidget {
  final int index;
  final TextStyle? style;
  final bool isFirst;
  final ColorScheme colorScheme;

  const _FrameBadge({
    required this.index,
    required this.style,
    required this.isFirst,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Text(
        '#$index',
        style: style?.copyWith(
          color: isFirst ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: isFirst ? FontWeight.bold : null,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  final ParsedStackFrame frame;
  final TextStyle? style;
  final bool isFirst;
  final ColorScheme colorScheme;

  const _LocationChip({
    required this.frame,
    required this.style,
    required this.isFirst,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrefix = frame.packagePrefix.isNotEmpty;
    return Text.rich(
      TextSpan(
        children: [
          if (hasPrefix) TextSpan(text: frame.packagePrefix),
          TextSpan(text: frame.path),
          if (frame.lineCol.isNotEmpty) TextSpan(text: frame.lineCol),
        ],
      ),
      style: theme.fixedFontStyle.copyWith(
        fontSize: 11,
        color: isFirst ? colorScheme.primary : colorScheme.subtleTextColor,
        fontWeight: isFirst || !hasPrefix ? FontWeight.bold : null,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── JSON tree ─────────────────────────────────────────────────────────────

/// A recursive tree node widget for displaying JSON data.
///
/// Maps are displayed with expandable keys, lists show indices,
/// and primitive values are displayed inline with type-based coloring.
class _JsonTreeNode extends StatefulWidget {
  final dynamic data;
  final String? keyName;
  final int depth;

  const _JsonTreeNode({required this.data, this.keyName, this.depth = 0});

  @override
  State<_JsonTreeNode> createState() => _JsonTreeNodeState();
}

class _JsonTreeNodeState extends State<_JsonTreeNode> {
  bool _isExpanded = true;

  bool get _isExpandable => widget.data is Map || widget.data is List;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = theme.fixedFontStyle;

    if (!_isExpandable) {
      return _LeafNode(
        depth: widget.depth,
        label: widget.keyName ?? '',
        value: widget.data,
        style: style,
        colorScheme: colorScheme,
      );
    }

    final entries = widget.data is Map
        ? (widget.data as Map).entries.toList()
        : (widget.data as List).asMap().entries.toList();

    final bracket = widget.data is Map ? ('{', '}') : ('[', ']');
    final hasKey = widget.keyName != null;
    final prefix = hasKey ? '"${widget.keyName}": ' : '';

    return Padding(
      padding: EdgeInsets.only(left: widget.depth == 0 ? 0 : largeSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            hoverColor: colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(densePadding),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: borderPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    size: defaultIconSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    _isExpanded
                        ? '$prefix${bracket.$1}'
                        : '$prefix${bracket.$1}...${bracket.$2}',
                    style: style.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: hasKey ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            ...entries.map(
              (entry) => _JsonTreeNode(
                data: entry.value,
                keyName: entry.key.toString(),
                depth: widget.depth + 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: largeSpacing),
              child: Text(
                bracket.$2,
                style: style.copyWith(color: colorScheme.onSurface),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A leaf node (non-expandable) in the JSON tree.
class _LeafNode extends StatelessWidget {
  final int depth;
  final String label;
  final dynamic value;
  final TextStyle style;
  final ColorScheme colorScheme;

  const _LeafNode({
    required this.depth,
    required this.label,
    required this.value,
    required this.style,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: depth == 0 ? 0 : largeSpacing,
        top: borderPadding,
        bottom: borderPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: largeSpacing),
          if (label.isNotEmpty) ...[
            Text(
              '"$label": ',
              style: style.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          Flexible(
            child: Text(
              _formatValue(value),
              style: style.copyWith(color: _valueColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic v) {
    if (v is String) return '"$v"';
    return v.toString();
  }

  Color get _valueColor {
    final isDark = colorScheme.brightness == Brightness.dark;
    if (value is String) {
      return isDark ? Colors.green.shade300 : Colors.green.shade700;
    }
    if (value is num) {
      return isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    }
    if (value is bool) {
      return isDark ? Colors.orange.shade300 : Colors.orange.shade700;
    }
    if (value == null) {
      return colorScheme.outline;
    }
    return colorScheme.onSurface;
  }
}
