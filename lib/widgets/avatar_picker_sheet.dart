import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:characters/characters.dart';
import 'dart:math' as math;

enum AvatarType { image, emoji, url, qq }

class AvatarPickerResult {
  final AvatarType type;
  final String value;

  AvatarPickerResult({required this.type, required this.value});
}

Future<AvatarPickerResult?> showAvatarPicker({
  required BuildContext context,
  bool showRemoveOption = false,
}) async {
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  return await showModalBottomSheet<AvatarPickerResult>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(zh ? '选择图片' : 'Choose Image'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final result = await _pickLocalImage(context);
                if (result != null) {
                  Navigator.of(context).maybePop(result);
                }
              },
            ),
            ListTile(
              title: Text(zh ? '选择表情' : 'Choose Emoji'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final emoji = await _pickEmoji(context);
                if (emoji != null) {
                  Navigator.of(context).maybePop(
                    AvatarPickerResult(type: AvatarType.emoji, value: emoji),
                  );
                }
              },
            ),
            ListTile(
              title: Text(zh ? '输入链接' : 'Enter Link'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final url = await _inputAvatarUrl(context);
                if (url != null && url.trim().isNotEmpty) {
                  Navigator.of(context).maybePop(
                    AvatarPickerResult(type: AvatarType.url, value: url.trim()),
                  );
                }
              },
            ),
            ListTile(
              title: Text(zh ? 'QQ头像' : 'Import from QQ'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final result = await _inputQQAvatar(context);
                if (result != null) {
                  Navigator.of(context).maybePop(result);
                }
              },
            ),
            if (showRemoveOption)
              ListTile(
                title: Text(zh ? '重置' : 'Reset'),
                onTap: () {
                  Navigator.of(ctx).pop(
                    AvatarPickerResult(type: AvatarType.image, value: ''),
                  );
                },
              ),
            const SizedBox(height: 4),
          ],
        ),
      );
    },
  );
}

Future<AvatarPickerResult?> _pickLocalImage(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 90,
    );
    if (file != null) {
      return AvatarPickerResult(type: AvatarType.image, value: file.path);
    }
  } catch (_) {}
  return null;
}

