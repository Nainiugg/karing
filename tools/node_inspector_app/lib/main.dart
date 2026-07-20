import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/app_controller.dart';
import 'services/sing_box_node_probe.dart';
import 'storage/app_secret_store.dart';
import 'storage/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppController controller = AppController(
    store: LocalJsonAppStore(LocalJsonAppStore.defaultFile()),
    secretStore: WindowsDpapiSecretStore(WindowsDpapiSecretStore.defaultFile()),
    probe: SingBoxNodeProbe(),
  );
  await controller.initialize();

  runApp(NodeInspectorApp(controller: controller));
}
