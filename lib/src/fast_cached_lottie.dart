import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';

import 'models/fast_cache_progress_data.dart';


/// The fast cached lottie implementation.
@immutable
class FastCachedLottie extends StatefulWidget {
  ///[url] is the url of the lottie file (json or zip).
  final String url;

  ///[headers] can be used to send headers with the request.
  final Map<String, dynamic>? headers;

  ///[errorBuilder] can be used to show a custom error widget.
  final Widget Function(
      BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;

  ///[loadingBuilder] can be used to show a custom loading widget.
  final Widget Function(
          BuildContext context, FastCachedProgressData progressData)?
      loadingBuilder;

  ///[width] can be used to set the width of the lottie.
  final double? width;

  ///[height] can be used to set the height of the lottie.
  final double? height;

  ///[fit] can be used to set the fit of the lottie.
  final BoxFit? fit;

  ///[alignment] can be used to set the alignment of the lottie.
  final AlignmentGeometry? alignment;

  ///[fadeInDuration] can be used to set the duration of the fade in animation.
  final Duration fadeInDuration;

  ///[repeat] can be used to set if the animation should repeat. Default is true.
  final bool repeat;

  ///[FastCachedLottie] creates a widget to display network lottie animations.
  const FastCachedLottie({
    required this.url,
    this.headers,
    this.errorBuilder,
    this.loadingBuilder,
    this.width,
    this.height,
    this.fit,
    this.alignment,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.repeat = true,
    super.key,
  });

  @override
  State<FastCachedLottie> createState() => _FastCachedLottieState();
}

class _FastCachedLottieState extends State<FastCachedLottie>
    with TickerProviderStateMixin {
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
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FastCachedLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadAsync(widget.url, widget.headers);
    }
  }

  Future<void> _loadAsync(String url, Map<String, dynamic>? headers) async {
    FastCachedImageConfig._checkInit();

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

    Uint8List? image = FastCachedImageConfig._getImage(url);

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

      Response response = await FastCachedImageConfig._dio.get(
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
              _ImageResponse(imageData: bytes, error: 'Lottie file is empty.'),
        );
        return;
      }
      if (mounted) {
        setState(
          () => _imageResponse = _ImageResponse(imageData: bytes, error: null),
        );
      }

      FastCachedImageConfig._saveImage(url, bytes);
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

  void _logErrors(dynamic error) {
    if (widget.errorBuilder != null) {
      debugPrint('FastCachedLottie: $error');
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
          // // Loading Effect (Builder > Shimmer)
          // if (_imageResponse == null)
          //   widget.loadingBuilder != null
          //       ? ValueListenableBuilder(
          //           valueListenable: _progressData.progressPercentage,
          //           builder: (context, p, c) {
          //             return widget.loadingBuilder!(context, _progressData);
          //           },
          //         )
          //       : Shimmer.fromColors(
          //           baseColor: Colors.grey[300]!,
          //           highlightColor: Colors.grey[100]!,
          //           child: Container(
          //             width: widget.width,
          //             height: widget.height,
          //             color: Colors.white,
          //           ),
          //         ),

          // // Actual Lottie with FadeIn
          AnimatedOpacity(
            opacity: _imageResponse != null ? 1.0 : 0.0,
            duration: widget.fadeInDuration,
            child: _imageResponse == null
                ? const SizedBox()
                : Lottie.memory(
                    _imageResponse!.imageData,
                    width: widget.width,
                    height: widget.height,
                    fit: widget.fit,
                    alignment: widget.alignment,
                    repeat: widget.repeat,
                    errorBuilder: (context, error, stackTrace) {
                      _logErrors(error);
                      FastCachedImageConfig.deleteCachedImage(
                        imageUrl: widget.url,
                        showLog: true,
                      );
                      return widget.errorBuilder != null
                          ? widget.errorBuilder!(context, error, stackTrace)
                          : const SizedBox();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
