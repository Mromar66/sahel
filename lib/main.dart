import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safwa/app/app.dart';
import 'package:safwa/core/services/auth_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthSession.instance.initialize();
  runApp(const ProviderScope(child: InventoryApp()));
}
