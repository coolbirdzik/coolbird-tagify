import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

/// Component to display error messages with appropriate styling and actions
class ErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onGoBack;
  final bool isNetworkPath;

  const ErrorView({
    Key? key,
    required this.errorMessage,
    required this.onRetry,
    required this.onGoBack,
    this.isNetworkPath = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNetworkPath ? EvaIcons.wifiOff : EvaIcons.alertCircle,
            size: 72,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onGoBack,
                child: Text(isNetworkPath ? 'Close Connection' : 'Go Back'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(isNetworkPath ? 'Try Again' : 'Retry'),
              ),
            ],
          ),
          if (isNetworkPath) ...[
            const SizedBox(height: 16),
            const Text(
              'If this error persists, check your network connection and the server status.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
