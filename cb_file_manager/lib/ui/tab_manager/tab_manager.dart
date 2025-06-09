import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math';
import 'tab_data.dart';
import 'package:flutter/material.dart';

/// Events for the TabManager
abstract class TabEvent {}

/// Event to add a new tab
class AddTab extends TabEvent {
  final String path;
  final String? name;
  final bool switchToTab;

  AddTab({
    required this.path,
    this.name,
    this.switchToTab = true,
  });
}

/// Event to switch to a tab
class SwitchToTab extends TabEvent {
  final String tabId;

  SwitchToTab(this.tabId);
}

/// Event to close a tab
class CloseTab extends TabEvent {
  final String tabId;

  CloseTab(this.tabId);
}

/// Event to update a tab's path
class UpdateTabPath extends TabEvent {
  final String tabId;
  final String newPath;

  UpdateTabPath(this.tabId, this.newPath);
}

/// Event to update a tab's name
class UpdateTabName extends TabEvent {
  final String tabId;
  final String newName;

  UpdateTabName(this.tabId, this.newName);
}

/// Event to toggle a tab's pinned status
class ToggleTabPin extends TabEvent {
  final String tabId;

  ToggleTabPin(this.tabId);
}

/// Event to add a path to tab navigation history
class AddToTabHistory extends TabEvent {
  final String tabId;
  final String path;

  AddToTabHistory(this.tabId, this.path);
}

/// State for the TabManager
class TabManagerState {
  final List<TabData> tabs;
  final String? activeTabId;

  TabManagerState({
    required this.tabs,
    this.activeTabId,
  });

  TabData? get activeTab => activeTabId != null
      ? tabs.firstWhere((tab) => tab.id == activeTabId,
          orElse: () => tabs.first)
      : (tabs.isNotEmpty ? tabs.first : null);

  TabManagerState copyWith({
    List<TabData>? tabs,
    String? activeTabId,
    bool clearActiveTabId = false,
  }) {
    return TabManagerState(
      tabs: tabs ?? this.tabs,
      activeTabId: clearActiveTabId ? null : (activeTabId ?? this.activeTabId),
    );
  }
}

/// BLoC for managing tabs
class TabManagerBloc extends Bloc<TabEvent, TabManagerState> {
  TabManagerBloc() : super(TabManagerState(tabs: [])) {
    on<AddTab>(_onAddTab);
    on<SwitchToTab>(_onSwitchToTab);
    on<CloseTab>(_onCloseTab);
    on<UpdateTabPath>(_onUpdateTabPath);
    on<UpdateTabName>(_onUpdateTabName);
    on<ToggleTabPin>(_onToggleTabPin);
    on<AddToTabHistory>(_onAddToTabHistory);
  }

  void _onAddTab(AddTab event, Emitter<TabManagerState> emit) {
    final random = Random();
    final newTabId =
        'tab_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}';

    final newTab = TabData(
      id: newTabId,
      name: event.name ?? _extractNameFromPath(event.path),
      path: event.path,
    );

    final tabs = List<TabData>.from(state.tabs)..add(newTab);

    emit(state.copyWith(
      tabs: tabs,
      activeTabId: event.switchToTab ? newTabId : state.activeTabId,
    ));
  }

  void _onSwitchToTab(SwitchToTab event, Emitter<TabManagerState> emit) {
    if (state.tabs.any((tab) => tab.id == event.tabId)) {
      emit(state.copyWith(activeTabId: event.tabId));
    }
  }

  void _onCloseTab(CloseTab event, Emitter<TabManagerState> emit) {
    if (state.tabs.isEmpty) return;

    final tabs = state.tabs.where((tab) => tab.id != event.tabId).toList();

    // If we're closing the active tab, switch to another tab
    String? newActiveTabId;
    if (state.activeTabId == event.tabId) {
      final closedTabIndex =
          state.tabs.indexWhere((tab) => tab.id == event.tabId);
      if (closedTabIndex >= 0 && tabs.isNotEmpty) {
        // Try to select the tab to the right, or if that's not possible, to the left
        final newSelectedIndex = min(closedTabIndex, tabs.length - 1);
        newActiveTabId = tabs[newSelectedIndex].id;
      } else {
        newActiveTabId = null;
      }
    } else {
      newActiveTabId = state.activeTabId;
    }

    emit(state.copyWith(
      tabs: tabs,
      activeTabId: newActiveTabId,
      clearActiveTabId: newActiveTabId == null,
    ));
  }

  void _onUpdateTabPath(UpdateTabPath event, Emitter<TabManagerState> emit) {
    // Check if the path is actually changing
    final currentTab = state.tabs.firstWhere(
      (tab) => tab.id == event.tabId,
      orElse: () => TabData(id: '', name: '', path: ''),
    );

    // If the path is the same as the current path, don't update
    if (currentTab.path == event.newPath) {
      debugPrint(
          "TabManagerBloc: Skipping tab path update - path unchanged: ${event.newPath}");
      return;
    }

    debugPrint(
        "TabManagerBloc: Updating tab path from ${currentTab.path} to ${event.newPath}");

    final tabs = state.tabs.map((tab) {
      if (tab.id == event.tabId) {
        // First add the new path to the navigation history of the existing tab
        tab.updatePath(event.newPath);

        // Then create a new tab instance with the updated path
        return tab.copyWith(path: event.newPath);
      }
      return tab;
    }).toList();

    emit(state.copyWith(tabs: tabs));
  }

  void _onUpdateTabName(UpdateTabName event, Emitter<TabManagerState> emit) {
    final tabs = state.tabs.map((tab) {
      if (tab.id == event.tabId) {
        return tab.copyWith(name: event.newName);
      }
      return tab;
    }).toList();

    emit(state.copyWith(tabs: tabs));
  }

