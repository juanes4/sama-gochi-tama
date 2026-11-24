import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_controller.dart';
import 'shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(DashboardApp(prefs: prefs));
}

class DashboardApp extends StatefulWidget {
  const DashboardApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  late final DashboardController _controller = DashboardController(widget.prefs);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard IoT · Equipo 01',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: DashboardShell(c: _controller),
    );
  }
}
