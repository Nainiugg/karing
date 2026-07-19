import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import 'import_screen.dart';
import 'results_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({required this.controller, super.key});

  final AppController controller;

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.input_rounded),
      selectedIcon: Icon(Icons.input_rounded),
      label: '导入',
    ),
    NavigationDestination(
      icon: Icon(Icons.radar_rounded),
      selectedIcon: Icon(Icons.radar_rounded),
      label: '检测',
    ),
    NavigationDestination(
      icon: Icon(Icons.fact_check_outlined),
      selectedIcon: Icon(Icons.fact_check_rounded),
      label: '结果',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final List<Widget> pages = <Widget>[
          ImportScreen(controller: controller),
          ScanScreen(controller: controller),
          ResultsScreen(controller: controller),
          SettingsScreen(controller: controller),
        ];

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 900;
            final Widget content = Column(
              children: <Widget>[
                if (controller.startupWarning case final String warning)
                  MaterialBanner(
                    content: Text(warning),
                    leading: const Icon(Icons.warning_amber_rounded),
                    actions: const <Widget>[SizedBox.shrink()],
                  ),
                if (controller.busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: IndexedStack(
                    index: controller.pageIndex,
                    children: pages,
                  ),
                ),
              ],
            );

            if (!wide) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Node Inspector'),
                  centerTitle: false,
                ),
                body: content,
                bottomNavigationBar: NavigationBar(
                  selectedIndex: controller.pageIndex,
                  onDestinationSelected: controller.selectPage,
                  destinations: _destinations,
                ),
              );
            }

            return Scaffold(
              body: Row(
                children: <Widget>[
                  SafeArea(
                    child: NavigationRail(
                      extended: constraints.maxWidth >= 1180,
                      selectedIndex: controller.pageIndex,
                      onDestinationSelected: controller.selectPage,
                      leading: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 24, 12, 28),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.travel_explore_rounded, size: 30),
                            if (constraints.maxWidth >= 1180) ...<Widget>[
                              const SizedBox(width: 12),
                              Text(
                                'Node Inspector',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ],
                        ),
                      ),
                      destinations: _destinations
                          .map(
                            (NavigationDestination destination) =>
                                NavigationRailDestination(
                              icon: destination.icon,
                              selectedIcon: destination.selectedIcon,
                              label: Text(destination.label),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
