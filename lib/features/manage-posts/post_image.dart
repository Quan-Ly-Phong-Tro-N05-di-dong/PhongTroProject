import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'post_model.dart';

// Chạy bằng compute() ở form để việc nén ảnh không chặn giao diện Android.
// Chỉ trả về JPEG <= 100 KiB: 6 ảnh Base64 vẫn dưới giới hạn document 1 MiB.
String compressPostImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Không đọc được ảnh. Hãy chọn ảnh JPG hoặc PNG.');
  }
  final oriented = img.bakeOrientation(decoded);
  for (final edge in [1024, 800, 640, 480, 320]) {
    final largest = oriented.width > oriented.height
        ? oriented.width : oriented.height;
    final resized = largest <= edge
        ? oriented
        : img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? edge : null,
            height: oriented.height > oriented.width ? edge : null,
          );
    // Nền trắng cho PNG trong suốt trước khi chuyển thành JPEG.
    final background = img.Image(width: resized.width, height: resized.height);
    img.fill(background, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(background, resized);
    for (final quality in [80, 65, 50]) {
      final encoded = img.encodeJpg(background, quality: quality);
      if (encoded.length <= maxPostImageBytes) {
        return '$postImagePrefix${base64Encode(encoded)}';
      }
    }
  }
  throw const FormatException('Không thể nén ảnh này. Hãy chọn ảnh khác.');
}

/// Dùng chung cho form, danh sách và chi tiết; hỗ trợ ảnh mới và link cũ.
class PostImage extends StatefulWidget {
  final String source;
  final double height;
  final BoxFit fit;
  const PostImage({
    super.key,
    required this.source,
    required this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<PostImage> {
  Uint8List? _bytes;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _readSource();
  }

  @override
  void didUpdateWidget(covariant PostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _readSource();
  }

  void _readSource() {
    _bytes = null;
    _invalid = false;
    if (widget.source.startsWith(postImagePrefix)) {
      if (widget.source.length > maxEmbeddedImageLength) {
        _invalid = true;
        return;
      }
      try {
        _bytes = base64Decode(widget.source.substring(postImagePrefix.length));
      } on FormatException {
        _invalid = true;
      }
    } else {
      final uri = Uri.tryParse(widget.source);
      _invalid = uri == null || uri.scheme != 'https' || uri.host.isEmpty;
    }
  }

  Widget _placeholder() => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: const Center(child: Text('Không tải được ảnh.')),
  );

  @override
  Widget build(BuildContext context) {
    if (_invalid) return _placeholder();
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        height: widget.height,
        width: double.infinity,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, error, stack) => _placeholder(),
      );
    }
    return Image.network(
      widget.source,
      height: widget.height,
      width: double.infinity,
      fit: widget.fit,
      errorBuilder: (_, error, stack) => _placeholder(),
    );
  }
}

/// Mở ảnh đầy đủ. Giữ nguyên dữ liệu JPEG đã nén và link HTTPS cũ.
void showPostImages(
  BuildContext context,
  List<String> sources, {
  int initialIndex = 0,
}) {
  if (sources.isEmpty) return;
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _PostImageViewer(
        sources: List<String>.unmodifiable(sources),
        initialIndex: initialIndex,
      ),
    ),
  );
}

class PostGallery extends StatefulWidget {
  final List<String> sources;
  const PostGallery({super.key, required this.sources});

  @override
  State<PostGallery> createState() => _PostGalleryState();
}

class _PostGalleryState extends State<PostGallery> {
  int _selected = 0;

  @override
  void didUpdateWidget(covariant PostGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected >= widget.sources.length) _selected = 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (widget.sources.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: Icon(Icons.image_not_supported_outlined, size: 48)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxWidth < 480 ? 260.0 : 340.0;
            return Material(
              color: const Color(0xffedf1f5),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showPostImages(
                  context, widget.sources, initialIndex: _selected,
                ),
                child: Stack(
                  children: [
                    PostImage(
                      source: widget.sources[_selected],
                      height: height,
                      fit: BoxFit.contain,
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, size: 18),
                              SizedBox(width: 4),
                              Text('Xem ảnh lớn'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (widget.sources.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.sources.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Semantics(
                label: 'Ảnh ${index + 1}',
                selected: index == _selected,
                button: true,
                child: SizedBox(
                  width: 88,
                  child: Material(
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: index == _selected
                            ? colors.primary : colors.outlineVariant,
                        width: index == _selected ? 3 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() => _selected = index),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: PostImage(
                          source: widget.sources[index],
                          height: 66,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PostImageViewer extends StatefulWidget {
  final List<String> sources;
  final int initialIndex;
  const _PostImageViewer({required this.sources, required this.initialIndex});

  @override
  State<_PostImageViewer> createState() => _PostImageViewerState();
}

class _PostImageViewerState extends State<_PostImageViewer> {
  final _transform = TransformationController();
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex >= 0 && widget.initialIndex < widget.sources.length
        ? widget.initialIndex : 0;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _setScale(double scale) {
    final matrix = _transform.value.clone();
    matrix.setIdentity();
    matrix.setEntry(0, 0, scale);
    matrix.setEntry(1, 1, scale);
    _transform.value = matrix;
  }

  void _move(int step) {
    final next = _index + step;
    if (next < 0 || next >= widget.sources.length) return;
    _setScale(1);
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Đóng ảnh',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          title: Text('Ảnh ${_index + 1}/${widget.sources.length}'),
          actions: [
            TextButton.icon(
              onPressed: () => _setScale(1),
              icon: const Icon(Icons.fit_screen),
              label: const Text('Vừa khung'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => InteractiveViewer(
                    transformationController: _transform,
                    alignment: Alignment.center,
                    minScale: 1,
                    maxScale: 4,
                    child: PostImage(
                      source: widget.sources[_index],
                      height: constraints.maxHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ValueListenableBuilder(
                  valueListenable: _transform,
                  builder: (context, matrix, child) {
                    final scale = matrix.getMaxScaleOnAxis();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.sources.length > 1)
                          IconButton(
                            tooltip: 'Ảnh trước',
                            onPressed: _index > 0 ? () => _move(-1) : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                        IconButton(
                          tooltip: 'Thu nhỏ',
                          onPressed: scale <= 1 ? null : () => _setScale(
                            (scale / 1.3).clamp(1.0, 4.0).toDouble(),
                          ),
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 54,
                          child: Text(
                            '${(scale * 100).round()}%',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Phóng to',
                          onPressed: scale >= 4 ? null : () => _setScale(
                            (scale * 1.3).clamp(1.0, 4.0).toDouble(),
                          ),
                          icon: const Icon(Icons.add),
                        ),
                        if (widget.sources.length > 1)
                          IconButton(
                            tooltip: 'Ảnh tiếp',
                            onPressed: _index < widget.sources.length - 1
                                ? () => _move(1) : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
