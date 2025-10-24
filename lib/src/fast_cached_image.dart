import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:uuid/uuid.dart';
import 'models/fast_cache_progress_data.dart';

class FastCachedImage extends StatefulWidget {
  final String url;
  final Map<String, dynamic>? headers;
  final ImageErrorWidgetBuilder? errorBuilder;
  final Widget Function(BuildContext, FastCachedProgressData)? loadingBuilder;
  final Duration fadeInDuration;
  final int? cacheWidth;
  final int? cacheHeight;
  final double? width;
  final double? height;
  final double scale;
  final Color? color;
  final Animation<double>? opacity;
  final FilterQuality filterQuality;
  final BlendMode? colorBlendMode;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final bool isAntiAlias;
  final bool showErrorLog;

  const FastCachedImage({
    required this.url,
    this.headers,
    this.scale = 1.0,
    this.errorBuilder,
    this.semanticLabel,
    this.loadingBuilder,
    this.excludeFromSemantics = false,
    this.showErrorLog = true,
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
    super.key,
  });

  @override
  State<FastCachedImage> createState() => _FastCachedImageState();
}

class _FastCachedImageState extends State<FastCachedImage> {
  _ImageResponse? _imageResponse;
  late FastCachedProgressData _progressData;

  @override
  void initState() {
    super.initState();
    _progressData = FastCachedProgressData(
      progressPercentage: ValueNotifier(0),
      totalBytes: null,
      downloadedBytes: 0,
      isDownloading: false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImage();
    });
  }

  @override
  void didUpdateWidget(covariant FastCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _loadImage();
  }

  Future<void> _loadImage() async {
    FastCachedImageConfig._checkInit();
    final cachedImage = await FastCachedImageConfig._getImage(widget.url);
    if (!mounted) return;

    if (cachedImage != null) {
      _imageResponse = _ImageResponse(imageData: cachedImage, error: null);
      setState(() {});
      return;
    }

    _progressData.isDownloading = true;

    try {
      final response = await Dio().get<Uint8List>(
        widget.url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: widget.headers,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _progressData
              ..downloadedBytes = received
              ..totalBytes = total
              ..progressPercentage.value =
                  double.parse((received / total).toStringAsFixed(2));
          }
        },
      );

      if (!mounted || response.data == null) return;

      if (response.statusCode != 200 || response.data!.isEmpty) {
        _setError(
          'Failed to load image: status ${response.statusCode ?? 'unknown'}',
        );
        return;
      }

      _imageResponse = _ImageResponse(imageData: response.data!, error: null);
      _progressData.isDownloading = false;
      setState(() {});
      await FastCachedImageConfig._saveImage(widget.url, response.data!);
    } catch (e) {
      if (!mounted) return;
      _setError(e.toString());
    }
  }

  void _setError(String error) {
    _imageResponse =
        _ImageResponse(imageData: Uint8List.fromList([]), error: error);
    if (widget.showErrorLog) debugPrint('$error - Image url : ${widget.url}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_imageResponse?.error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(
        context,
        Object,
        StackTrace.fromString(_imageResponse!.error!),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_imageResponse == null && widget.loadingBuilder != null)
          ValueListenableBuilder<double>(
            valueListenable: _progressData.progressPercentage,
            builder: (_, __, ___) =>
                widget.loadingBuilder!(context, _progressData),
          ),
        if (_imageResponse != null)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: widget.fadeInDuration,
            builder: (context, opacity, child) {
              return Opacity(
                opacity: opacity,
                child: child,
              );
            },
            child: Image.memory(
              _imageResponse!.imageData,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              alignment: widget.alignment,
              color: widget.color,
              opacity: widget.opacity,
              cacheWidth: widget.cacheWidth,
              cacheHeight: widget.cacheHeight,
              centerSlice: widget.centerSlice,
              colorBlendMode: widget.colorBlendMode,
              excludeFromSemantics: widget.excludeFromSemantics,
              filterQuality: widget.filterQuality,
              gaplessPlayback: widget.gaplessPlayback,
              isAntiAlias: widget.isAntiAlias,
              matchTextDirection: widget.matchTextDirection,
              repeat: widget.repeat,
              scale: widget.scale,
              semanticLabel: widget.semanticLabel,
              errorBuilder: (a, b, c) {
                _setError(b.toString());
                return widget.errorBuilder != null
                    ? widget.errorBuilder!(a, b, c)
                    : const SizedBox();
              },
            ),
          ),
      ],
    );
  }
}

class _ImageResponse {
  Uint8List imageData;
  String? error;
  _ImageResponse({required this.imageData, required this.error});
}

class FastCachedImageConfig {
  static LazyBox<Uint8List>? _imageBox;
  static LazyBox<DateTime>? _imageKeyBox;
  static bool _isInitialized = false;
  static const String _notInitMessage =
      'FastCachedImage is not initialized. Please call FastCachedImageConfig.init() first.';

  /// Initialize Hive and cache boxes. Only call once in `main()`.
  static Future<void> init({String? subDir, Duration? clearCacheAfter}) async {
    if (_isInitialized) return;

    clearCacheAfter ??= const Duration(days: 7);

    await Hive.initFlutter(subDir);
    _imageKeyBox = await Hive.openLazyBox<DateTime>(_BoxNames.imagesKeyBox);
    _imageBox = await Hive.openLazyBox<Uint8List>(_BoxNames.imagesBox);

    _isInitialized = true;
    await _clearOldCache(clearCacheAfter);
  }

