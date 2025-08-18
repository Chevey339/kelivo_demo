class ChatInputData {
  final String text;
  final List<String> imagePaths; // absolute file paths or data URLs

  const ChatInputData({required this.text, this.imagePaths = const []});
}

