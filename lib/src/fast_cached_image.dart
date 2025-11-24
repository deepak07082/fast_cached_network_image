import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';

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
  ///and the actual image. Default value is 500 ms.
  final Duration fadeInDuration;

  final int? cacheWidth;
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

  ///[showErrorLog] can be set to true if you want to ignore error logs from the widget
  final bool showErrorLog;

  ///[disableErrorLogs] can be set to true if you want to ignore error logs from the widget
  ///Deprecated: Use [showErrorLog] instead.
  @Deprecated('Use showErrorLog instead')
  final bool? disableErrorLogs;

  ///[FastCachedImage] creates a widget to display network images. This widget downloads the network image
  ///when this widget is build for the first time. Later whenever this widget is called the image will be displayed from
  ///the downloaded database instead of the network. This can avoid unnecessary downloads and load images much faster.
  const FastCachedImage({
    required this.url,
    this.headers,
    this.scale = 1.0,
    this.errorBuilder,
    this.semanticLabel,
    this.loadingBuilder,
    this.excludeFromSemantics = false,
    this.showErrorLog = true,
    this.disableErrorLogs,
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
    _loadAsync(widget.url, widget.headers);
  }

  @override
  void didUpdateWidget(covariant FastCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadAsync(widget.url, widget.headers);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageResponse?.error != null && widget.errorBuilder != null) {
      _logErrors(_imageResponse?.error);
      return widget.errorBuilder!(
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
          if (_imageResponse == null)
            widget.loadingBuilder != null
                ? ValueListenableBuilder(
                    valueListenable: _progressData.progressPercentage,
                    builder: (context, p, c) {
                      return widget.loadingBuilder!(context, _progressData);
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

          // Actual Image with FadeIn
          // if (_imageResponse != null)
          AnimatedOpacity(
            opacity: _imageResponse != null ? 1.0 : 0.0,
            duration: widget.fadeInDuration,
            child: _imageResponse == null
                ? const SizedBox()
                : Image.memory(
                    _imageResponse!.imageData,
                    color: widget.color,
                    width: widget.width,
                    height: widget.height,
                    alignment: widget.alignment,
                    key: widget.key,
                    cacheWidth: widget.cacheWidth,
                    cacheHeight: widget.cacheHeight,
                    fit: widget.fit,
                    errorBuilder: (a, c, v) {
                      _logErrors(c);
                      FastCachedImageConfig.deleteCachedImage(
                        imageUrl: widget.url,
                        showLog: widget.showErrorLog,
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

  Future<void> _loadAsync(String url, Map<String, dynamic>? headers) async {
    FastCachedImageConfig.checkInit();

    if (url.isEmpty || Uri.tryParse(url) == null) {
      if (mounted) {
        setState(
          () => _imageResponse = _ImageResponse(
            imageData: Uint8List.fromList([]),
            error: 'Invalid url: $url',
          ),
        );
      }
      return;
    }

    Uint8List? image = FastCachedImageConfig.getImage(url);

    if (!mounted) return;

    if (image != null) {
      Future.delayed(widget.fadeInDuration, () {
        if (mounted) {
          setState(
            () =>
                _imageResponse = _ImageResponse(imageData: image, error: null),
          );
        }
      });
      return;
    }

    StreamController chunkEvents = StreamController();

    try {
      final Uri resolved = Uri.base.resolve(url);
      _progressData.isDownloading = true;
      if (widget.loadingBuilder != null && mounted) {
        widget.loadingBuilder!(context, _progressData);
      }

      Response response = await FastCachedImageConfig.dio.get(
        url,
        options: Options(responseType: ResponseType.bytes, headers: headers),
        onReceiveProgress: (int received, int total) {
          if (received < 0 || total < 0) return;
          if (widget.loadingBuilder != null) {
            _progressData.downloadedBytes = received;
            _progressData.totalBytes = total;
            _progressData.progressPercentage.value =
                double.parse((received / total).toStringAsFixed(2));
            if (mounted) widget.loadingBuilder!(context, _progressData);
          }
          chunkEvents.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: received,
              expectedTotalBytes: total,
            ),
          );
        },
      );

      final Uint8List bytes = response.data;

      if (response.statusCode != 200) {
        String error = NetworkImageLoadException(
          statusCode: response.statusCode ?? 0,
          uri: resolved,
        ).toString();
        if (mounted) {
          setState(
            () => _imageResponse =
                _ImageResponse(imageData: Uint8List.fromList([]), error: error),
          );
        }
        return;
      }

      _progressData.isDownloading = false;

      if (bytes.isEmpty && mounted) {
        setState(
          () => _imageResponse =
              _ImageResponse(imageData: bytes, error: 'Image is empty.'),
        );
        return;
      }
      if (mounted) {
        setState(
          () => _imageResponse = _ImageResponse(imageData: bytes, error: null),
        );
      }

      FastCachedImageConfig.saveImage(url, bytes);
    } catch (e) {
      if (mounted) {
        setState(
          () => _imageResponse = _ImageResponse(
            imageData: Uint8List.fromList([]),
            error: e.toString(),
          ),
        );
      }
    } finally {
      if (!chunkEvents.isClosed) await chunkEvents.close();
    }
  }

  void _logErrors(dynamic object) {
    if (widget.showErrorLog) {
      debugPrint('$object - Image url : ${widget.url}');
    }
  }
}

class _ImageResponse {
  Uint8List imageData;
  String? error;
  _ImageResponse({required this.imageData, required this.error});
}

///[FastCachedImageConfig] is the class to manage and set the cache configurations.
class FastCachedImageConfig {
  static Directory? _cacheDir;
  static bool _isInitialized = false;
  static const String _notInitMessage =
      'FastCachedImage is not initialized. Please use FastCachedImageConfig.init to initialize FastCachedImage';
  static final Dio dio = Dio();

  ///[init] function initializes the cache management system. Use this code only once in the app in main to avoid errors.
  /// You can provide a [subDir] where the boxes should be stored.
  ///[clearCacheAfter] property is used to set a  duration after which the cache will be cleared.
  ///Default value of [clearCacheAfter] is 7 days which means if [clearCacheAfter] is set to null,
  /// an image cached today will be cleared when you open the app after 7 days from now.
  static Future<void> init({String? subDir, Duration? clearCacheAfter}) async {
    if (_isInitialized) return;

    clearCacheAfter ??= const Duration(days: 7);

    final rootDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${rootDir.path}/${subDir ?? 'fast_cache_image'}');

    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }

    _isInitialized = true;
    _clearOldCache(clearCacheAfter);
  }

  static Uint8List? getImage(String url) {
    checkInit();
    final file = _getFile(url);
    if (file.existsSync()) {
      return file.readAsBytesSync();
    }
    return null;
  }

  ///[saveImage] is to save an image to cache. Not part of public API.
  static void saveImage(String url, Uint8List image) {
    checkInit();
    final file = _getFile(url);
    file.writeAsBytesSync(image);
  }

  ///[_clearOldCache] clears the old cache. Not part of public API.
  static void _clearOldCache(Duration clearCacheAfter) {
    checkInit();
    DateTime today = DateTime.now();

    for (final file in _cacheDir!.listSync()) {
      if (file is File) {
        final stat = file.statSync();
        if (today.difference(stat.modified) > clearCacheAfter) {
          file.deleteSync();
        }
      }
    }
  }

  ///[deleteCachedImage] function takes in a image [imageUrl] and removes the image corresponding to the url
  /// from the cache if the image is present in the cache.
  static void deleteCachedImage({
    required String imageUrl,
    bool showLog = true,
  }) {
    checkInit();
    final file = _getFile(imageUrl);
    if (file.existsSync()) {
      file.deleteSync();
      if (showLog) {
        debugPrint('FastCacheImage: Removed image $imageUrl from cache.');
      }
    }
  }

  ///[clearAllCachedImages] function clears all cached images. This can be used in scenarios such as
  ///logout functionality of your app, so that all cached images corresponding to the user's account is removed.
  static void clearAllCachedImages({bool showLog = true}) {
    checkInit();
    if (_cacheDir!.existsSync()) {
      _cacheDir!.deleteSync(recursive: true);
      _cacheDir!.createSync();
      if (showLog) debugPrint('FastCacheImage: All cache cleared.');
    }
  }

  ///[checkInit] method ensures the hive db is initialized. Not part of public API
  static void checkInit() {
    if (!_isInitialized || _cacheDir == null) {
      throw Exception(_notInitMessage);
    }
  }

  ///[isCached] returns a boolean indicating whether the given image is cached or not.
  ///Returns true if cached, false if not.
  static bool isCached({required String imageUrl}) {
    checkInit();
    final file = _getFile(imageUrl);
    return file.existsSync();
  }

  static File _getFile(String url) {
    final key = _keyFromUrl(url);
    return File('${_cacheDir!.path}/$key');
  }

  ///[getCachedFile] returns the file associated with the given url.
  ///This method does not check if the file exists.
  static File getCachedFile(String url) {
    checkInit();
    return _getFile(url);
  }

  static String _keyFromUrl(String url) =>
      const Uuid().v5(Namespace.url.value, url);
}

/// The fast cached image implementation of [ImageProvider].
@immutable
class FastCachedImageProvider extends ImageProvider<NetworkImage>
    implements NetworkImage {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  const FastCachedImageProvider(this.url, {this.scale = 1.0, this.headers});

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

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
      FastCachedImageConfig.checkInit();

      if (url.isEmpty || Uri.tryParse(url) == null) {
        // Throwing NetworkImageLoadException allows the Image widget to catch it and show the errorBuilder
        throw NetworkImageLoadException(
          statusCode: 400,
          uri: Uri.parse(url.isEmpty ? 'empty' : url),
        );
      }

      Uint8List? image = FastCachedImageConfig.getImage(url);
      if (image != null) {
        final ui.ImmutableBuffer buffer =
            await ui.ImmutableBuffer.fromUint8List(image);
        return decode(buffer);
      }

      final Uri resolved = Uri.base.resolve(key.url);

      // if (headers != null) dio.options.headers.addAll(headers!); // Cannot modify shared dio headers globally

      // Create options with headers for this request
      final options = Options(responseType: ResponseType.bytes);
      if (headers != null) {
        options.headers = headers;
      }

      Response response = await FastCachedImageConfig.dio.get(
        url,
        options: options,
        onReceiveProgress: (int received, int total) {
          chunkEvents.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: received,
              expectedTotalBytes: total,
            ),
          );
        },
      );

      final Uint8List bytes = response.data;
      if (bytes.lengthInBytes == 0) {
        throw Exception('NetworkImage is an empty file: $resolved');
      }

      final ui.ImmutableBuffer buffer =
          await ui.ImmutableBuffer.fromUint8List(bytes);
      FastCachedImageConfig.saveImage(url, bytes);
      return decode(buffer);
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a micro-task to give the cache a chance to add the key.
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

class ImageResponse {
  Uint8List imageData;
  String? error;
  ImageResponse({required this.imageData, required this.error});
}