Future<String?> _pickEmoji(BuildContext context) async {
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final controller = TextEditingController();
  String value = '';
  bool validGrapheme(String s) {
    final trimmed = s.characters.take(1).toString().trim();
    return trimmed.isNotEmpty && trimmed == s.trim();
  }
  final List<String> quick = const [
    '😀','😁','😂','🤣','😃','😄','😅','😊','😍','😘','😗','😙','😚','🙂','🤗','🤩','🫶','🤝','👍','👎','👋','🙏','💪','🔥','✨','🌟','💡','🎉','🎊','🎈','🌈','☀️','🌙','⭐','⚡','☁️','❄️','🌧️','🍎','🍊','🍋','🍉','🍇','🍓','🍒','🍑','🥭','🍍','🥝','🍅','🥕','🌽','🍞','🧀','🍔','🍟','🍕','🌮','🌯','🍣','🍜','🍰','🍪','🍩','🍫','🍻','☕','🧋','🥤','⚽','🏀','🏈','🎾','🏐','🎮','🎧','🎸','🎹','🎺','📚','✏️','💼','💻','🖥️','📱','🛩️','✈️','🚗','🚕','🚙','🚌','🚀','🛰️','🧠','🫀','💊','🩺','🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵'
  ];
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return StatefulBuilder(builder: (ctx, setLocal) {
        final media = MediaQuery.of(ctx);
        final avail = media.size.height - media.viewInsets.bottom;
        final double gridHeight = (avail * 0.28).clamp(120.0, 220.0);
        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: cs.surface,
          title: Text(zh ? '选择表情' : 'Choose Emoji'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    value.isEmpty ? '🙂' : value.characters.take(1).toString(),
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (v) => setLocal(() => value = v),
                  onSubmitted: (_) {
                    if (validGrapheme(value)) {
                      Navigator.of(ctx).pop(value.characters.take(1).toString());
                    }
                  },
                  decoration: InputDecoration(
                    hintText: zh ? '输入或粘贴任意表情' : 'Type or paste any emoji',
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.white10
                        : const Color(0xFFF2F3F5),
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
                      borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: gridHeight,
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: quick.length,
                    itemBuilder: (c, i) {
                      final e = quick[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(ctx).pop(e),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(e, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(zh ? '取消' : 'Cancel'),
            ),
            TextButton(
              onPressed: validGrapheme(value)
                  ? () => Navigator.of(ctx).pop(value.characters.take(1).toString())
                  : null,
              child: Text(
                zh ? '保存' : 'Save',
                style: TextStyle(
                  color: validGrapheme(value)
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.38),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      });
    },
  );
}

Future<String?> _inputAvatarUrl(BuildContext context) async {
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(zh ? '输入链接' : 'Enter Link'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: zh ? '例如：https://...' : 'e.g., https://...',
        ),
        onSubmitted: (_) => Navigator.of(ctx).pop(true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(zh ? '取消' : 'Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(zh ? '确定' : 'OK'),
        ),
      ],
    ),
  );
  if (ok == true) {
    final url = controller.text.trim();
    if (url.isNotEmpty) {
      return url;
    }
  }
  return null;
}

Future<AvatarPickerResult?> _inputQQAvatar(BuildContext context) async {
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      String value = '';
      bool valid(String s) => RegExp(r'^[0-9]{5,12}$').hasMatch(s.trim());
      String randomQQ() {
        final lengths = <int>[5, 6, 7, 8, 9, 10, 11];
        final weights = <int>[1, 20, 80, 100, 240, 3000, 80];
        final total = weights.fold<int>(0, (a, b) => a + b);
        final rnd = math.Random();
        int roll = rnd.nextInt(total) + 1;
        int chosenLen = lengths.last;
        int acc = 0;
        for (int i = 0; i < lengths.length; i++) {
          acc += weights[i];
          if (roll <= acc) {
            chosenLen = lengths[i];
            break;
          }
        }
        final sb = StringBuffer();
        final firstGroups = <List<int>>[
          [1, 2],
          [3, 4],
          [5, 6, 7, 8],
          [9],
        ];
        final firstWeights = <int>[8, 4, 2, 1];
        final firstTotal = firstWeights.fold<int>(0, (a, b) => a + b);
        int r2 = rnd.nextInt(firstTotal) + 1;
        int idx = 0;
        int a2 = 0;
        for (int i = 0; i < firstGroups.length; i++) {
          a2 += firstWeights[i];
          if (r2 <= a2) {
            idx = i;
            break;
          }
        }
        final group = firstGroups[idx];
        sb.write(group[rnd.nextInt(group.length)]);
        for (int i = 1; i < chosenLen; i++) {
          sb.write(rnd.nextInt(10));
        }
        return sb.toString();
      }
      return StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: cs.surface,
          title: Text(zh ? '导入QQ头像' : 'Import QQ Avatar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zh ? '输入QQ号获取其头像' : 'Enter QQ number to get avatar',
                style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (v) => setLocal(() => value = v),
                onSubmitted: (_) {
                  if (valid(value)) Navigator.of(ctx).pop(true);
                },
                decoration: InputDecoration(
                  hintText: zh ? '例如：10001' : 'e.g., 10001',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    zh ? '随机生成：' : 'Random: ',
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                  ),
                  InkWell(
                    onTap: () {
                      final qq = randomQQ();
                      controller.text = qq;
                      setLocal(() => value = qq);
                    },
                    child: Text(
                      zh ? '点击生成' : 'Click to generate',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(zh ? '取消' : 'Cancel'),
            ),
            TextButton(
              onPressed: valid(value) ? () => Navigator.of(ctx).pop(true) : null,
              child: Text(
                zh ? '确定' : 'OK',
                style: TextStyle(
                  color: valid(value)
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.38),
                ),
              ),
            ),
          ],
        );
      });
    },
  );
  if (ok == true) {
    final qq = controller.text.trim();
    if (RegExp(r'^[0-9]{5,12}$').hasMatch(qq)) {
      final url = 'https://q2.qlogo.cn/headimg_dl?dst_uin=$qq&spec=100';
      return AvatarPickerResult(type: AvatarType.qq, value: url);
    }
  }
  return null;
}