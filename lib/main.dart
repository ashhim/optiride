import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/connection_controller.dart';
import 'controllers/gyro_controller.dart';
import 'controllers/joystick_controller.dart';
import 'controllers/light_controller.dart';
import 'controllers/motion_controller.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/stream_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OptiRideApp());
}

class OptiRideApp extends StatelessWidget {
  const OptiRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1DE9B6),
      brightness: Brightness.dark,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionController()),
        ProxyProvider<ConnectionController, ApiService>(
          update: (_, connection, api) {
            final service = api ?? ApiService();
            service.setBaseUri(connection.baseUri);
            return service;
          },
        ),
        ChangeNotifierProxyProvider<ApiService, MotionController>(
          create: (_) => MotionController(),
          update: (_, api, motion) {
            final controller = motion ?? MotionController();
            controller.bind(api);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<ApiService, LightController>(
          create: (_) => LightController(),
          update: (_, api, light) {
            final controller = light ?? LightController();
            controller.bind(api);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<MotionController, JoystickController>(
          create: (_) => JoystickController(),
          update: (_, motion, joystick) {
            final controller = joystick ?? JoystickController();
            controller.bind(motion);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<MotionController, GyroController>(
          create: (_) => GyroController(),
          update: (_, motion, gyro) {
            final controller = gyro ?? GyroController();
            controller.bind(motion);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<ApiService, StreamService>(
          create: (_) => StreamService(),
          update: (_, api, stream) {
            final controller = stream ?? StreamService();
            controller.bind(api);
            return controller;
          },
        ),
      ],
      child: MaterialApp(
        title: 'OptiRide Controller',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: const Color(0xFF05070C),
          textTheme: Typography.whiteCupertino.copyWith(
            bodyMedium: const TextStyle(color: Colors.white70),
            bodySmall: const TextStyle(color: Colors.white60),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF0D1220),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0x2236E6C5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0x2236E6C5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF1DE9B6), width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF132130),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
