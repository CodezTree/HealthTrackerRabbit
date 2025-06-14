import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rabbithole_health_tracker_new/screens/main_screen.dart';
import 'package:rabbithole_health_tracker_new/screens/pairing_screen.dart';
import 'package:rabbithole_health_tracker_new/providers/ble_provider.dart';
import 'package:rabbithole_health_tracker_new/services/local_db_service.dart';
import 'screens/login_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/background_service.dart';

Future<void> requestPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  await LocalDbService.init();
  await BackgroundService.initialize();

  final container =
      ProviderContainer(); // for accessing providers before runApp
  final bleService = container.read(bleServiceProvider);

  // Testing Without BLE
  const bool testWithoutBLE = false;
  const bool skipLogin = true;

  final reconnected = testWithoutBLE
      ? true
      : await bleService.tryReconnectFromSavedDevice();

  // final reconnected = await bleService.tryReconnectFromSavedDevice();

  // Schedule periodic BLE read every 30 minutes
  Timer.periodic(const Duration(minutes: 30), (_) {
    bleService.measureHealthData(); // Using the correct method name
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(initialConnected: reconnected, skipLogin: skipLogin),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool initialConnected;
  final bool skipLogin;

  const MyApp({
    super.key,
    required this.initialConnected,
    required this.skipLogin,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: skipLogin
          ? const PairingScreen()
          : (initialConnected ? const MainScreen() : const LoginScreen()),
    );
  }
}
