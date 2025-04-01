import 'package:flutter/material.dart';
import 'responsive_grid.dart';


enum NavigationType {
  bottom,
  rail,
  drawer,
}


class AdaptiveScaffold extends StatelessWidget {
  final String title;
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? bottomSheet;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottomSheet,
  });

  @override
  Widget build(BuildContext context) {
    
    return ResponsiveBuilder(
      builder: (context, breakpoint) {
        final navigationType = _getNavigationType(breakpoint);

        
        switch (navigationType) {
          case NavigationType.rail:
            return _buildWithNavigationRail(context);
          case NavigationType.drawer:
            return _buildWithNavigationDrawer(context);
          case NavigationType.bottom:
          default:
            return _buildWithBottomBar(context);
        }
      },
    );
  }

  NavigationType _getNavigationType(BreakpointSize breakpoint) {
    if (breakpoint == BreakpointSize.xs) {
      return NavigationType.bottom;
    } else if (breakpoint == BreakpointSize.sm ||
        breakpoint == BreakpointSize.md) {
      return NavigationType.rail;
    } else {
      return NavigationType.drawer;
    }
  }

  Widget _buildWithBottomBar(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
      floatingActionButton: floatingActionButton,
      bottomSheet: bottomSheet,
    );
  }

  Widget _buildWithNavigationRail(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.selected,
            destinations: destinations.map((destination) {
              return NavigationRailDestination(
                icon: destination.icon,
                selectedIcon: destination.selectedIcon ?? destination.icon,
                label: Text((destination.label as Text).data ?? ''),
              );
            }).toList(),
            backgroundColor: colorScheme.surface,
            selectedIconTheme: IconThemeData(color: colorScheme.primary),
            unselectedIconTheme:
                IconThemeData(color: colorScheme.onSurfaceVariant),
            selectedLabelTextStyle: TextStyle(color: colorScheme.primary),
            unselectedLabelTextStyle:
                TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomSheet: bottomSheet,
    );
  }

  Widget _buildWithNavigationDrawer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.primary,
              ),
              child: Center(
                child: Text(
                  'Banco Digital',
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            for (int i = 0; i < destinations.length; i++)
              ListTile(
                leading: Icon(
                  i == selectedIndex
                      ? (destinations[i].selectedIcon as Icon).icon
                      : (destinations[i].icon as Icon).icon,
                  color: i == selectedIndex
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  (destinations[i].label as Text).data ?? '',
                  style: textTheme.bodyLarge?.copyWith(
                    color: i == selectedIndex
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                selected: i == selectedIndex,
                onTap: () {
                  onDestinationSelected(i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomSheet: bottomSheet,
    );
  }
}
