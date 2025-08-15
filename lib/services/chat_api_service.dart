import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../providers/settings_provider.dart';
import '../providers/model_provider.dart';

class ChatApiService {
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
  }) async* {
    final kind = ProviderConfig.classify(config.id);
    final client = _clientFor(config);

    try {
      if (kind == ProviderKind.openai) {
        yield* _sendOpenAIStream(client, config, modelId, messages);
      } else if (kind == ProviderKind.claude) {
        yield* _sendClaudeStream(client, config, modelId, messages);
      } else if (kind == ProviderKind.google) {
        yield* _sendGoogleStream(client, config, modelId, messages);
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

  static Stream<ChatStreamChunk> _sendOpenAIStream(
    http.Client client,
    ProviderConfig config,
    String modelId,
    List<Map<String, dynamic>> messages,
  ) async* {
    final base = config.baseUrl.endsWith('/') 
        ? config.baseUrl.substring(0, config.baseUrl.length - 1) 
        : config.baseUrl;
    final path = (config.useResponseApi == true) 
        ? '/responses' 
        : (config.chatPath ?? '/chat/completions');
    final url = Uri.parse('$base$path');

    final body = config.useResponseApi == true
        ? {
            'model': modelId,
            'input': messages,
            'stream': true,
          }
        : {
            'model': modelId,
            'messages': messages,
            'stream': true,
          };

    final request = http.Request('POST', url);
    request.headers.addAll({
      'Authorization': 'Bearer ${config.apiKey}',
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

    await for (final chunk in stream) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.last;

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || !line.startsWith('data: ')) continue;

        final data = line.substring(6);
        if (data == '[DONE]') {
          yield ChatStreamChunk(
            content: '',
            isDone: true,
            totalTokens: totalTokens,
          );
          return;
        }

        try {
          final json = jsonDecode(data);
          String content = '';
          
          if (config.useResponseApi == true) {
            // Handle OpenAI /responses format
            final output = json['output'];
            if (output != null) {
              content = output['content'] ?? '';
              final usage = json['usage'];
              if (usage != null) {
                totalTokens = usage['total_tokens'] ?? totalTokens;
              }
            }
          } else {
            // Handle standard OpenAI format
            final choices = json['choices'];
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'];
              if (delta != null) {
                content = delta['content'] ?? '';
              }
            }
            final usage = json['usage'];
            if (usage != null) {
              totalTokens = usage['total_tokens'] ?? totalTokens;
            }
          }

          if (content.isNotEmpty) {
            yield ChatStreamChunk(
              content: content,
              isDone: false,
              totalTokens: totalTokens,
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
  ) async* {
    final base = config.baseUrl.endsWith('/') 
        ? config.baseUrl.substring(0, config.baseUrl.length - 1) 
        : config.baseUrl;
    final url = Uri.parse('$base/messages');

    final body = {
      'model': modelId,
      'max_tokens': 4096,
      'messages': messages,
      'stream': true,
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
            if (delta != null && delta['type'] == 'text_delta') {
              final content = delta['text'] ?? '';
              if (content.isNotEmpty) {
                yield ChatStreamChunk(
                  content: content,
                  isDone: false,
                  totalTokens: totalTokens,
                );
              }
            }
          } else if (type == 'message_stop') {
            yield ChatStreamChunk(
              content: '',
              isDone: true,
              totalTokens: totalTokens,
            );
            return;
          } else if (type == 'message_delta') {
            final usage = json['usage'];
            if (usage != null) {
              final outputTokens = usage['output_tokens'] ?? 0;
              final inputTokens = usage['input_tokens'] ?? 0;
              totalTokens = outputTokens + inputTokens;
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
  ) async* {
    // Google API doesn't support streaming in the same way
    // We'll use non-streaming and yield the entire response
    String url;
    if (config.vertexAI == true && 
        (config.location?.isNotEmpty == true) && 
        (config.projectId?.isNotEmpty == true)) {
      final loc = config.location!;
      final proj = config.projectId!;
      url = 'https://$loc-aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models/$modelId:generateContent';
    } else {
      final base = config.baseUrl.endsWith('/') 
          ? config.baseUrl.substring(0, config.baseUrl.length - 1) 
          : config.baseUrl;
      url = '$base/models/$modelId:generateContent';
      if (config.apiKey.isNotEmpty) {
        url = '$url?key=${Uri.encodeQueryComponent(config.apiKey)}';
      }
    }

    // Convert messages to Google format
    final contents = <Map<String, dynamic>>[];
    for (final msg in messages) {
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': msg['content']}
        ]
      });
    }

    final body = {'contents': contents};
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (config.vertexAI == true && config.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    final response = await client.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body);
    final candidates = json['candidates'];
    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates[0]['content'];
      if (content != null) {
        final parts = content['parts'];
        if (parts != null && parts.isNotEmpty) {
          final text = parts[0]['text'] ?? '';
          
          // Calculate approximate tokens
          final totalTokens = (text.length / 4).round();
          
          yield ChatStreamChunk(
            content: text,
            isDone: false,
            totalTokens: totalTokens,
          );
        }
      }
    }

    yield ChatStreamChunk(
      content: '',
      isDone: true,
      totalTokens: 0,
    );
  }
}

class ChatStreamChunk {
  final String content;
  final bool isDone;
  final int totalTokens;

  ChatStreamChunk({
    required this.content,
    required this.isDone,
    required this.totalTokens,
  });
}