  /// Returns cached image if exists, otherwise null
  static Future<Uint8List?> _getImage(String url) async {
    _checkInit();
    final key = _keyFromUrl(url);

    if (_imageKeyBox!.containsKey(url) && _imageBox!.containsKey(url)) {
      // Migrate old key to new key
      final oldImage = await _imageBox!.get(url);
      final date = await _imageKeyBox!.get(url);
      if (oldImage != null && date != null) {
        await _replaceImageKey(oldKey: url, newKey: key);
        await _replaceOldImage(oldKey: url, newKey: key, image: oldImage);
      }
    }

    if (_imageKeyBox!.containsKey(key) && _imageBox!.containsKey(key)) {
      final data = await _imageBox!.get(key);
      return (data != null && data.isNotEmpty) ? data : null;
    }

    return null;
  }

  /// Save image to cache
  static Future<void> _saveImage(String url, Uint8List image) async {
    _checkInit();
    final key = _keyFromUrl(url);
    await Future.wait([
      _imageBox!.put(key, image),
      _imageKeyBox!.put(key, DateTime.now()),
    ]);
  }

  /// Delete old cache
  static Future<void> _clearOldCache(Duration clearAfter) async {
    _checkInit();
    final now = DateTime.now();
    for (final key in _imageKeyBox!.keys) {
      final created = await _imageKeyBox!.get(key);
      if (created == null || now.difference(created) <= clearAfter) continue;
      await Future.wait([_imageBox!.delete(key), _imageKeyBox!.delete(key)]);
    }
  }

  static Future<void> _replaceImageKey({
    required String oldKey,
    required String newKey,
  }) async {
    _checkInit();
    final dateCreated = await _imageKeyBox!.get(oldKey);
    if (dateCreated == null) return;
    await _imageKeyBox!
      ..delete(oldKey)
      ..put(newKey, dateCreated);
  }

  static Future<void> _replaceOldImage({
    required String oldKey,
    required String newKey,
    required Uint8List image,
  }) async {
    _checkInit();
    await Future.wait([
      _imageBox!.delete(oldKey),
      _imageBox!.put(newKey, image),
    ]);
  }

  /// Delete a specific cached image
  static Future<void> deleteCachedImage({
    required String imageUrl,
    bool showLog = true,
  }) async {
    _checkInit();
    final key = _keyFromUrl(imageUrl);
    if (_imageKeyBox!.containsKey(key) && _imageBox!.containsKey(key)) {
      await Future.wait([_imageBox!.delete(key), _imageKeyBox!.delete(key)]);
      if (showLog) debugPrint('FastCachedImage: Removed $imageUrl from cache.');
    }
  }

  /// Clear all cache
  static Future<void> clearAllCachedImages({bool showLog = true}) async {
    _checkInit();
    await Future.wait(
      [_imageBox!.deleteFromDisk(), _imageKeyBox!.deleteFromDisk()],
    );
    if (showLog) debugPrint('FastCachedImage: All cache cleared.');
    _imageBox = await Hive.openLazyBox(_BoxNames.imagesBox);
    _imageKeyBox = await Hive.openLazyBox(_BoxNames.imagesKeyBox);
  }

  /// Check if image is cached
  static Future<bool> isCached({required String imageUrl}) async {
    _checkInit();
    final key = _keyFromUrl(imageUrl);
    return _imageKeyBox!.containsKey(key) && _imageBox!.containsKey(key);
  }

  static void _checkInit() {
    if (!_isInitialized || _imageBox == null || _imageKeyBox == null) {
      throw Exception(_notInitMessage);
    }
  }

  static String _keyFromUrl(String url) =>
      const Uuid().v5(Namespace.url.value, url);
}

///[_BoxNames] contains the name of the boxes. Not part of public API
class _BoxNames {
  ///[imagesBox] db for images
  static String imagesBox = 'cachedImages';

  ///[imagesKeyBox] db for keys of images
  static String imagesKeyBox = 'cachedImagesKeys';
}

class FastCachedImageProvider extends ImageProvider<FastCachedImageProvider> {
  const FastCachedImageProvider(this.url, {this.scale = 1.0, this.headers});

  final String url;
  final double scale;
  final Map<String, String>? headers;

  @override
  Future<FastCachedImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    FastCachedImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<FastCachedImageProvider>('Image key', key),
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
      final bytes = await _fetchImageBytes();

      if (bytes.isEmpty) {
        throw Exception('NetworkImage is empty: ${Uri.base.resolve(key.url)}');
      }

      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }

  Future<Uint8List> _fetchImageBytes() async {
    FastCachedImageConfig._checkInit();

    // Check cache first
    final cached = await FastCachedImageConfig._getImage(url);
    if (cached != null) return cached;

    // Fetch from network
    final uri = Uri.base.resolve(url);
    final dio = Dio();
    if (headers != null) dio.options.headers.addAll(headers!);

    final response = await dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        // optionally handle chunk progress
      },
    );

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('NetworkImage failed or empty: $uri');
    }

    await FastCachedImageConfig._saveImage(url, bytes);
    return bytes;
  }

  @override
  bool operator ==(Object other) =>
      other is FastCachedImageProvider &&
      other.url == url &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => 'FastCachedImageProvider("$url", scale: $scale)';
}
