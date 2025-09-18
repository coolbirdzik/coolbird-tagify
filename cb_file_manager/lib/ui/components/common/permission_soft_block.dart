import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef RequestCallback = Future<void> Function();

class PermissionSoftBlock extends StatelessWidget {
  final String title;
  final String message;
  final String ctaLabel;
  final RequestCallback onRequest;

  const PermissionSoftBlock({
    Key? key,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(onPressed: onRequest, child: Text(ctaLabel)),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final uri = Platform.isIOS
                          ? Uri.parse('app-settings:')
                          : Uri.parse('package:');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    child: const Text('Mở Cài đặt'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
