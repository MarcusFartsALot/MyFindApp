import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/community_report_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Shared playback for saved and newly selected evidence.
class LocalEvidencePreview extends StatefulWidget {
  final PlatformFile? file;
  final String? storagePath;
  const LocalEvidencePreview({super.key, required PlatformFile this.file})
    : storagePath = null;
  const LocalEvidencePreview.saved({
    super.key,
    required String this.storagePath,
  }) : file = null;
  @override
  State<LocalEvidencePreview> createState() => _LocalEvidencePreviewState();
}

class _LocalEvidencePreviewState extends State<LocalEvidencePreview> {
  VideoPlayerController? _video;
  Future<void>? _ready;
  late final bool _isVideo;
  String? _url;
  bool _disposed = false;
  String get _name =>
      widget.file?.name ?? widget.storagePath!.split('/').last.split('?').first;
  @override
  void initState() {
    super.initState();
    _isVideo = [
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
    ].contains(_name.split('.').last.toLowerCase());
    _ready = _load();
  }

  Future<void> _load() async {
    final file = widget.file;
    if (widget.storagePath != null) {
      var path = widget.storagePath!;
      if (path.startsWith('https://') || path.startsWith('http://')) {
        _url = path;
      } else {
        const bucket = CommunityReportService.bucketName;
        if (path.startsWith('$bucket/')) {
          path = path.substring(bucket.length + 1);
        }
        _url = await Supabase.instance.client.storage
            .from(bucket)
            .createSignedUrl(path, 3600);
      }
    }
    if (_disposed) return;
    if (_isVideo) {
      if (_url != null) {
        _video = VideoPlayerController.networkUrl(Uri.parse(_url!));
      } else if (kIsWeb && file?.bytes != null) {
        final mime = _name.toLowerCase().endsWith('.webm')
            ? 'video/webm'
            : 'video/mp4';
        _video = VideoPlayerController.networkUrl(
          Uri.parse('data:$mime;base64,${base64Encode(file!.bytes!)}'),
        );
      } else if (!kIsWeb && file?.path != null) {
        _video = VideoPlayerController.file(File(file!.path!));
      }
      if (_video == null) throw StateError('File unavailable');
      try {
        await _video!.initialize();
      } catch (_) {
        // Some older Android GPU/decoder combinations reject texture surfaces.
        // Recreate with a native view before treating the media as unsupported.
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) rethrow;
        await _video!.dispose();
        if (_disposed) return;
        _video = _url != null
            ? VideoPlayerController.networkUrl(
                Uri.parse(_url!),
                viewType: VideoViewType.platformView,
              )
            : VideoPlayerController.file(
                File(file!.path!),
                viewType: VideoViewType.platformView,
              );
        await _video!.initialize();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _video?.dispose();
    super.dispose();
  }

  Widget get _error => Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white70,
            size: 40,
          ),
          const SizedBox(height: 16),
          const Text(
            'Preview could not load. Check your connection and try again. Some video encodings may not play on this device. Your attachment has not been removed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await _video?.dispose();
              _video = null;
              if (!mounted) return;
              setState(() => _ready = _load());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0F172A),
    appBar: AppBar(
      title: Text(
        _name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFF0F172A),
    ),
    body: SafeArea(
      child: Center(
        child: _isVideo
            ? FutureBuilder<void>(
                future: _ready,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _error;
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const CircularProgressIndicator();
                  }
                  return AnimatedBuilder(
                    animation: _video!,
                    builder: (context, _) => SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AspectRatio(
                            aspectRatio: _video!.value.aspectRatio > 0
                                ? _video!.value.aspectRatio
                                : 16 / 9,
                            child: VideoPlayer(_video!),
                          ),
                          VideoProgressIndicator(
                            _video!,
                            allowScrubbing: true,
                            padding: const EdgeInsets.all(16),
                          ),
                          IconButton.filled(
                            tooltip: _video!.value.isPlaying ? 'Pause' : 'Play',
                            onPressed: () => _video!.value.isPlaying
                                ? _video!.pause()
                                : _video!.play(),
                            icon: Icon(
                              _video!.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: widget.storagePath != null
                    ? FutureBuilder<void>(
                        future: _ready,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) return _error;
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const CircularProgressIndicator();
                          }
                          return Image.network(
                            _url!,
                            errorBuilder: (_, error, stack) => _error,
                          );
                        },
                      )
                    : widget.file?.bytes != null
                    ? Image.memory(
                        widget.file!.bytes!,
                        errorBuilder: (_, error, stack) => _error,
                      )
                    : !kIsWeb && widget.file?.path != null
                    ? Image.file(
                        File(widget.file!.path!),
                        errorBuilder: (_, error, stack) => _error,
                      )
                    : _error,
              ),
      ),
    ),
  );
}
