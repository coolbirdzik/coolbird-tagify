import 'package:flutter/material.dart';
import 'package:cb_file_manager/config/translation_helper.dart';

/// Utility class for common dialogs used throughout the application
class DialogUtils {
  /// Shows a confirmation dialog asking if the user wants to continue iteration
  ///
  /// Returns true if the user wants to continue, false otherwise
  static Future<bool> showContinueIterationDialog(
    BuildContext context, {
    String? title,
    String? message,
    String? continueText,
    String? cancelText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title ?? 'Continue?'),
          content: Text(message ?? 'Continue to iterate?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(cancelText ?? dialogContext.tr.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(continueText ?? dialogContext.tr.ok),
            ),
          ],
        );
      },
    );

    // Return false if dialog was dismissed without selection
    return result ?? false;
  }

  /// Shows a general confirmation dialog with customizable options
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(cancelText ?? dialogContext.tr.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(confirmText ?? dialogContext.tr.ok),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Shows a delete confirmation dialog
  static Future<bool> showDeleteConfirmationDialog(
    BuildContext context, {
    required bool isFile,
  }) async {
    final message = isFile
        ? context.tr.fileDeleteConfirmation
        : context.tr.folderDeleteConfirmation;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.tr.delete),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(dialogContext.tr.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(dialogContext.tr.delete),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
