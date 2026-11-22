import 'package:flutter/material.dart';

import 'data/wms_database.dart';
import 'screens/home_screen.dart';

class NaeemSoftWmsApp extends StatelessWidget {
  const NaeemSoftWmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NaeemSoft WMS',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B55)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: FutureBuilder(
        future: WmsDatabase.instance.database,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('تعذر فتح قاعدة البيانات: ${snapshot.error}')),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
