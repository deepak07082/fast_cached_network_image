import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

///[FastCachedImageConfig] is the class to manage and set the cache configurations.
class FastCachedImageConfig {
  static Directory? _cacheDir;
  static bool _isInitialized = false;
  static bool showLog = false;
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

    final rootDir = await getApplicationCacheDirectory();
    _cacheDir = Directory('${rootDir.path}/${subDir ?? 'fast_cache_image'}');

    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }

    _isInitialized = true;
    _clearOldCache(clearCacheAfter);
  }

  ///[saveImage] is to save an image to cache
  static void saveImage(String url, Uint8List image) {
    checkInit();
    final file = _getFile(url);
    file.writeAsBytesSync(image);
  }

  ///[_clearOldCache] clears the old cache
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
