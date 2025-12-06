import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/config/app_theme.dart';
import 'package:cb_file_manager/config/translation_helper.dart';

class DrawerHeaderWidget extends StatelessWidget {
  final bool isPinned;
  final Function(bool) onPinStateChanged;

  const DrawerHeaderWidget({
    Key? key,
    required this.isPinned,
    required this.onPinStateChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.darkBlue,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo with shadow effect
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 32,
                  width: 32,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    remix.Remix.folder_5_fill,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    context.tr.appTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Pin button (hidden on small screens)
              if (!isSmallScreen)
                IconButton(
                  icon: Icon(
                    isPinned
                        ? remix.Remix.pushpin_fill
                        : remix.Remix.pushpin_line,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: isPinned ? 'Unpin menu' : 'Pin menu',
                  onPressed: () {
                    onPinStateChanged(!isPinned);
                  },
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            'File Management Made Simple',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
