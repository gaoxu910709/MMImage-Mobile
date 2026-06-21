import 'dart:collection';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // 已存在于 pubspec

import '../models/image_suit.dart';
import '../store.dart';
import '../utils.dart';

class ViewPage extends StatefulWidget {
  ViewPage({super.key, required this.imageSuit})
      : images = getImageURLs(imageSuit);

  final ImageSuit imageSuit;
  final List<String> images;

  @override
  State<ViewPage> createState() => _ViewPageState();
}

class _ViewPageState extends State<ViewPage> {
  final HashSet<int> _cachedIndexes = HashSet<int>();
  final ValueNotifier<int> _pageIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isAppBarVisible = ValueNotifier<bool>(true); // 默认显示

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageIndexNotifier.value == 0) {
      _preloadImage(0, viewCacheStep);
    }
  }

  void _preloadImage(int start, [int len = 1]) {
    if (start < 0 || start >= widget.images.length) return;
    final int end = min(widget.images.length, start + len);
    for (int i = start; i < end; i++) {
      if (!_cachedIndexes.contains(i)) {
        precacheImage(CachedNetworkImageProvider(widget.images[i]), context);
        _cachedIndexes.add(i);
      }
    }
  }

  void _toggleAppBar() {
    _isAppBarVisible.value = !_isAppBarVisible.value;
  }

  // 下载图片
  Future<void> _downloadImage() async {
    final url = widget.images[_pageIndexNotifier.value];
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在下载图片...')),
      );
    }
  }

  // 设为壁纸（提示用户）
  void _setAsWallpaper() {
    _downloadImage();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设为壁纸'),
        content: const Text('图片已开始下载\n下载完成后请在相册中长按图片 → 设为壁纸'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: NotificationListener<ScrollUpdateNotification>(
            onNotification: (_) {
              if (_isAppBarVisible.value) _toggleAppBar();
              return false;
            },
            child: GestureDetector(
              onTap: _toggleAppBar,
              child: _photoPageView(),
            ),
          ),
        ),
        // 顶部工具栏
        ValueListenableBuilder(
          valueListenable: _isAppBarVisible,
          builder: (context, isVisible, child) {
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: isVisible ? 0 : -100,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.95),
                elevation: 2,
                leading: IconButton(
                  icon: const Icon(CupertinoIcons.back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: ValueListenableBuilder(
                  valueListenable: _pageIndexNotifier,
                  builder: (context, page, _) => Text(
                    '${page + 1} / ${widget.images.length}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.download), onPressed: _downloadImage),
                  IconButton(icon: const Icon(Icons.wallpaper), onPressed: _setAsWallpaper),
                  LikeorDislikeButton(imageSuit: widget.imageSuit),
                ],
              ),
            );
          },
        ),
        // 底部圆点页码（类似你图二）
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: ValueListenableBuilder(
            valueListenable: _pageIndexNotifier,
            builder: (context, page, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => GestureDetector(
                    onTap: () {
                      // 可跳转到指定页（PhotoView 支持）
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == page ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == page ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  PhotoViewGallery _photoPageView() {
    return PhotoViewGallery.builder(
      allowImplicitScrolling: true,
      wantKeepAlive: true,
      itemCount: widget.images.length,
      builder: (context, index) => PhotoViewGalleryPageOptions(
        imageProvider: CachedNetworkImageProvider(widget.images[index]),
      ),
      pageController: PageController(initialPage: _pageIndexNotifier.value),
      onPageChanged: (index) {
        if (index > _pageIndexNotifier.value) {
          _preloadImage(index + viewCacheStep - 1);
        }
        _pageIndexNotifier.value = index;
      },
      scrollDirection: Axis.horizontal,
      backgroundDecoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
    );
  }
}

// 收藏按钮保持不变
class LikeorDislikeButton extends StatelessWidget {
  const LikeorDislikeButton({super.key, required this.imageSuit});
  final ImageSuit imageSuit;

  @override
  Widget build(BuildContext context) {
    final toggle = context.read<GlobalStore>().toggle;
    final flag = context
        .select<GlobalStore, Map<String, ImageSuit>>((store) => store.collections)
        .containsKey(getId(imageSuit));

    return IconButton(
      icon: Icon(flag ? CupertinoIcons.heart_fill : CupertinoIcons.heart),
      onPressed: () => toggle(imageSuit),
    );
  }
}