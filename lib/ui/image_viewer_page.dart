import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key, required this.images, this.initialIndex = 0});

  final List<String> images; // local paths, http urls, or data urls
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.isEmpty ? 0 : widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ImageProvider _providerFor(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return NetworkImage(src);
    }
    if (src.startsWith('data:')) {
      try {
        final base64Marker = 'base64,';
        final idx = src.indexOf(base64Marker);
        if (idx != -1) {
          final b64 = src.substring(idx + base64Marker.length);
          return MemoryImage(base64Decode(b64));
        }
      } catch (_) {}
    }
    return FileImage(File(src));
  }

  Future<void> _shareCurrent() async {
    try {
      final src = widget.images[_index];
      String? pathToSave;
      File? temp;
      if (src.startsWith('data:')) {
        final i = src.indexOf('base64,');
        if (i != -1) {
          final bytes = base64Decode(src.substring(i + 7));
          final tmp = await getTemporaryDirectory();
          temp = await File(p.join(tmp.path, 'kelivo_${DateTime.now().millisecondsSinceEpoch}.png')).create(recursive: true);
          await temp.writeAsBytes(bytes);
          pathToSave = temp.path;
        }
      } else if (src.startsWith('http')) {
        // Try download and share
        final resp = await http.get(Uri.parse(src));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final tmp = await getTemporaryDirectory();
          final ext = p.extension(Uri.parse(src).path);
          temp = await File(p.join(tmp.path, 'kelivo_${DateTime.now().millisecondsSinceEpoch}${ext.isNotEmpty ? ext : '.jpg'}')).create(recursive: true);
          await temp.writeAsBytes(resp.bodyBytes);
          pathToSave = temp.path;
        } else {
          if (!mounted) return;
          // fallback to sharing url as text
          await Share.share(src);
          return;
        }
      } else {
        final f = File(src);
        if (await f.exists()) {
          pathToSave = f.path;
        }
      }
      if (pathToSave == null) {
        if (!mounted) return;
        await Share.share('');
        return;
      }
      try {
        await Share.shareXFiles([XFile(pathToSave)]);
      } on MissingPluginException catch (_) {
        // Fallback: open system chooser by opening file
        final res = await OpenFilex.open(pathToSave);
        if (!mounted) return;
        if (res.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法分享，已尝试打开文件: ${res.message ?? res.type.name}')),
          );
        }
      } on PlatformException catch (_) {
        final res = await OpenFilex.open(pathToSave);
        if (!mounted) return;
        if (res.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法分享，已尝试打开文件: ${res.message ?? res.type.name}')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final src = widget.images[i];
              return Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Hero(
                  tag: 'img:$src',
                  child: InteractiveViewer(
                    minScale: 0.6,
                    maxScale: 5,
                    child: Image(
                      image: _providerFor(src),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70, size: 64),
                    ),
                  ),
                ),
              );
            },
          ),
          // Top bar
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '${_index + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          // Bottom save button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, 0.6),
                    end: Alignment(0, 1),
                    colors: [Colors.transparent, Colors.black54, Colors.black87],
                  ),
                ),
                child: Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    onPressed: _shareCurrent,
                    icon: const Icon(Icons.share),
                    label: const Text('分享图片'),
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

Route _buildFancyRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, anim, sec, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: 0.98, end: 1).animate(curved), child: child),
      );
    },
  );
}
