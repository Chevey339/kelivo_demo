import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

class ChatService extends ChangeNotifier {
  static const String _conversationsBoxName = 'conversations';
  static const String _messagesBoxName = 'messages';

  late Box<Conversation> _conversationsBox;
  late Box<ChatMessage> _messagesBox;
  
  String? _currentConversationId;
  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, Conversation> _draftConversations = {};

  bool _initialized = false;
  bool get initialized => _initialized;

  String? get currentConversationId => _currentConversationId;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    
    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationAdapter());
    }

    _conversationsBox = await Hive.openBox<Conversation>(_conversationsBoxName);
    _messagesBox = await Hive.openBox<ChatMessage>(_messagesBoxName);

    _initialized = true;
    notifyListeners();
  }

  List<Conversation> getAllConversations() {
    if (!_initialized) return [];
    final conversations = _conversationsBox.values.toList();
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  List<Conversation> getPinnedConversations() {
    return getAllConversations().where((c) => c.isPinned).toList();
  }

  Conversation? getConversation(String id) {
    if (!_initialized) return null;
    return _conversationsBox.get(id) ?? _draftConversations[id];
  }

  List<ChatMessage> getMessages(String conversationId) {
    if (!_initialized) return [];
    
    // Check cache first
    if (_messagesCache.containsKey(conversationId)) {
      return _messagesCache[conversationId]!;
    }

    // Load from storage
    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null) return [];

    final messages = <ChatMessage>[];
    for (final messageId in conversation.messageIds) {
      final message = _messagesBox.get(messageId);
      if (message != null) {
        messages.add(message);
      }
    }

    // Cache the result
    _messagesCache[conversationId] = messages;
    return messages;
  }

  Future<Conversation> createConversation({String? title}) async {
    if (!_initialized) await init();

    final conversation = Conversation(
      title: title ?? '新对话',
    );

    await _conversationsBox.put(conversation.id, conversation);
    _currentConversationId = conversation.id;
    notifyListeners();
    return conversation;
  }

  // Create a draft conversation that is not persisted until first message arrives.
  Future<Conversation> createDraftConversation({String? title}) async {
    if (!_initialized) await init();
    final conversation = Conversation(title: title ?? '新对话');
    _draftConversations[conversation.id] = conversation;
    _currentConversationId = conversation.id;
    notifyListeners();
    return conversation;
  }

  Future<void> deleteConversation(String id) async {
    if (!_initialized) return;

    // If it's a draft and never persisted, just drop it.
    if (_draftConversations.containsKey(id)) {
      _draftConversations.remove(id);
      if (_currentConversationId == id) {
        _currentConversationId = null;
      }
      notifyListeners();
      return;
    }

    final conversation = _conversationsBox.get(id);
    if (conversation == null) return;

    // Collect local file paths referenced by messages in this conversation
    final Set<String> pathsToMaybeDelete = <String>{};
    for (final messageId in conversation.messageIds) {
      final message = _messagesBox.get(messageId);
      if (message == null) continue;
      final content = message.content;
      // [image:/abs/path]
      final imgRe = RegExp(r"\[image:(.+?)\]");
      for (final m in imgRe.allMatches(content)) {
        final pth = m.group(1)?.trim();
        if (pth != null && pth.isNotEmpty && !pth.startsWith('http') && !pth.startsWith('data:')) {
          pathsToMaybeDelete.add(pth);
        }
      }
      // [file:/abs/path|filename|mime]
      final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
      for (final m in fileRe.allMatches(content)) {
        final pth = m.group(1)?.trim();
        if (pth != null && pth.isNotEmpty && !pth.startsWith('http') && !pth.startsWith('data:')) {
          pathsToMaybeDelete.add(pth);
        }
      }
    }

    // Delete all messages
    for (final messageId in conversation.messageIds) {
      await _messagesBox.delete(messageId);
    }

    // Delete conversation
    await _conversationsBox.delete(id);

    // Remove cached messages
    // Clear cache
    _messagesCache.remove(id);

    // Delete orphaned files (not referenced by any remaining conversation)
    await _cleanupOrphanUploads();

    if (_currentConversationId == id) {
      _currentConversationId = null;
    }

    notifyListeners();
  }

  Set<String> _extractAttachmentPaths(String content) {
    final out = <String>{};
    final imgRe = RegExp(r"\[image:(.+?)\]");
    for (final m in imgRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null && pth.isNotEmpty && !pth.startsWith('http') && !pth.startsWith('data:')) out.add(pth);
    }
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    for (final m in fileRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null && pth.isNotEmpty && !pth.startsWith('http') && !pth.startsWith('data:')) out.add(pth);
    }
    return out;
  }

  Future<void> _cleanupOrphanUploads() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final uploadDir = Directory(p.join(docs.path, 'upload'));
      if (!await uploadDir.exists()) return;

      // Build the set of all referenced paths across all messages
      final referenced = <String>{};
      for (final m in _messagesBox.values) {
        referenced.addAll(_extractAttachmentPaths(m.content));
      }

      final entries = uploadDir.listSync();
      for (final ent in entries) {
        if (ent is File) {
          final filePath = ent.path;
          if (!referenced.contains(filePath)) {
            try { await ent.delete(); } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> restoreConversation(Conversation conversation, List<ChatMessage> messages) async {
    if (!_initialized) await init();
    // Restore messages first
    for (final m in messages) {
      await _messagesBox.put(m.id, m);
    }
    // Ensure messageIds are in the same order
    final ids = messages.map((m) => m.id).toList();
    final restored = Conversation(
      id: conversation.id,
      title: conversation.title,
      createdAt: conversation.createdAt,
      updatedAt: DateTime.now(),
      messageIds: ids,
      isPinned: conversation.isPinned,
    );
    await _conversationsBox.put(restored.id, restored);

    // Update caches
    _messagesCache[restored.id] = List.of(messages);

    notifyListeners();
  }

  Future<void> renameConversation(String id, String newTitle) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(id)) {
      final draft = _draftConversations[id]!;
      draft.title = newTitle;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    final conversation = _conversationsBox.get(id);
    if (conversation == null) return;

    conversation.title = newTitle;
    conversation.updatedAt = DateTime.now();
    await conversation.save();
    notifyListeners();
  }

  Future<void> togglePinConversation(String id) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(id)) {
      final draft = _draftConversations[id]!;
      draft.isPinned = !draft.isPinned;
      notifyListeners();
      return;
    }
    final conversation = _conversationsBox.get(id);
    if (conversation == null) return;

    conversation.isPinned = !conversation.isPinned;
    await conversation.save();
    notifyListeners();
  }

  Future<ChatMessage> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? modelId,
    String? providerId,
    int? totalTokens,
    bool isStreaming = false,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
  }) async {
    if (!_initialized) await init();

    var conversation = _conversationsBox.get(conversationId);
    // If conversation doesn't exist yet, persist draft (if any)
    if (conversation == null) {
      final draft = _draftConversations.remove(conversationId);
      if (draft != null) {
        await _conversationsBox.put(draft.id, draft);
        conversation = draft;
      } else {
        // Create a new one on the fly as a fallback
        conversation = Conversation(id: conversationId, title: '新对话');
        await _conversationsBox.put(conversationId, conversation);
      }
    }

    final message = ChatMessage(
      role: role,
      content: content,
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerId,
      totalTokens: totalTokens,
      isStreaming: isStreaming,
      reasoningText: reasoningText,
      reasoningStartAt: reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt,
    );

    await _messagesBox.put(message.id, message);
    
    conversation.messageIds.add(message.id);
    conversation.updatedAt = DateTime.now();
    await conversation.save();

    // Update cache
    if (_messagesCache.containsKey(conversationId)) {
      _messagesCache[conversationId]!.add(message);
    }

    notifyListeners();
    return message;
  }

  Future<void> updateMessage(String messageId, {
    String? content,
    int? totalTokens,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
  }) async {
    if (!_initialized) return;

    final message = _messagesBox.get(messageId);
    if (message == null) return;

    final updatedMessage = message.copyWith(
      content: content ?? message.content,
      totalTokens: totalTokens ?? message.totalTokens,
      isStreaming: isStreaming ?? message.isStreaming,
      reasoningText: reasoningText ?? message.reasoningText,
      reasoningStartAt: reasoningStartAt ?? message.reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt ?? message.reasoningFinishedAt,
    );

    await _messagesBox.put(messageId, updatedMessage);

    // Update cache
    final conversationId = message.conversationId;
    if (_messagesCache.containsKey(conversationId)) {
      final messages = _messagesCache[conversationId]!;
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = updatedMessage;
      }
    }

    notifyListeners();
  }

  Future<void> deleteMessage(String messageId) async {
    if (!_initialized) return;

    final message = _messagesBox.get(messageId);
    if (message == null) return;

    final conversation = _conversationsBox.get(message.conversationId);
    if (conversation != null) {
      conversation.messageIds.remove(messageId);
      await conversation.save();
    }

    await _messagesBox.delete(messageId);

    // Update cache
    if (_messagesCache.containsKey(message.conversationId)) {
      _messagesCache[message.conversationId]!.removeWhere((m) => m.id == messageId);
    }

    // Clean up orphaned upload files that are no longer referenced by any message
    await _cleanupOrphanUploads();

    notifyListeners();
  }

  void setCurrentConversation(String? id) {
    _currentConversationId = id;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    if (!_initialized) return;

    await _messagesBox.clear();
    await _conversationsBox.clear();
    _messagesCache.clear();
    _draftConversations.clear();
    _currentConversationId = null;
    // Remove uploads directory completely
    try {
      final docs = await getApplicationDocumentsDirectory();
      final uploadDir = Directory(p.join(docs.path, 'upload'));
      if (await uploadDir.exists()) {
        await uploadDir.delete(recursive: true);
      }
    } catch (_) {}
    notifyListeners();
  }

  // Uploads stats: count and total size of files under app documents/upload
  Future<UploadStats> getUploadStats() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final uploadDir = Directory(p.join(docs.path, 'upload'));
      if (!await uploadDir.exists()) {
        return const UploadStats(fileCount: 0, totalBytes: 0);
      }
      int count = 0;
      int bytes = 0;
      final entries = uploadDir.listSync(recursive: true, followLinks: false);
      for (final ent in entries) {
        if (ent is File) {
          count += 1;
          try { bytes += await ent.length(); } catch (_) {}
        }
      }
      return UploadStats(fileCount: count, totalBytes: bytes);
    } catch (_) {
      return const UploadStats(fileCount: 0, totalBytes: 0);
    }
  }
}

class UploadStats {
  final int fileCount;
  final int totalBytes;
  const UploadStats({required this.fileCount, required this.totalBytes});
}
