import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'fast_cache_helper.dart';

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
      var result = await FastCacheHelper.fetchFile(
        url: url,
        headers: headers,
        loadingBuilder: (processData) {
          var received = processData.downloadedBytes;
          var total = processData.totalBytes ?? 0;
          if (received < 0 || total < 0) return;
          if (_isDisposed) return;
          value = value.copyWith(
            progress: double.parse((received / total).toStringAsFixed(2)),
          );
        },
      );

      if (result.filePath != null) {
        await _initializePlayer(result.filePath!);
      }
    } catch (e) {
      value = value.copyWith(
        isLoading: false,
        error: e.toString(),
      );
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
