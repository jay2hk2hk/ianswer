import 'package:ianswer/api/chat_api.dart';
import 'package:ianswer/chat_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(ChatApp(chatApi: ChatApi()));
}

class ChatApp extends StatelessWidget {
  const ChatApp({required this.chatApi, super.key});

  final ChatApi chatApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '我答',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 0, 35, 150),
          secondary: Color.fromARGB(255, 130, 57, 220),
        ),
      ),
      home: ChatPage(chatApi: chatApi),
    );
  }
}
