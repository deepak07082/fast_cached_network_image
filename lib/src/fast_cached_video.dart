import './fast_cached_video_controller.dart';
import './models/fast_cache_progress_data.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

/// The fast cached video implementation.
@immutable
class FastCachedVideo extends StatefulWidget {
  ///[controller] manages the video downloading, caching, and playback.
  final FastCachedVideoController controller;

  ///[errorBuilder] can be used to show a custom error widget.
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )? errorBuilder;

  ///[loadingBuilder] can be used to show a custom loading widget.
  final Widget Function(
    BuildContext context,
    FastCachedProgressData progressData,
  )? loadingBuilder;

  ///[width] can be used to set the width of the video.
  final double? width;

  ///[height] can be used to set the height of the video.
  final double? height;

  ///[fit] can be used to set the fit of the video.
  final BoxFit? fit;

  ///[alignment] can be used to set the alignment of the video.
  final AlignmentGeometry alignment;

  ///[fadeInDuration] can be used to set the duration of the fade in animation.
  final Duration fadeInDuration;

  ///[FastCachedVideo] creates a widget to display network videos.
  const FastCachedVideo({
    required this.controller,
    this.errorBuilder,
    this.loadingBuilder,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.fadeInDuration = const Duration(milliseconds: 500),
    super.key,
  });

  @override
  State<FastCachedVideo> createState() => _FastCachedVideoState();
}

class _FastCachedVideoState extends State<FastCachedVideo> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  void _logErrors(dynamic error) {
    if (widget.errorBuilder != null) {
      debugPrint('FastCachedVideo: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FastCachedVideoValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        if (value.error != null && widget.errorBuilder != null) {
          _logErrors(value.error);
          return widget.errorBuilder!(
            context,
            Object,
            StackTrace.fromString(value.error!),
          );
        }

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.passthrough,
            children: [
              // Loading Effect (Builder > Shimmer)
              if (!value.isInitialized)
                widget.loadingBuilder != null
                    ? widget.loadingBuilder!(
                        context,
                        FastCachedProgressData(
                          progressPercentage: ValueNotifier(value.progress),
                          totalBytes: null,
                          downloadedBytes: 0,
                          isDownloading: value.isLoading,
                        ),
                      )
                    : Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: widget.width,
                          height: widget.height,
                          color: Colors.white,
                        ),
                      ),

              // Actual Video with FadeIn
              AnimatedOpacity(
                opacity: value.isInitialized ? 1.0 : 0.0,
                duration: widget.fadeInDuration,
                child: value.isInitialized &&
                        widget.controller.videoPlayerController != null
                    ? SizedBox(
                        width: widget.width,
                        height: widget.height,
                        child: FittedBox(
                          fit: widget.fit ?? BoxFit.contain,
                          alignment: widget.alignment,
                          child: SizedBox(
                            width: widget.controller.videoPlayerController!
                                .value.size.width,
                            height: widget.controller.videoPlayerController!
                                .value.size.height,
                            child: VideoPlayer(
                              widget.controller.videoPlayerController!,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        );
      },
    );
  }
}
