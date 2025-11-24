import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fast_cache_network_image/fast_cached_network_image.dart'
    show FastCachedVideo;
import 'package:fast_cache_network_image/src/fast_cached_video.dart'
    show FastCachedVideo;
import 'package:flutter/material.dart';
import './fast_cached_image.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// State for [FastCachedVideoController]
class FastCachedVideoValue {
  /// Whether the video is currently being downloaded/loaded.
  final bool isLoading;

  /// Error message if something went wrong.
  final String? error;

  /// Download progress (0.0 to 1.0).
  final double progress;

  /// Whether the video player is initialized and ready to play.
  final bool isInitialized;

  const FastCachedVideoValue({
    this.isLoading = false,
    this.error,
    this.progress = 0.0,
    this.isInitialized = false,
  });

  FastCachedVideoValue copyWith({
    bool? isLoading,
    String? error,
    double? progress,
    bool? isInitialized,
  }) {
    return FastCachedVideoValue(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      progress: progress ?? this.progress,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Controller for [FastCachedVideo].
/// Manages downloading, caching, and the underlying [VideoPlayerController].
class FastCachedVideoController extends ValueNotifier<FastCachedVideoValue> {
  final String url;
  final Map<String, dynamic>? headers;
  final bool autoPlay;
  final bool loop;
  bool _isDisposed = false;

  VideoPlayerController? _videoPlayerController;

  /// The underlying [VideoPlayerController].
  /// This will be null until the video file is cached and initialized.
  VideoPlayerController? get videoPlayerController => _videoPlayerController;

  FastCachedVideoController(
    this.url, {
    this.headers,
    this.autoPlay = true,
    this.loop = true,
  }) : super(const FastCachedVideoValue());

  /// Initialize the controller.
  /// This will check the cache, download if necessary, and initialize the [VideoPlayerController].
  Future<void> initialize() async {
    if (value.isInitialized || value.isLoading) return;

    value = value.copyWith(isLoading: true, error: null, progress: 0);

    try {
      FastCachedImageConfig.checkInit();

      if (url.isEmpty || Uri.tryParse(url) == null) {
        value = value.copyWith(
          isLoading: false,
          error: 'Invalid url: $url',
        );
        return;
      }

      final file = FastCachedImageConfig.getCachedFile(url);

      if (file.existsSync()) {
        await _initializePlayer(file);
      } else {
        await _downloadAndCache(url, file);
      }
    } catch (e) {
      value = value.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _downloadAndCache(String url, File file) async {
    StreamController chunkEvents = StreamController();

    try {
      final Uri resolved = Uri.base.resolve(url);

      Response response = await FastCachedImageConfig.dio.get(
        url,
        options: Options(responseType: ResponseType.bytes, headers: headers),
        onReceiveProgress: (int received, int total) {
          if (received < 0 || total < 0) return;
          if (_isDisposed) return;
          value = value.copyWith(
            progress: double.parse((received / total).toStringAsFixed(2)),
          );
        },
      );

      final Uint8List bytes = response.data;

      if (response.statusCode != 200) {
        throw NetworkImageLoadException(
          statusCode: response.statusCode ?? 0,
          uri: resolved,
        );
      }

      if (bytes.isEmpty) {
        throw Exception('Video file is empty.');
      }

      FastCachedImageConfig.saveImage(url, bytes);
      await _initializePlayer(file);
    } catch (e) {
      rethrow;
    } finally {
      if (!chunkEvents.isClosed) await chunkEvents.close();
    }
  }

  Future<void> _initializePlayer(File file) async {
    try {
      _videoPlayerController = VideoPlayerController.file(file);
      await _videoPlayerController!.initialize();
      if (autoPlay) {
        await _videoPlayerController!.play();
      }
      if (loop) {
        await _videoPlayerController!.setLooping(true);
      }
      value = value.copyWith(
        isLoading: false,
        isInitialized: true,
        error: null,
      );
    } catch (e) {
      value = value.copyWith(
        isLoading: false,
        error: 'Error initializing video player: $e',
      );
    }
  }

  /// Play the video.
  Future<void> play() async {
    await _videoPlayerController?.play();
  }

  /// Pause the video.
  Future<void> pause() async {
    await _videoPlayerController?.pause();
  }

  /// Seek to a specific position.
  Future<void> seekTo(Duration position) async {
    await _videoPlayerController?.seekTo(position);
  }

  /// Set looping.
  Future<void> setLooping(bool looping) async {
    await _videoPlayerController?.setLooping(looping);
  }

  /// Set volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    await _videoPlayerController?.setVolume(volume);
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await _videoPlayerController?.dispose();
    super.dispose();
  }
}
