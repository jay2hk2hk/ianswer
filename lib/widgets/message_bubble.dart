// widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:markdown_widget/markdown_widget.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.content,
    required this.isUserMessage,
    super.key,
  });

  final String content;
  final bool isUserMessage;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isUserMessage
            ? themeData.colorScheme.primary.withOpacity(0.4)
            : themeData.colorScheme.secondary.withOpacity(0.4),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isUserMessage ? '你' : '你问我答',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              content,
              style: TextStyle(fontSize: 13.sp),
            ),
            /*MarkdownWidget(
              data: content,
              shrinkWrap: true,
            ),*/
          ],
        ),
      ),
    );
  }
}
