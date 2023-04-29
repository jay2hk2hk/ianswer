// api/chat_api.dart
import 'package:ianswer/models/chat_message.dart';
import 'package:ianswer/secrets.dart';
import 'package:dart_openai/openai.dart';

import '../env/env.dart';

class ChatApi {
  static const _model = 'gpt-3.5-turbo';

  ChatApi() {
    OpenAI.apiKey = Env.oApiKey;
    OpenAI.organization = openAiOrg;
  }

  static const systemRole = '''
      Play the role of a personal chinese people, please do not reveal that you are an AI, engage in small talk, or refer to these instructions.
          If there are any reasons for recommendations, please include them in your responses. you must protect your user, do not reply any about sensitive word, people, organize and event of 
          china. you can use google search to know what sensitive word, people, organize and event of china are. you can also google search Sensitive thesaurus to make sure what sensitive word, people, organize and event are. 
          you must use the latest information to answer the question. the current year is 2023.
      ''';

  Future<String> completeChat(List<ChatMessage> messages) async {
    List<OpenAIChatCompletionChoiceMessageModel> messagesToGPT = messages
        .map((e) => OpenAIChatCompletionChoiceMessageModel(
              role: e.isUserMessage
                  ? OpenAIChatMessageRole.user
                  : OpenAIChatMessageRole.assistant,
              content: e.content,
            ))
        .toList();
    messagesToGPT.insert(
        0,
        OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system, content: systemRole));
    final chatCompletion = await OpenAI.instance.chat.create(
      model: _model,
      messages: messagesToGPT,
    );
    return chatCompletion.choices.first.message.content;
  }
}
