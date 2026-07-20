import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_inspector_app/app.dart';
import 'package:node_inspector_app/controllers/app_controller.dart';
import 'package:node_inspector_app/storage/app_store.dart';
import 'package:node_inspector_app/widgets/app_background.dart';

void main() {
  testWidgets('application exposes all four primary destinations', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AppController controller = AppController(store: MemoryAppStore());
    await controller.initialize();

    await tester.pumpWidget(NodeInspectorApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Node Inspector'), findsOneWidget);
    expect(find.text('导入'), findsOneWidget);
    expect(find.text('检测'), findsOneWidget);
    expect(find.text('结果'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('导入节点'), findsOneWidget);
    expect(find.byType(AppBackground), findsOneWidget);
  });
}
