import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../providers/settings_provider.dart';
import '../providers/model_provider.dart';
import '../models/token_usage.dart';
import '../utils/sandbox_path_resolver.dart';

class ChatApiService {
  static String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/png';
  }

  static Future<String> _encodeBase64File(String path, {bool withPrefix = false}) async {
    final fixed = SandboxPathResolver.fix(path);
    final file = File(fixed);
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    if (withPrefix) {
      final mime = _mimeFromPath(fixed);
      return 'data:$mime;base64,$b64';
    }
    return b64;
  }
  static http.Client _clientFor(ProviderConfig cfg) {
    final enabled = cfg.proxyEnabled == true;
    final host = (cfg.proxyHost ?? '').trim();
    final portStr = (cfg.proxyPort ?? '').trim();
    final user = (cfg.proxyUsername ?? '').trim();
    final pass = (cfg.proxyPassword ?? '').trim();
    if (enabled && host.isNotEmpty && portStr.isNotEmpty) {
      final port = int.tryParse(portStr) ?? 8080;
      final io = HttpClient();
      io.findProxy = (uri) => 'PROXY $host:$port';
      if (user.isNotEmpty) {
        io.addProxyCredentials(host, port, '', HttpClientBasicCredentials(user, pass));
      }
      return IOClient(io);
    }
    return http.Client();
  }

  static Stream<ChatStreamChunk> sendMessageStream({
    required ProviderConfig config,
    required String modelId,
    required List<Map<String, dynamic>> messages,
    List<String>? userImagePaths,
    int? thinkingBudget,
  }) async* {
    final kind = ProviderConfig.classify(config.id);
    final client = _clientFor(config);

    try {
      if (kind == ProviderKind.openai) {
        yield* _sendOpenAIStream(client, config, modelId, messages, userImagePaths: userImagePaths, thinkingBudget: thinkingBudget);
      } else if (kind == ProviderKind.claude) {
        yield* _sendClaudeStream(client, config, modelId, messages, userImagePaths: userImagePaths, thinkingBudget: thinkingBudget);
      } else if (kind == ProviderKind.google) {
        yield* _sendGoogleStream(client, config, modelId, messages, userImagePaths: userImagePaths, thinkingBudget: thinkingBudget);
      }
    } finally {
      client.close();
    }
  }

  // Non-streaming text generation for utilities like title summarization
  static Future<String> generateText({
    required ProviderConfig config,
    required String modelId,
    required String prompt,
  }) async {
    final kind = ProviderConfig.classify(config.id);
    final client = _clientFor(config);
    try {
      if (kind == ProviderKind.openai) {
        final base = config.baseUrl.endsWith('/')
            ? config.baseUrl.substring(0, config.baseUrl.length - 1)
            : config.baseUrl;
        final path = (config.useResponseApi == true) ? '/responses' : (config.chatPath ?? '/chat/completions');
        final url = Uri.parse('$base$path');
        final body = (config.useResponseApi == true)
            ? {
                'model': modelId,
                'input': [
                  {'role': 'user', 'content': prompt}
                ],
              }
            : {
                'model': modelId,
                'messages': [
                  {'role': 'user', 'content': prompt}
                ],
                'temperature': 0.3,
              };
        final resp = await client.post(
          url,
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw HttpException('HTTP ${resp.statusCode}: ${resp.body}');
        }
        final data = jsonDecode(resp.body);
        if (config.useResponseApi == true) {
          final output = data['output'];
          return (output?['content'] ?? '').toString();
        } else {
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final msg = choices.first['message'];
            return (msg?['content'] ?? '').toString();
          }
          return '';
        }
      } else if (kind == ProviderKind.claude) {
        final base = config.baseUrl.endsWith('/')
            ? config.baseUrl.substring(0, config.baseUrl.length - 1)
            : config.baseUrl;
        final url = Uri.parse('$base/messages');
        final body = {
          'model': modelId,
          'max_tokens': 512,
          'temperature': 0.3,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        };
        final resp = await client.post(
          url,
          headers: {
            'x-api-key': config.apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw HttpException('HTTP ${resp.statusCode}: ${resp.body}');
        }
        final data = jsonDecode(resp.body);
        final content = data['content'] as List?;
        if (content != null && content.isNotEmpty) {
          final text = content.first['text'];
          return (text ?? '').toString();
        }
        return '';
      } else {
        // Google
        String url;
        if (config.vertexAI == true && (config.location?.isNotEmpty == true) && (config.projectId?.isNotEmpty == true)) {
          final loc = config.location!;
          final proj = config.projectId!;
          url = 'https://$loc-aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models/$modelId:generateContent';
        } else {
          final base = config.baseUrl.endsWith('/')
              ? config.baseUrl.substring(0, config.baseUrl.length - 1)
              : config.baseUrl;
          url = '$base/models/$modelId:generateContent?key=${Uri.encodeComponent(config.apiKey)}';
        }
        final body = {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {'temperature': 0.3},
        };
        final resp = await client.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw HttpException('HTTP ${resp.statusCode}: ${resp.body}');
        }
        final data = jsonDecode(resp.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates.first['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return (parts.first['text'] ?? '').toString();
          }
        }
        return '';
      }
    } finally {
      client.close();
    }
  }

  static bool _isOff(int? budget) => (budget != null && budget != -1 && budget < 1024);
  static String _effortForBudget(int? budget) {
    if (budget == null || budget == -1) return 'auto';
    if (_isOff(budget)) return 'off';
    if (budget <= 2000) return 'low';
    if (budget <= 20000) return 'medium';
    return 'high';
  }

  static Stream<ChatStreamChunk> _sendOpenAIStream(
    http.Client client,
    ProviderConfig config,
    String modelId,
    List<Map<String, dynamic>> messages,
    {List<String>? userImagePaths, int? thinkingBudget}
  ) async* {
    final base = config.baseUrl.endsWith('/') 
        ? config.baseUrl.substring(0, config.baseUrl.length - 1) 
        : config.baseUrl;
    final path = (config.useResponseApi == true) 
        ? '/responses' 
        : (config.chatPath ?? '/chat/completions');
    final url = Uri.parse('$base$path');

    final isReasoning = ModelRegistry
        .infer(ModelInfo(id: modelId, displayName: modelId))
        .abilities
        .contains(ModelAbility.reasoning);

    final effort = _effortForBudget(thinkingBudget);
    final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
    Map<String, dynamic> body;
    if (config.useResponseApi == true) {
      final input = <Map<String, dynamic>>[];
      for (int i = 0; i < messages.length; i++) {
        final m = messages[i];
        final isLast = i == messages.length - 1;
        if (isLast && (userImagePaths?.isNotEmpty == true) && (m['role'] == 'user')) {
          final text = (m['content'] ?? '').toString();
          final parts = <Map<String, dynamic>>[];
          if (text.isNotEmpty) {
            parts.add({'type': 'input_text', 'text': text});
          }
          for (final p in userImagePaths!) {
            final dataUrl = (p.startsWith('http') || p.startsWith('data:'))
                ? p
                : await _encodeBase64File(p, withPrefix: true);
            parts.add({'type': 'input_image', 'image_url': dataUrl});
          }
          input.add({'role': m['role'] ?? 'user', 'content': parts});
        } else {
          input.add({'role': m['role'] ?? 'user', 'content': m['content'] ?? ''});
        }
      }
      body = {
        'model': modelId,
        'input': input,
        'stream': true,
        if (isReasoning && effort != 'off')
          'reasoning': {
            'summary': 'auto',
            if (effort != 'auto') 'effort': effort,
          },
      };
    } else {
      final mm = <Map<String, dynamic>>[];
      for (int i = 0; i < messages.length; i++) {
        final m = messages[i];
        final isLast = i == messages.length - 1;
        if (isLast && (userImagePaths?.isNotEmpty == true) && (m['role'] == 'user')) {
          final text = (m['content'] ?? '').toString();
          final parts = <Map<String, dynamic>>[];
          if (text.isNotEmpty) {
            parts.add({'type': 'text', 'text': text});
          }
          for (final p in userImagePaths!) {
            final dataUrl = (p.startsWith('http') || p.startsWith('data:'))
                ? p
                : await _encodeBase64File(p, withPrefix: true);
            parts.add({'type': 'image_url', 'image_url': {'url': dataUrl}});
          }
          mm.add({'role': m['role'] ?? 'user', 'content': parts});
        } else {
          mm.add({'role': m['role'] ?? 'user', 'content': m['content'] ?? ''});
        }
      }
      body = {
        'model': modelId,
        'messages': mm,
        'stream': true,
        if (isReasoning && effort != 'off' && effort != 'auto') 'reasoning_effort': effort,
      };
    }

    // Vendor-specific reasoning knobs for chat-completions compatible hosts
    if (config.useResponseApi != true) {
      final off = _isOff(thinkingBudget);
      if (host.contains('openrouter.ai')) {
        // OpenRouter uses `reasoning.enabled/max_tokens`
        if (off) {
          (body as Map<String, dynamic>)['reasoning'] = {'enabled': false};
        } else if (isReasoning) {
          final obj = <String, dynamic>{'enabled': true};
          if (thinkingBudget != null && thinkingBudget > 0) obj['max_tokens'] = thinkingBudget;
          (body as Map<String, dynamic>)['reasoning'] = obj;
          // Remove generic effort to avoid conflicts
          (body as Map<String, dynamic>).remove('reasoning_effort');
        }
      } else if (host.contains('dashscope') || host.contains('aliyun')) {
        // Aliyun DashScope: enable_thinking + thinking_budget
        (body as Map<String, dynamic>)['enable_thinking'] = off ? false : (isReasoning ? true : null);
        if (!off && isReasoning && thinkingBudget != null && thinkingBudget > 0) {
          (body as Map<String, dynamic>)['thinking_budget'] = thinkingBudget;
        }
        (body as Map<String, dynamic>).remove('reasoning_effort');
      } else if (host.contains('ark.cn-beijing.volces.com') || host.contains('volc') || host.contains('ark')) {
        // Volc Ark: thinking: { type: enabled|disabled }
        (body as Map<String, dynamic>)['thinking'] = {
          'type': off ? 'disabled' : (isReasoning ? 'enabled' : 'disabled'),
        };
        (body as Map<String, dynamic>).remove('reasoning_effort');
      } else if (host.contains('intern-ai') || host.contains('intern') || host.contains('chat.intern-ai.org.cn')) {
        // InternLM (InternAI): thinking_mode boolean switch
        (body as Map<String, dynamic>)['thinking_mode'] = off ? false : (isReasoning ? true : null);
        (body as Map<String, dynamic>).remove('reasoning_effort');
      } else if (host.contains('siliconflow')) {
        // SiliconFlow: OFF -> enable_thinking: false; otherwise omit (provider decides)
        if (off) {
          (body as Map<String, dynamic>)['enable_thinking'] = false;
        }
        (body as Map<String, dynamic>).remove('reasoning_effort');
      }
    }

    final request = http.Request('POST', url);
    request.headers.addAll({
      'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    // Ask for usage in streaming for chat-completions compatible hosts (when supported)
    if (config.useResponseApi != true) {
      final h = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
      if (!h.contains('mistral.ai')) {
        (body as Map<String, dynamic>)['stream_options'] = {'include_usage': true};
      }
    }
    request.body = jsonEncode(body);

    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw HttpException('HTTP ${response.statusCode}: $errorBody');
    }

    final stream = response.stream.transform(utf8.decoder);
    String buffer = '';
    int totalTokens = 0;
    TokenUsage? usage;
    // Fallback approx token calculation when provider doesn't include usage
    int _approxTokensFromChars(int chars) => (chars / 4).round();
    final int approxPromptChars = messages.fold<int>(0, (acc, m) => acc + ((m['content'] ?? '').toString().length));
    final int approxPromptTokens = _approxTokensFromChars(approxPromptChars);
    int approxCompletionChars = 0;

    await for (final chunk in stream) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.last;

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || !line.startsWith('data: ')) continue;

        final data = line.substring(6);
        if (data == '[DONE]') {
          final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
          yield ChatStreamChunk(
            content: '',
            isDone: true,
            totalTokens: usage?.totalTokens ?? approxTotal,
            usage: usage,
          );
          return;
        }

        try {
          final json = jsonDecode(data);
          String content = '';
          String? reasoning;

          if (config.useResponseApi == true) {
            // OpenAI /responses SSE types
            final type = json['type'];
            if (type == 'response.output_text.delta') {
              final delta = json['delta'];
              if (delta is String) {
                content = delta;
                approxCompletionChars += content.length;
              }
            } else if (type == 'response.reasoning_summary_text.delta') {
              final delta = json['delta'];
              if (delta is String) reasoning = delta;
            } else if (type == 'response.completed') {
              final u = json['response']?['usage'];
              if (u != null) {
                final inTok = (u['input_tokens'] ?? 0) as int;
                final outTok = (u['output_tokens'] ?? 0) as int;
                usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: inTok, completionTokens: outTok));
                totalTokens = usage!.totalTokens;
              }
              final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
              yield ChatStreamChunk(
                content: '',
                reasoning: null,
                isDone: true,
                totalTokens: usage?.totalTokens ?? approxTotal,
                usage: usage,
              );
              return;
            } else {
              // Fallback for providers that inline output
              final output = json['output'];
              if (output != null) {
                content = (output['content'] ?? '').toString();
                approxCompletionChars += content.length;
                final u = json['usage'];
                if (u != null) {
                  final inTok = (u['input_tokens'] ?? 0) as int;
                  final outTok = (u['output_tokens'] ?? 0) as int;
                  usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: inTok, completionTokens: outTok));
                  totalTokens = usage!.totalTokens;
                }
              }
            }
          } else {
            // Handle standard OpenAI Chat Completions format
            final choices = json['choices'];
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'];
              if (delta != null) {
                content = (delta['content'] ?? '') as String;
                if (content.isNotEmpty) {
                  approxCompletionChars += content.length;
                }
                final rc = (delta['reasoning_content'] ?? delta['reasoning']) as String?;
                if (rc != null && rc.isNotEmpty) reasoning = rc;
              }
            }
            final u = json['usage'];
            if (u != null) {
              final prompt = (u['prompt_tokens'] ?? 0) as int;
              final completion = (u['completion_tokens'] ?? 0) as int;
              final cached = (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ?? 0;
              usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: prompt, completionTokens: completion, cachedTokens: cached));
              totalTokens = usage!.totalTokens;
            }
          }

          if (content.isNotEmpty || (reasoning != null && reasoning!.isNotEmpty)) {
            final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
            yield ChatStreamChunk(
              content: content,
              reasoning: reasoning,
              isDone: false,
              totalTokens: totalTokens > 0 ? totalTokens : approxTotal,
              usage: usage,
            );
          }
        } catch (e) {
          // Skip malformed JSON
        }
      }
    }
  }

  static Stream<ChatStreamChunk> _sendClaudeStream(
    http.Client client,
    ProviderConfig config,
    String modelId,
    List<Map<String, dynamic>> messages,
    {List<String>? userImagePaths, int? thinkingBudget}
  ) async* {
    final base = config.baseUrl.endsWith('/') 
        ? config.baseUrl.substring(0, config.baseUrl.length - 1) 
        : config.baseUrl;
    final url = Uri.parse('$base/messages');

    final isReasoning = ModelRegistry
        .infer(ModelInfo(id: modelId, displayName: modelId))
        .abilities
        .contains(ModelAbility.reasoning);

    // Transform last user message to include images per Anthropic schema
    final transformed = <Map<String, dynamic>>[];
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      final isLast = i == messages.length - 1;
      if (isLast && (userImagePaths?.isNotEmpty == true) && (m['role'] == 'user')) {
        final parts = <Map<String, dynamic>>[];
        final text = (m['content'] ?? '').toString();
        if (text.isNotEmpty) parts.add({'type': 'text', 'text': text});
        for (final p in userImagePaths!) {
          if (p.startsWith('http') || p.startsWith('data:')) {
            // Fallback: include link as text
            parts.add({'type': 'text', 'text': p});
          } else {
            final mime = _mimeFromPath(p);
            final b64 = await _encodeBase64File(p, withPrefix: false);
            parts.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mime,
                'data': b64,
              }
            });
          }
        }
        transformed.add({'role': 'user', 'content': parts});
      } else {
        transformed.add({'role': m['role'] ?? 'user', 'content': m['content'] ?? ''});
      }
    }

    final body = {
      'model': modelId,
      'max_tokens': 4096,
      'messages': transformed,
      'stream': true,
      if (isReasoning)
        'thinking': {
          'type': (thinkingBudget == 0) ? 'disabled' : 'enabled',
          if (thinkingBudget != null && thinkingBudget > 0)
            'budget_tokens': thinkingBudget,
        },
    };

    final request = http.Request('POST', url);
    request.headers.addAll({
      'x-api-key': config.apiKey,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    request.body = jsonEncode(body);

    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw HttpException('HTTP ${response.statusCode}: $errorBody');
    }

    final stream = response.stream.transform(utf8.decoder);
    String buffer = '';
    int totalTokens = 0;
    TokenUsage? usage;

    await for (final chunk in stream) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.last;

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || !line.startsWith('data: ')) continue;

        final data = line.substring(6);
        try {
          final json = jsonDecode(data);
          final type = json['type'];
          
          if (type == 'content_block_delta') {
            final delta = json['delta'];
            if (delta != null) {
              if (delta['type'] == 'text_delta') {
                final content = delta['text'] ?? '';
                if (content is String && content.isNotEmpty) {
                  yield ChatStreamChunk(
                    content: content,
                    isDone: false,
                    totalTokens: totalTokens,
                  );
                }
              } else if (delta['type'] == 'thinking_delta') {
                final thinking = (delta['thinking'] ?? delta['text'] ?? '') as String;
                if (thinking.isNotEmpty) {
                  yield ChatStreamChunk(
                    content: '',
                    reasoning: thinking,
                    isDone: false,
                    totalTokens: totalTokens,
                  );
                }
              }
            }
          } else if (type == 'message_stop') {
            yield ChatStreamChunk(
              content: '',
              isDone: true,
              totalTokens: totalTokens,
              usage: usage,
            );
            return;
          } else if (type == 'message_delta') {
            final u = json['usage'] ?? json['message']?['usage'];
            if (u != null) {
              final inTok = (u['input_tokens'] ?? 0) as int;
              final outTok = (u['output_tokens'] ?? 0) as int;
              usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: inTok, completionTokens: outTok));
              totalTokens = usage!.totalTokens;
            }
          }
        } catch (e) {
          // Skip malformed JSON
        }
      }
    }
  }

  static Stream<ChatStreamChunk> _sendGoogleStream(
    http.Client client,
    ProviderConfig config,
    String modelId,
    List<Map<String, dynamic>> messages,
    {List<String>? userImagePaths, int? thinkingBudget}
  ) async* {
    // Implement SSE streaming via :streamGenerateContent with alt=sse
    // Build endpoint per Vertex vs Gemini
    String baseUrl;
    if (config.vertexAI == true && (config.location?.isNotEmpty == true) && (config.projectId?.isNotEmpty == true)) {
      final loc = config.location!.trim();
      final proj = config.projectId!.trim();
      baseUrl = 'https://$loc-aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models/$modelId:streamGenerateContent';
    } else {
      final base = config.baseUrl.endsWith('/')
          ? config.baseUrl.substring(0, config.baseUrl.length - 1)
          : config.baseUrl;
      baseUrl = '$base/models/$modelId:streamGenerateContent';
    }

    // Build query with key (for non-Vertex) and alt=sse
    final uriBase = Uri.parse(baseUrl);
    final qp = Map<String, String>.from(uriBase.queryParameters);
    if (!(config.vertexAI == true)) {
      if (config.apiKey.isNotEmpty) qp['key'] = config.apiKey;
    }
    qp['alt'] = 'sse';
    final uri = uriBase.replace(queryParameters: qp);

    // Convert messages to Google contents format
    final contents = <Map<String, dynamic>>[];
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      final isLast = i == messages.length - 1;
      final parts = <Map<String, dynamic>>[];
      final text = (msg['content'] ?? '').toString();
      if (text.isNotEmpty) parts.add({'text': text});
      if (isLast && role == 'user' && (userImagePaths?.isNotEmpty == true)) {
        for (final p in userImagePaths!) {
          if (p.startsWith('http') || p.startsWith('data:')) {
            // Google inline_data expects base64; skip remote/data
            continue;
          }
          final mime = _mimeFromPath(p);
          final b64 = await _encodeBase64File(p, withPrefix: false);
          parts.add({
            'inline_data': {
              'mime_type': mime,
              'data': b64,
            }
          });
        }
      }
      contents.add({'role': role, 'parts': parts});
    }

    final isReasoning = ModelRegistry
        .infer(ModelInfo(id: modelId, displayName: modelId))
        .abilities
        .contains(ModelAbility.reasoning);
    final off = _isOff(thinkingBudget);
    final body = <String, dynamic>{
      'contents': contents,
      if (isReasoning)
        'generationConfig': {
          'thinkingConfig': {
            'includeThoughts': off ? false : true,
            if (!off && thinkingBudget != null && thinkingBudget >= 0)
              'thinkingBudget': thinkingBudget,
          }
        },
    };

    final request = http.Request('POST', uri);
    request.headers.addAll(<String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      if (config.vertexAI == true && config.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${config.apiKey}',
    });
    request.body = jsonEncode(body);

    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw HttpException('HTTP ${response.statusCode}: $errorBody');
    }

    final stream = response.stream.transform(utf8.decoder);
    String buffer = '';
    TokenUsage? usage;
    int totalTokens = 0;

    await for (final chunk in stream) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.last; // keep incomplete line

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim(); // after 'data:'
        if (data.isEmpty) continue;
        // No [DONE] sentinel for Google SSE; rely on stream close
        try {
          final obj = jsonDecode(data) as Map<String, dynamic>;
          // usageMetadata may appear on any chunk
          final um = obj['usageMetadata'];
          if (um is Map<String, dynamic>) {
            usage = (usage ?? const TokenUsage()).merge(TokenUsage(
              promptTokens: (um['promptTokenCount'] ?? 0) as int,
              completionTokens: (um['candidatesTokenCount'] ?? 0) as int,
              totalTokens: (um['totalTokenCount'] ?? 0) as int,
            ));
            totalTokens = usage!.totalTokens;
          }

          final candidates = obj['candidates'];
          if (candidates is List && candidates.isNotEmpty) {
            // Aggregate deltas in this event
            String textDelta = '';
            String reasoningDelta = '';
            for (final cand in candidates) {
              if (cand is! Map) continue;
              final content = cand['content'];
              if (content is! Map) continue;
              final parts = content['parts'];
              if (parts is! List) continue;
              for (final p in parts) {
                if (p is! Map) continue;
                final t = (p['text'] ?? '') as String? ?? '';
                final thought = p['thought'] as bool? ?? false;
                if (t.isEmpty) continue;
                if (thought) {
                  reasoningDelta += t;
                } else {
                  textDelta += t;
                }
              }
            }

            // Yield deltas if any
            if (reasoningDelta.isNotEmpty) {
              yield ChatStreamChunk(
                content: '',
                reasoning: reasoningDelta,
                isDone: false,
                totalTokens: totalTokens,
                usage: usage,
              );
            }
            if (textDelta.isNotEmpty) {
              yield ChatStreamChunk(
                content: textDelta,
                isDone: false,
                totalTokens: totalTokens,
                usage: usage,
              );
            }
          }
        } catch (_) {
          // ignore malformed chunk
        }
      }
    }

    // Stream ended: send final done signal with latest usage if any
    yield ChatStreamChunk(
      content: '',
      isDone: true,
      totalTokens: totalTokens,
      usage: usage,
    );
  }
}

class ChatStreamChunk {
  final String content;
  // Optional reasoning delta (when model supports reasoning)
  final String? reasoning;
  final bool isDone;
  final int totalTokens;
  final TokenUsage? usage;

  ChatStreamChunk({
    required this.content,
    this.reasoning,
    required this.isDone,
    required this.totalTokens,
    this.usage,
  });
}
