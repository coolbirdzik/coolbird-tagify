import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/ui/shared/address_bar_widget.dart';

class MobileEmptyChromeBar extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onMenu;
  final VoidCallback onAddNewTab;
  final VoidCallback onMore;
  final VoidCallback onAddressTap;

  const MobileEmptyChromeBar({
    Key? key,
    required this.isDarkMode,
    required this.onMenu,
    required this.onAddNewTab,
    required this.onMore,
    required this.onAddressTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(EvaIcons.menu, color: textColor),
            onPressed: onMenu,
          ),
          Expanded(
            child: AddressBarWidget(
              path: "",
              name: "CoolBird Tagify",
              onTap: onAddressTap,
              isDarkMode: isDarkMode,
              showDropdownIndicator: true,
            ),
          ),
          IconButton(
            icon: Icon(EvaIcons.plus, color: textColor),
            tooltip: 'Add new tab',
            onPressed: onAddNewTab,
          ),
          IconButton(
            icon: Icon(EvaIcons.moreVertical, color: textColor),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

