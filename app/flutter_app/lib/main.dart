import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/runtime_config.dart';
import 'core/locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast when required runtime values are missing.
  final config = RuntimeConfig.fromEnvironment();
  config.validate();

  // Supabase session is the source of access tokens for API calls.
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  // Build application-wide data/network dependencies once at boot.
  await Locator.initialize(config);
  runApp(const RowingApp());
}
