import 'package:ianswer/api/chat_api.dart';
import 'package:ianswer/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() {
  runApp(ChatApp(chatApi: ChatApi()));
}

class ChatApp extends StatelessWidget {
  const ChatApp({required this.chatApi, super.key});

  final ChatApi chatApi;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: '你问我答',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Color.fromARGB(255, 0, 35, 150),
                secondary: Color.fromARGB(255, 130, 57, 220),
              ),
            ),
            home: child,
          );
        },
        child: ChatPage(chatApi: chatApi));
  }
}
