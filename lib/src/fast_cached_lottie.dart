import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../fast_cached_network_image.dart';

class FastCachedLottie extends StatefulWidget {
  ///[url] is the url of the lottie file (json or zip).
  final String url;

  ///[headers] can be used to send headers with the request.
  final Map<String, dynamic>? headers;

  ///[errorBuilder] can be used to show a custom error widget.
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )? errorBuilder;

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

  final void Function(LottieComposition)? onLoaded;

  final bool? animate;

  final Animation<double>? controller;

  ///[FastCachedLottie] creates a widget to display network lottie animations.
  const FastCachedLottie({
    required this.url,
    this.headers,
    this.errorBuilder,
    this.width,
    this.height,
    this.fit,
    this.alignment,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.repeat = true,
    this.onLoaded,
    this.animate,
    this.controller,
    super.key,
  });

  @override
  State<FastCachedLottie> createState() => _FastCachedLottieState();
}

class _FastCachedLottieState extends State<FastCachedLottie>
    with TickerProviderStateMixin {
  FileModel? _imageResponse;

  @override
  void initState() {
    super.initState();

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
    var result = await FastCacheHelper.fetchFile(
      url: url,
      headers: headers,
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
      debugPrint('FastCachedLottie: ${_imageResponse?.error}');
      return widget.errorBuilder!(
        context,
        Object,
        StackTrace.fromString(_imageResponse!.error!),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _imageResponse == null
          ? const SizedBox()
          : Lottie.file(
              _imageResponse!.filePath!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              alignment: widget.alignment,
              repeat: widget.repeat,
              onLoaded: widget.onLoaded,
              animate: widget.animate,
              controller: widget.controller,
              errorBuilder: (context, error, stackTrace) {
                FastCachedImageConfig.deleteCachedImage(
                  imageUrl: widget.url,
                );
                return widget.errorBuilder != null
                    ? widget.errorBuilder!(context, error, stackTrace)
                    : const SizedBox();
              },
            ),
    );
  }
}
