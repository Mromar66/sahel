import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/core/utils/constants.dart';

class DexefNavigationScope extends InheritedWidget {
  const DexefNavigationScope({
    super.key,
    required this.navigationShell,
    required this.branchPaths,
    required super.child,
  });

  final StatefulNavigationShell navigationShell;
  final List<String> branchPaths;

  static DexefNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DexefNavigationScope>();

  int? branchIndexFor(String route) {
    final path = Uri.parse(route).path;
    if (path == '/treasury') {
      return branchPaths.indexOf('/treasury-movement');
    }
    var bestIndex = -1;
    var bestLength = -1;
    for (var index = 0; index < branchPaths.length; index++) {
      final branchPath = branchPaths[index];
      if ((path == branchPath || path.startsWith('$branchPath/')) &&
          branchPath.length > bestLength) {
        bestIndex = index;
        bestLength = branchPath.length;
      }
    }
    return bestIndex < 0 ? null : bestIndex;
  }

  @override
  bool updateShouldNotify(DexefNavigationScope oldWidget) =>
      navigationShell != oldWidget.navigationShell ||
      branchPaths != oldWidget.branchPaths;
}

class DexefWindowTab {
  const DexefWindowTab({required this.route, required this.label});

  final String route;
  final String label;
}

class DexefWindowTabs {
  static final ValueNotifier<List<DexefWindowTab>> tabs = ValueNotifier([
    const DexefWindowTab(route: AppRoutes.home, label: 'الرئيسية'),
  ]);
  static final Map<int, String> activeRouteByBranch = {};

  static void remember(String route, String label, {int? branchIndex}) {
    if (branchIndex != null) activeRouteByBranch[branchIndex] = route;
    final current = tabs.value;
    final index = current.indexWhere((tab) => tab.route == route);
    if (index >= 0) {
      if (current[index].label == label) return;
      final updated = [...current];
      updated[index] = DexefWindowTab(route: route, label: label);
      tabs.value = updated;
      return;
    }
    tabs.value = [...current, DexefWindowTab(route: route, label: label)];
  }

  static void close(String route) {
    if (route == AppRoutes.home) return;
    tabs.value = tabs.value.where((tab) => tab.route != route).toList();
    activeRouteByBranch.removeWhere((_, activeRoute) => activeRoute == route);
  }
}

void removeCurrentAppTab(BuildContext context) {
  final route = GoRouter.of(context).routeInformationProvider.value.uri
      .toString();
  DexefWindowTabs.close(route);
}

/// Opens pages in their own retained navigator, like DEXEF's open windows.
void openAppWindowTab(BuildContext context, String route) {
  final currentRoute = GoRouter.of(context).routeInformationProvider.value.uri
      .toString();
  if (route == currentRoute) return;

  final navigation = DexefNavigationScope.maybeOf(context);
  final branchIndex = navigation?.branchIndexFor(route);
  if (navigation != null && branchIndex != null) {
    final rememberedRoute = DexefWindowTabs.activeRouteByBranch[branchIndex];
    if (branchIndex != navigation.navigationShell.currentIndex) {
      navigation.navigationShell.goBranch(branchIndex);
    }
    if (rememberedRoute != route) {
      context.go(route);
    }
    return;
  }
  context.push(route);
}
