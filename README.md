
# Fast Cached Network Image

A flutter package to cache network image easily, with loader, error builder, and smooth fade transitions.
You can also add beautiful loaders and percentage indicators with the total and download size of the image.

Use fast_cache_network_image: 1.0.2 (without "^") for projects with Flutter SDK version < 3.27.1.

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://pub.dev/packages/fast_cache_network_image)
[![pub](https://img.shields.io/pub/v/fast_cache_network_image)](https://pub.dev/packages/fast_cache_network_image)
[![dart](https://img.shields.io/badge/dart-pure%20dart-success)](https://pub.dev/packages/fast_cache_network_image)

## Screenshots

![App caching](https://raw.githubusercontent.com/deepak07082/fast_cached_network_image/main/gif%20images/fast-cache.gif)

![Caching with fade in animation](https://raw.githubusercontent.com/deepak07082/fast_cached_network_image/main/gif%20images/images-in-row.gif)

![Caching with progress indicator and image  size](https://raw.githubusercontent.com/deepak07082/fast_cached_network_image/main/gif%20images/fast%20cache%204.gif)

![The below gif displays a 30 MB image from cache](https://raw.githubusercontent.com/deepak07082/fast_cached_network_image/main/gif%20images/image-with-shimmer.gif)
Use [shimmer](https://pub.dev/packages/shimmer) package to create a beautiful loading widget.


## Usage
Import it
```dart
import 'package:fast_cache_network_image/fast_cache_network_image.dart';
```

> This package uses [Hive_ce](https://pub.dev/packages/hive_ce) as cache container, which uses getApplicationDocumentsDirectory() to get the default path in case subDir is not specified

Initialize the cache configuration in the main function.
```dart
await FastCachedImageConfig.init();
```

The init function takes 2 arguments which are subDir, and clearCacheAfter. Both are optional.

To set a custom directory for your storage box, you can use [path_provider](https://pub.dev/packages/path_provider)
```dart
String storageLocation = (await getApplicationDocumentsDirectory()).path;
```
and then pass the storageLocation to the subDir parameter.

The clearCacheAfter property is used to set the Duration after with the cached image will be cleared. By default its set to 7 days, which means an image cached today will be deleted when you open the app after 7 days.


Use it as a Widget

```dart
child: FastCachedImage(url: url)
```

## Properties
``` dart
errorBuilder: (context, exception, stacktrace) {
  return Text(stacktrace.toString());
},
```
errorBuilder property needs to return a widget. This widget will be displayed if there is any error while loading the provided image.
``` dart

loadingBuilder: (context, progress) {
  return Container(
    color: Colors.yellow,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (progress.isDownloading && progress.totalBytes != null)
          Text('${progress.downloadedBytes ~/ 1024} / ${progress.totalBytes! ~/ 1024} kb',
              style: const TextStyle(color: Colors.red)),
        SizedBox(
            width: 120,
            height: 120,
            child:
            CircularProgressIndicator(color: Colors.red, value: progress.progressPercentage.value)),
      ],
    ),
  );
},
```
loadingBuilder property can be used to display a loading widget such as a shimmer. This widget will be displayed while the image is being downloaded and processed.
loadingBuilder provides a progress property which can be used to display the image download progress with the size(in bytes) of the image.

```dart
fadeInDuration: const Duration(seconds: 1);
```
fadeInDuration property can be use to set the fadeInDuration between the loadingBuilder and the image. Default duration is 500 milliseconds


```dart
FastCachedImageConfig.isCached(imageUrl: url));
```
You can pass in a url to this method and check whether the image in the url is already cached.


```dart
FastCachedImageConfig.deleteCachedImage(imageUrl: url);
```
This method deletes the image with given url from cache.

```dart
FastCachedImageConfig.clearAllCachedImages();
```
This method removes all the cached images. This method can be used in situations such as user logout, where you need to
clear all the images corresponding to the particular user.

If an image had some errors while displaying, the image will be automatically re - downloaded when the image is requested again.

FastCachedImage have all other default properties such as height, width etc. provided by flutter.


If you want to use an image from cache as image provider, use

```dart
FastCachedImageProvider(url);
```


## Example

```dart
import 'package:fast_cache_network_image/fast_cache_network_image.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FastCachedImageConfig.init(clearCacheAfter: const Duration(days: 15));

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String url1 = 'https://www.sefram.com/images/products/photos/hi_res/7202.jpg';

  bool isImageCached = false;
  String? log;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: FastCachedImage(
                      url: url1,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(seconds: 1),
                      errorBuilder: (context, exception, stacktrace) {
                        return Text(stacktrace.toString());
                      },
                      loadingBuilder: (context, progress) {
                        return Container(
                          color: Colors.yellow,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (progress.isDownloading && progress.totalBytes != null)
                                Text('${progress.downloadedBytes ~/ 1024} / ${progress.totalBytes! ~/ 1024} kb',
                                    style: const TextStyle(color: Colors.red)),
                              
                              SizedBox(
                                  width: 120,
                                  height: 120,
                                  child:
                                  CircularProgressIndicator(color: Colors.red, value: progress.progressPercentage.value)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  
                  Text('Is image cached? = $isImageCached', style: const TextStyle(color: Colors.red)),
                 
                  const SizedBox(height: 12),
                  
                  Text(log ?? ''),

                  const SizedBox(height: 120),

                  MaterialButton(
                    onPressed: () async {
                      setState(() => isImageCached = FastCachedImageConfig.isCached(imageUrl: url1));
                    },
                    child: const Text('check image is cached or not'),
                  ),

                  const SizedBox(height: 12),

                  MaterialButton(
                    onPressed: () async {
                      await FastCachedImageConfig.deleteCachedImage(imageUrl: url1);
                      setState(() => log = 'deleted image $url1');
                      await Future.delayed(const Duration(seconds: 2), () => setState(() => log = null));
                    },
                    child: const Text('delete cached image'),
                  ),

                  const SizedBox(height: 12),

                  MaterialButton(
                    onPressed: () async {
                      await FastCachedImageConfig.clearAllCachedImages();
                      setState(() => log = 'All cached images deleted');
                      await Future.delayed(const Duration(seconds: 2), () => setState(() => log = null));
                    },
                    child: const Text('delete all cached images'),
                  ),
                ],
              ),
            )));
  }
}


```

Feel free to contribute and support.

## Contributors 🤝

Big thanks go to these wonderful people:

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/CHRISTOPANANJICKAL"><img src="https://avatars.githubusercontent.com/u/58786637?v=4" width="100px;" alt=""/><br /><sub><b>Author: Christo Pananjickal</b></sub></a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/woutervanwijk"><img src="https://avatars.githubusercontent.com/u/480348?v=4" width="100px;" alt=""/><br /><sub><b>Contributor: Wouter van Wijk</b></sub></a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/MerdanDev"><img src="https://avatars.githubusercontent.com/u/70772623?v=4" width="100px;" alt=""/><br /><sub><b>Contributor: Merdan Atamyradow</b></sub></a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/stevenosse"><img src="https://avatars.githubusercontent.com/u/33069233?v=4" width="100px;" alt=""/><br /><sub><b>Contributor: Steve</b></sub></a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/suyog-patil-21"><img src="https://avatars.githubusercontent.com/u/67726767?v=4" width="100px;" alt=""/><br /><sub><b>Contributor: Suyog Patil</b></sub></a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->




## Package on pub.dev

[fast_cache_network_image](https://pub.dev/packages/fast_cache_network_image)

