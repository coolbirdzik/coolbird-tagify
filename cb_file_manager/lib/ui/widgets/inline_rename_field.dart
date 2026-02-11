import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/inline_rename_controller.dart';

/// A widget that displays an inline text field for renaming files/folders.
///
/// This widget is used on desktop platforms to provide Windows Explorer-like
/// inline renaming functionality.
class InlineRenameField extends StatefulWidget {
  /// The controller managing the rename state.
  final InlineRenameController controller;

  /// Called when the rename is committed (Enter pressed or focus lost).
  final Future<void> Function() onCommit;

  /// Called when the rename is cancelled (Escape pressed).
  final VoidCallback onCancel;

  /// Text style for the text field.
  final TextStyle? textStyle;

  /// Text alignment.
  final TextAlign textAlign;

  /// Maximum number of lines.
  final int maxLines;

  const InlineRenameField({
    Key? key,
    required this.controller,
    required this.onCommit,
    required this.onCancel,
    this.textStyle,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  }) : super(key: key);

  @override
  State<InlineRenameField> createState() => _InlineRenameFieldState();
}

class _InlineRenameFieldState extends State<InlineRenameField> {
  @override
  void initState() {
    super.initState();
    // Listen for focus changes to cancel rename when focus is lost
    widget.controller.focusNode?.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.controller.focusNode?.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    // If focus is lost, cancel the rename
    if (widget.controller.focusNode != null &&
        !widget.controller.focusNode!.hasFocus) {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onCancel();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onCommit();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      // Use TextField instead of EditableText for full text selection support
      // TextField automatically handles drag-to-select gestures
      child: TextField(
        controller: widget.controller.textController!,
        focusNode: widget.controller.focusNode!,
        style: widget.textStyle ??
            theme.textTheme.bodySmall!.copyWith(fontSize: 12),
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        autofocus: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),
          isDense: true,
        ),
        cursorColor: theme.colorScheme.primary,
        onSubmitted: (_) => widget.onCommit(),
      ),
    );
  }
}
