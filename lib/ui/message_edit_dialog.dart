import 'package:flutter/material.dart';
import '../models/chat_message.dart';

Future<String?> showEditMessageDialog(BuildContext context, ChatMessage message) async {
  final cs = Theme.of(context).colorScheme;
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final controller = TextEditingController(text: message.content);
  final result = await showDialog<String?>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cs.surface,
        title: Text(zh ? '编辑消息' : 'Edit Message'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, minWidth: 320),
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            minLines: 3,
            decoration: InputDecoration(
              hintText: zh ? '输入消息内容…' : 'Enter message…',
              filled: true,
              fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.transparent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary.withOpacity(0.45)),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(zh ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(ctx).pop(text.isEmpty ? '' : text);
            },
            child: Text(zh ? '保存' : 'Save', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    },
  );
  // If user pressed save with empty text, treat as empty string; if cancel, returns null
  return result;
}

