// @dart=3.0
// Flutter web bootstrap script for package:inflow_web/main.dart.
//
// Generated file. Do not edit.
//

// ignore_for_file: type=lint

import 'models/product.dart';
import 'models/sales_order_line.dart';
import 'models/purchase_order_line.dart';
import 'models/inventory_transaction.dart';
import 'services/column_inspector_service.dart'; // already there if needed
import 'services/dataset_analysis_service.dart'; // already there if needed
import 'dart:ui_web' as ui_web;
import 'dart:async';

import 'package:inflow_web/main.dart' as entrypoint;
import 'web_plugin_registrant.dart' as pluginRegistrant;

typedef _UnaryFunction = dynamic Function(List<String> args);
typedef _NullaryFunction = dynamic Function();

Future<void> main() async {
  await ui_web.bootstrapEngine(
    runApp: () {
      if (entrypoint.main is _UnaryFunction) {
        return (entrypoint.main as _UnaryFunction)(<String>[]);
      }
      return (entrypoint.main as _NullaryFunction)();
    },
    registerPlugins: () {
      pluginRegistrant.registerPlugins();
    },
  );
}