  void _onToggleTabPin(ToggleTabPin event, Emitter<TabManagerState> emit) {
    final tabs = state.tabs.map((tab) {
      if (tab.id == event.tabId) {
        return TabData(
          id: tab.id,
          name: tab.name,
          path: tab.path,
          icon: tab.icon,
          isPinned: !tab.isPinned,
        );
      }
      return tab;
    }).toList();

    emit(state.copyWith(tabs: tabs));
  }

  void _onAddToTabHistory(
      AddToTabHistory event, Emitter<TabManagerState> emit) {
    final tabs = state.tabs.map((tab) {
      if (tab.id == event.tabId) {
        final List<String> updatedHistory = List.from(tab.navigationHistory);
        // Add path to history if it's different from the current path
        if (updatedHistory.isEmpty || updatedHistory.last != event.path) {
          updatedHistory.add(event.path);
        }
        return tab.copyWith(navigationHistory: updatedHistory);
      }
      return tab;
    }).toList();

    emit(state.copyWith(tabs: tabs));
  }

  String _extractNameFromPath(String path) {
    final pathParts = path.split('/');
    return pathParts.isEmpty || pathParts.last.isEmpty
        ? 'Root'
        : pathParts.last;
  }

  // Add methods for navigation history management
  bool canTabNavigateBack(String tabId) {
    final tab = state.tabs.firstWhere(
      (tab) => tab.id == tabId,
      orElse: () => TabData(id: '', name: '', path: ''),
    );
    return tab.navigationHistory.length > 1;
  }

  String? getTabPreviousPath(String tabId) {
    final tab = state.tabs.firstWhere(
      (tab) => tab.id == tabId,
      orElse: () => TabData(id: '', name: '', path: ''),
    );
    return tab.getPreviousPath();
  }

  // Handle backwards navigation for a tab and return the new path
  String? backNavigationToPath(String tabId) {
    // Find the tab with this ID
    final tabIndex = state.tabs.indexWhere((tab) => tab.id == tabId);
    if (tabIndex == -1) return null;

    // Get a mutable copy of the tabs
    final tabs = List<TabData>.from(state.tabs);

    // Navigate back for this specific tab
    final previousPath = tabs[tabIndex].navigateBack();
    if (previousPath != null) {
      // Update the tab with the new path
      tabs[tabIndex] = tabs[tabIndex].copyWith(path: previousPath);

      // Update state using add() instead of emit()
      add(UpdateTabPath(tabId, previousPath));

      // Return the path we navigated to
      return previousPath;
    }

    return null;
  }

  // Handle forwards navigation for a tab and return the new path
  String? forwardNavigationToPath(String tabId) {
    // Find the tab with this ID
    final tabIndex = state.tabs.indexWhere((tab) => tab.id == tabId);
    if (tabIndex == -1) return null;

    // Get a mutable copy of the tabs
    final tabs = List<TabData>.from(state.tabs);

    // Navigate forward for this specific tab
    final nextPath = tabs[tabIndex].navigateForward();
    if (nextPath != null) {
      // Update the tab with the new path
      tabs[tabIndex] = tabs[tabIndex].copyWith(path: nextPath);

      // Update state using add() instead of emit()
      add(UpdateTabPath(tabId, nextPath));

      // Return the path we navigated to
      return nextPath;
    }

    return null;
  }

  // Get the full navigation history for a tab
  List<String> getTabHistory(String tabId) {
    final tab = state.tabs.firstWhere(
      (tab) => tab.id == tabId,
      orElse: () => TabData(id: '', name: '', path: ''),
    );
    return List.from(tab.navigationHistory);
  }

  bool canTabNavigateForward(String tabId) {
    final tab = state.tabs.firstWhere(
      (tab) => tab.id == tabId,
      orElse: () => TabData(id: '', name: '', path: ''),
    );
    return tab.forwardHistory.isNotEmpty;
  }

  String? getTabNextPath(String tabId) {
    final tab = state.tabs.firstWhere(
      (tab) => tab.id == tabId,
      orElse: () => TabData(id: '', name: '', path: ''),
    );
    return tab.forwardHistory.isNotEmpty ? tab.forwardHistory.last : null;
  }
}

/// Helper class for working with the tab system
/// Serves as interface between network browsing and the tab system
class TabNavigator {
  /// Updates the path of a specific tab
  static void updateTabPath(BuildContext context, String tabId, String path) {
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);

    // Check if the path is actually different before updating
    final currentTab = tabBloc.state.tabs.firstWhere(
      (tab) => tab.id == tabId,
      orElse: () => TabData(id: '', name: '', path: ''),
    );

    // Only update if the path has actually changed
    if (currentTab.path != path) {
      tabBloc.add(UpdateTabPath(tabId, path));
      // Add path to tab history as well
      tabBloc.add(AddToTabHistory(tabId, path));
    } else {
      debugPrint("TabNavigator: Skipping path update - path unchanged: $path");
    }
  }

  /// Opens a new tab with the specified path
  static void openTab(BuildContext context, String path, {String? title}) {
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    tabBloc.add(AddTab(
      path: path,
      name: title ?? _extractNameFromPath(path),
      switchToTab: true,
    ));
  }

  /// Closes the specified tab
  static void closeTab(BuildContext context, String tabId) {
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    tabBloc.add(CloseTab(tabId));
  }

  /// Helper method to extract a name from a path
  static String _extractNameFromPath(String path) {
    final pathParts = path.split('/');
    return pathParts.isEmpty || pathParts.last.isEmpty
        ? 'Root'
        : pathParts.last;
  }
}
