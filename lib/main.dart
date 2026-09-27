import 'package:flutter/widgets.dart';
import 'app/app.dart';
import 'core/database/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const DeutschLernenApp());
}
