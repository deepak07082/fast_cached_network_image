import 'dart:async';
import 'dart:ui' as ui;

import 'fast_cache_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'fast_cache_helper.dart';
import 'models/fast_cache_progress_data.dart';

class FastCachedImage extends StatefulWidget {
  ///Provide the [url] for the image to display.
  final String url;

  ///Provide the [headers] for the image to display.
  final Map<String, dynamic>? headers;

  ///[errorBuilder] must return a widget. This widget will be displayed if there is any error in downloading or displaying
  ///the downloaded image
  final ImageErrorWidgetBuilder? errorBuilder;

  ///[loadingBuilder] is the builder which can show the download progress of an image.
  ///Usage: loadingBuilder(context, FastCachedProgressData progressData){return  Text('${progress.downloadedBytes ~/ 1024} / ${progress.totalBytes! ~/ 1024} kb')}
  final Widget Function(BuildContext, FastCachedProgressData)? loadingBuilder;

  ///[fadeInDuration] can be adjusted to change the duration of the fade transition between the [loadingBuilder]
  final Duration fadeInDuration;

  final int? cacheWidth;

  final bool? enableShimmer;

  final int? cacheHeight;

  ///[width] width of the image
  final double? width;

  ///[height] of the image
  final double? height;

  ///[scale] property in Flutter memory image.
  final double scale;

  ///[color] property in Flutter memory image.
  final Color? color;

  ///[opacity] property in Flutter memory image.
  final Animation<double>? opacity;

  /// [filterQuality] property in Flutter memory image.
  final FilterQuality filterQuality;

  ///[colorBlendMode] property in Flutter memory image
  final BlendMode? colorBlendMode;

  ///[fit] How a box should be inscribed into another box
  final BoxFit? fit;

  /// [alignment] property in Flutter memory image.
  final AlignmentGeometry alignment;

  ///[repeat] property in Flutter memory image.
  final ImageRepeat repeat;

  ///[centerSlice] property in Flutter memory image.
  final Rect? centerSlice;

  ///[matchTextDirection] property in Flutter memory image.
  final bool matchTextDirection;

  /// [gaplessPlayback] property in Flutter memory image.
  final bool gaplessPlayback;

  ///[semanticLabel] property in Flutter memory image.
  final String? semanticLabel;

  ///[excludeFromSemantics] property in Flutter memory image.
  final bool excludeFromSemantics;

  ///[isAntiAlias] property in Flutter memory image.
  final bool isAntiAlias;

  const FastCachedImage({
    required this.url,
    this.headers,
    this.scale = 1.0,
    this.errorBuilder,
    this.semanticLabel,
    this.loadingBuilder,
    this.excludeFromSemantics = false,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.cacheWidth,
    this.cacheHeight,
    this.enableShimmer = true,
    super.key,
  });

  @override
  State<FastCachedImage> createState() => _FastCachedImageState();
}

class _FastCachedImageState extends State<FastCachedImage> {
  FileModel? _imageResponse;
  FastCachedProgressData? _progressData;

  @override
  void initState() {
    super.initState();
    _loadAsync(widget.url, widget.headers);
  }

  @override
  void didUpdateWidget(covariant FastCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadAsync(widget.url, widget.headers);
    }
  }

  Future<void> _loadAsync(String url, Map<String, dynamic>? headers) async {
    var result = await FastCacheHelper.fetchFile(
      url: url,
      headers: headers,
      loadingBuilder: (progress) {
        if (mounted) {
          setState(() {
            _progressData = progress;
          });
        }
      },
    );
    if (mounted) {
      setState(() {
        _imageResponse = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageResponse?.error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!.call(
        context,
        Object,
        StackTrace.fromString(_imageResponse!.error!),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.passthrough,
        children: [
          if (widget.enableShimmer == false)
            SizedBox()
          else if (_imageResponse == null)
            widget.loadingBuilder != null && _progressData != null
                ? ValueListenableBuilder(
                    valueListenable: _progressData!.progressPercentage,
                    builder: (context, p, c) {
                      return widget.loadingBuilder!
                          .call(context, _progressData!);
                    },
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
          AnimatedOpacity(
            opacity: _imageResponse != null ? 1.0 : 0.0,
            duration: widget.fadeInDuration,
            child: _imageResponse == null
                ? const SizedBox()
                : Image.file(
                    _imageResponse!.filePath!,
                    color: widget.color,
                    width: widget.width,
                    height: widget.height,
                    alignment: widget.alignment,
                    key: widget.key,
                    cacheWidth: widget.cacheWidth,
                    cacheHeight: widget.cacheHeight,
                    fit: widget.fit,
                    errorBuilder: (a, c, v) {
                      FastCachedImageConfig.deleteCachedImage(
                        imageUrl: widget.url,
                      );
                      return widget.errorBuilder != null
                          ? widget.errorBuilder!(a, c, v)
                          : const SizedBox();
                    },
                    centerSlice: widget.centerSlice,
                    colorBlendMode: widget.colorBlendMode,
                    excludeFromSemantics: widget.excludeFromSemantics,
                    filterQuality: widget.filterQuality,
                    gaplessPlayback: widget.gaplessPlayback,
                    isAntiAlias: widget.isAntiAlias,
                    matchTextDirection: widget.matchTextDirection,
                    opacity: widget.opacity,
                    repeat: widget.repeat,
                    scale: widget.scale,
                    semanticLabel: widget.semanticLabel,
                  ),
          ),
        ],
      ),
    );
  }
}

class FastCachedImageProvider extends ImageProvider<NetworkImage>
    implements NetworkImage {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  const FastCachedImageProvider(
    this.url, {
    required this.fallBackUrl,
    this.scale = 1.0,
    this.headers,
  });

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

  final String? fallBackUrl;

  @override
  Future<FastCachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FastCachedImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    NetworkImage key,
    ImageDecoderCallback decode,
  ) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key as FastCachedImageProvider, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<NetworkImage>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    FastCachedImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    try {
      assert(key == this);

      var result = await FastCacheHelper.fetchFile(
        url: url == '' ? (fallBackUrl ?? '') : url,
        headers: headers,
        loadingBuilder: (progress) {
          chunkEvents.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: progress.downloadedBytes,
              expectedTotalBytes: progress.totalBytes,
            ),
          );
        },
      );

      if (result.error != null) {
        result = await FastCacheHelper.fetchFile(
          url: fallBackUrl ?? '',
          headers: headers,
          loadingBuilder: (progress) {
            chunkEvents.add(
              ImageChunkEvent(
                cumulativeBytesLoaded: progress.downloadedBytes,
                expectedTotalBytes: progress.totalBytes,
              ),
            );
          },
        );
      }

      final ui.ImmutableBuffer buffer =
          await ui.ImmutableBuffer.fromFilePath(result.filePath!.path);
      return decode(buffer);
    } catch (e) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is FastCachedImageProvider &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NetworkImage')}("$url", scale: $scale)';

  @override
  WebHtmlElementStrategy get webHtmlElementStrategy =>
      WebHtmlElementStrategy.never;
}
