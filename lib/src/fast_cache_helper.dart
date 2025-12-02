import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../fast_cached_network_image.dart';

class FastCacheHelper {
  static Future<FileModel> fetchFile({
    required String url,
    Map<String, dynamic>? headers,
    void Function(FastCachedProgressData)? loadingBuilder,
  }) async {
    FastCachedImageConfig.checkInit();

    if (url.isEmpty || Uri.tryParse(url) == null) {
      return FileModel(
        filePath: null,
        error: 'Invalid url: $url',
      );
    }

    if (FastCachedImageConfig.isCached(imageUrl: url)) {
      var image = FastCachedImageConfig.getCachedFile(url);
      if (image.existsSync()) {
        return FileModel(
          filePath: image,
          error: null,
        );
      }
    }

    try {
      final Uri resolved = Uri.base.resolve(url);
      FastCachedProgressData? _progressData;
      if (loadingBuilder != null) {
        _progressData = FastCachedProgressData(
          progressPercentage: ValueNotifier(0),
          totalBytes: null,
          downloadedBytes: 0,
          isDownloading: true,
        );
        loadingBuilder.call(_progressData);
      }

      Response response = await FastCachedImageConfig.dio.get(
        url,
        options: Options(responseType: ResponseType.bytes, headers: headers),
        onReceiveProgress: (int received, int total) {
          if (received < 0 || total < 0) return;
          if (loadingBuilder != null) {
            _progressData?.downloadedBytes = received;
            _progressData?.totalBytes = total;
            _progressData?.progressPercentage.value =
                double.parse((received / total).toStringAsFixed(2));
            loadingBuilder.call(_progressData!);
          }
        },
      );

      if (response.statusCode != 200) {
        return FileModel(
          filePath: null,
          error: NetworkImageLoadException(
            statusCode: response.statusCode ?? -1,
            uri: resolved,
          ).toString(),
        );
      } else {
        if (response.data.isEmpty) {
          return FileModel(
            filePath: null,
            error: 'downloaded file byte is empty.',
          );
        }
        FastCachedImageConfig.saveImage(url, response.data);
        var image = FastCachedImageConfig.getCachedFile(url);
        if (image.existsSync()) {
          return FileModel(
            filePath: image,
            error: null,
          );
        }
      }
    } catch (e) {
      return FileModel(
        filePath: null,
        error: e.toString(),
      );
    }
    return FileModel(filePath: null, error: 'Unknown error');
  }
}
