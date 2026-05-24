import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'vpn_service.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E1A),
    ),
  );
  runApp(const VpnApp());
}

class VpnApp extends StatelessWidget {
  const VpnApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VpnService(),
      child: MaterialApp(
        title: 'SafeBoost',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0A0E1A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00D4FF),
            secondary: Color(0xFF00FF87),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
