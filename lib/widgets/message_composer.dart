// widgets/message_composer.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MessageComposer extends StatelessWidget {
  MessageComposer({
    required this.onSubmitted,
    required this.awaitingResponse,
    super.key,
  });

  final TextEditingController _messageController = TextEditingController();

  final void Function(String) onSubmitted;
  final bool awaitingResponse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.05),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: !awaitingResponse
                  ? TextField(
                      style: TextStyle(fontSize: 13.sp),
                      controller: _messageController,
                      onSubmitted: onSubmitted,
                      decoration: const InputDecoration(
                        hintText: '在这里写下您的信息...',
                        border: InputBorder.none,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 24.h,
                          width: 24.w,
                          child: CircularProgressIndicator(),
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('思考中...'),
                        ),
                      ],
                    ),
            ),
            IconButton(
              onPressed: !awaitingResponse
                  ? () => onSubmitted(_messageController.text)
                  : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
