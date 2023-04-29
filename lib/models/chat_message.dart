// models/chat_message.dart

import 'package:dart_openai/openai.dart';

class ChatMessage {
  ChatMessage(this.content, this.isUserMessage);

  final String content;
  final bool isUserMessage;
}
