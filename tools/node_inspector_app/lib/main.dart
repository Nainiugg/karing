import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/app_controller.dart';
import 'storage/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppController controller = AppController(
    store: LocalJsonAppStore(LocalJsonAppStore.defaultFile()),
  );
  await controller.initialize();

  runApp(NodeInspectorApp(controller: controller));
}
