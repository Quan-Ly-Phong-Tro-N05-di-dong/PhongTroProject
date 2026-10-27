import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'post_image.dart';
import 'post_model.dart';
import 'post_service.dart';

class PostFormPage extends StatefulWidget {
  final RentalPost? post;
  const PostFormPage({super.key, this.post});

  @override
  State<PostFormPage> createState() => _PostFormPageState();
}

class _PostFormPageState extends State<PostFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = PostService();
  late final Map<String, TextEditingController> _controllers;
  final _picker = ImagePicker();
  List<String> _images = [];
  bool _picking = false;
  String? _imageError;
  String _imageStatus = 'Đang đọc ảnh...';

  bool get _busy => _saving || _picking;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    final values = {
      'title': post?.title ?? '',
      'address': post?.address ?? '',
      'price': post == null ? '' : numberForInput(post.price),
      'area': post == null ? '' : numberForInput(post.area),
      'amenities': post?.amenities ?? '',
      'contact': post?.contact ?? '',
    };
    _controllers = {
      for (final item in values.entries)
        item.key: TextEditingController(text: item.value),
    };
    _images = List.of(post?.imageUrls ?? <String>[]);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _picking = true;
      unawaited(_restoreLostImages());
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parseNumber(String input) =>
      double.tryParse(input.trim().replaceAll(',', '.'));

  Future<void> _restoreLostImages() async {
    try {
      final response = await _picker.retrieveLostData();
      if (!mounted || response.isEmpty) return;
      final files = response.files;
      if (files != null && files.isNotEmpty) await _appendPicked(files);
      if (response.exception != null && mounted) {
        setState(() => _imageError = 'Không khôi phục được ảnh. Hãy chọn lại.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _imageError = 'Không đọc được ảnh cũ. Hãy chọn lại ảnh.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _chooseImages() async {
    if (_busy || _images.length >= maxPostImages) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _picking = true;
      _imageError = null;
      _imageStatus = 'Đang mở thư viện...';
    });
    try {
      final List<XFile> files;
      final remaining = maxPostImages - _images.length;
      if (remaining == 1) {
        final file = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        files = file == null ? <XFile>[] : [file];
      } else {
        files = await _picker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
          limit: remaining,
        );
      }
      if (!mounted || files.isEmpty) return;
      await _appendPicked(files);
    } catch (error) {
      if (!mounted) return;
      setState(() => _imageError =
          'Không mở được thư viện. Hãy thử lại. '
          '${PostService.errorText(error)}');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _appendPicked(List<XFile> files) async {
    final images = List<String>.of(_images);
    final warnings = <String>[];
    for (var i = 0; i < files.length; i++) {
      if (!mounted) return;
      if (images.length >= maxPostImages) {
        warnings.add('Chỉ được chọn tối đa 6 ảnh.');
        break;
      }
      setState(() => _imageStatus = 'Đang xử lý ảnh ${i + 1}/${files.length}...');
      try {
        final file = files[i];
        if (await file.length() > 20 * 1024 * 1024) {
          warnings.add('Một ảnh quá lớn (trên 20 MB) đã được bỏ qua.');
          continue;
        }
        final bytes = await file.readAsBytes();
        final source = await compute(compressPostImage, bytes);
        if (!mounted) return;
        if (!images.contains(source)) images.add(source);
      } on FormatException catch (error) {
        warnings.add(error.message);
      } catch (error) {
        warnings.add('Không đọc được một ảnh. Hãy thử ảnh JPG hoặc PNG khác.');
      }
    }
    if (!mounted) return;
    setState(() {
      _images = images;
      _imageError = warnings.isEmpty ? null : warnings.toSet().join('\n');
    });
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final imageError = PostDraft.validateImages(_images);
    if (imageError != null) {
      setState(() => _imageError = imageError);
      return;
    }
    FocusScope.of(context).unfocus();
    final draft = PostDraft(
      title: _controllers['title']!.text,
      address: _controllers['address']!.text,
      price: _parseNumber(_controllers['price']!.text)!,
      area: _parseNumber(_controllers['area']!.text)!,
      amenities: _controllers['amenities']!.text,
      contact: _controllers['contact']!.text,
      imageUrls: _images,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var changed = true;
      final post = widget.post;
      if (post == null) {
        await _service.createPost(
          title: draft.title,
          address: draft.address,
          price: draft.price,
          area: draft.area,
          amenities: draft.amenities,
          contact: draft.contact,
          imageUrls: draft.imageUrls,
        );
      } else {
        changed = await _service.updatePost(post: post, draft: draft);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      if (!changed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nội dung bài đăng không thay đổi.')),
        );
      }
      // Cho PopScope nhận trạng thái mới trước khi đóng form.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop(changed);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = PostService.errorText(error));
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    bool number = false,
    int maximum = 300,
    int lines = 1,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _controllers[key],
        enabled: !_busy,
        maxLength: maximum,
        maxLines: lines,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : lines > 1
            ? TextInputType.multiline
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Vui lòng nhập $label';
          if (text.length > maximum) return 'Tối đa $maximum ký tự';
          if (number) {
            final parsed = _parseNumber(text);
            final limit = key == 'price' ? 1000000000000 : 1000000;
            if (parsed == null ||
                !parsed.isFinite ||
                parsed <= 0 ||
                parsed > limit) {
              return 'Nhập số lớn hơn 0, tối đa $limit';
            }
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.post != null;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? 'Sửa bài đăng' : 'Thêm bài đăng'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (editing) ...[
                const Text(
                  'Thay đổi nội dung sẽ gửi bài về trạng thái chờ duyệt. '
                  'Trạng thái phòng và ẩn/hiện được quản lý ở danh sách bài.',
                ),
                const SizedBox(height: 16),
              ],
              _field('title', 'Tiêu đề', maximum: 120),
              _field('address', 'Địa chỉ', lines: 2),
              _field(
                'price',
                'Giá thuê/tháng (VNĐ)',
                number: true,
                maximum: 20,
                helper: 'Ví dụ: 3000000, không nhập dấu phân cách hàng nghìn.',
              ),
              _field(
                'area',
                'Diện tích (m²)',
                number: true,
                maximum: 20,
                helper: 'Ví dụ: 25 hoặc 25.5',
              ),
              _field('amenities', 'Tiện ích', maximum: 1000, lines: 3),
              _field('contact', 'Thông tin liên hệ', maximum: 150, lines: 2),
              Text(
                'Hình ảnh (${_images.length}/$maxPostImages)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Chọn từ 1 đến 6 ảnh. Ảnh đầu tiên là ảnh bìa. '
                'Ảnh được tự động nén trước khi lưu.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy || _images.length >= maxPostImages
                    ? null : _chooseImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_picking ? _imageStatus : 'Thêm ảnh từ thư viện'),
              ),
              if (_picking) const LinearProgressIndicator(),
              for (var i = 0; i < _images.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: PostImage(source: _images[i], height: 180),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Chip(label: Text(i == 0 ? 'Ảnh bìa' : 'Ảnh ${i + 1}')),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton.filled(
                          tooltip: 'Xóa ảnh ${i + 1}',
                          onPressed: _busy ? null : () {
                            setState(() {
                              _images.removeAt(i);
                              _imageError = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_imageError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _imageError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                SelectableText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.send),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu và gửi duyệt'),
              ),
              if (_saving) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
