import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/login_page.dart';
import 'sdk/logging/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 IM 日志系统
  await ImFileLogger.init();
  imLogInfo('App started', tag: ImLogTags.lifecycle);

  runApp(const ProviderScope(child: ImSdkDemoApp()));
}

class ImSdkDemoApp extends StatelessWidget {
  const ImSdkDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '畅聊天下',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const LoginPage(),
    );
  }
}
