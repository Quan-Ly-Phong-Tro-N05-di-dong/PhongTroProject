import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'post_form_page.dart';
import 'post_image.dart';
import 'post_model.dart';
import 'post_service.dart';

class PostsPage extends StatefulWidget {
  final String role;
  const PostsPage({super.key, required this.role});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  final _service = PostService();
  int _selectedTab = 0;
  bool _busy = false;
  late Stream<List<RentalPost>> _postsStream;

  bool get _isLandlord => widget.role == 'landlord';
  bool get _isAdmin => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant PostsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _selectedTab = 0;
      _subscribe();
    }
  }

  void _subscribe() {
    _postsStream = _service.watchPosts(role: widget.role, tab: _selectedTab);
  }

  void _changeTab(int index) {
    if (_busy) return;
    setState(() {
      _selectedTab = index;
      _subscribe();
    });
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _openForm([RentalPost? post]) async {
    if (_busy) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PostFormPage(post: post)),
    );
    if (!mounted || saved != true) return;
    _changeTab(1);
    _notify('Đã lưu bài đăng. Bài đang chờ admin duyệt.');
  }

  void _showDetails(RentalPost post) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PostDetailsPage(
          postId: post.id,
          service: _service,
          role: widget.role,
        ),
      ),
    );
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _notify(successMessage);
    } catch (error) {
      if (!mounted) return;
      _notify(PostService.errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _ownerAction(String action, RentalPost post) async {
    if (_busy) return;
    switch (action) {
      case 'edit':
        await _openForm(post);
        return;
      case 'available':
      case 'rented':
        if (post.availability == action) return;
        await _runAction(
          () => _service.setAvailability(post, action),
          'Đã cập nhật trạng thái phòng.',
        );
        return;
      case 'hide':
        await _runAction(
          () => _service.setHidden(post, !post.isHidden),
          post.isHidden
              ? 'Đã bỏ ẩn bài. Bài sẽ công khai khi được duyệt.'
              : 'Đã ẩn bài đăng.',
        );
        return;
      case 'delete':
        final confirmed = await _confirm(
          'Xóa bài đăng?',
          'Xóa bài "${post.title}"? Thao tác này không thể hoàn tác.',
        );
        if (!mounted || !confirmed) return;
        await _runAction(
          () => _service.deletePost(post),
          'Đã xóa bài đăng.',
        );
        return;
    }
  }

  Future<void> _review(RentalPost post, String decision) async {
    if (_busy) return;
    final updatedAt = post.updatedAt;
    if (updatedAt == null) {
      _notify('Bài chưa có thời gian cập nhật hợp lệ. Hãy tải lại.');
      return;
    }
    final approving = decision == 'approved';
    final confirmed = await _confirm(
      approving ? 'Duyệt bài đăng?' : 'Từ chối bài đăng?',
      '${post.title}\n\n'
      '${post.address}\n'
      '${formatRent(post.price)} VNĐ/tháng\n\n'
      'Bạn đã kiểm tra nội dung và hình ảnh của bài này?',
    );
    if (!mounted || !confirmed) return;
    await _runAction(
      () => _service.reviewPost(
        postId: post.id,
        decision: decision,
        expectedUpdatedAt: updatedAt,
      ),
      approving ? 'Đã duyệt bài đăng.' : 'Đã từ chối bài đăng.',
    );
  }

  Widget _postCard(RentalPost post) {
    final colors = Theme.of(context).colorScheme;
    final mine = _isLandlord &&
        post.ownerId == FirebaseAuth.instance.currentUser?.uid;
    return Card(
      key: ValueKey(post.id),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: const Color(0xffedf1f5),
            child: InkWell(
              onTap: post.imageUrls.isEmpty
                  ? null : () => showPostImages(context, post.imageUrls),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      if (post.imageUrls.isNotEmpty)
                        PostImage(
                          source: post.imageUrls.first,
                          height: constraints.maxHeight,
                          fit: BoxFit.contain,
                        )
                      else
                        const Center(
                          child: Icon(Icons.image_not_supported_outlined, size: 40),
                        ),
                      if (post.imageUrls.isNotEmpty)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library_outlined,
                                      size: 15, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text('${post.imageUrls.length}',
                                      style: const TextStyle(color: Colors.white)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.open_in_full,
                                      size: 15, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () => _showDetails(post),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            post.title.isEmpty ? 'Bài chưa có tiêu đề' : post.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700, height: 1.3,
                            ),
                          ),
                        ),
                      ),
                      if (mine)
                        PopupMenuButton<String>(
                          enabled: !_busy,
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          tooltip: 'Quản lý bài đăng',
                          onSelected: (action) => _ownerAction(action, post),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Sửa bài')),
                            const PopupMenuItem(
                              value: 'available', child: Text('Đánh dấu còn phòng'),
                            ),
                            const PopupMenuItem(
                              value: 'rented', child: Text('Đánh dấu đã cho thuê'),
                            ),
                            PopupMenuItem(
                              value: 'hide', child: Text(post.isHidden ? 'Hiện bài' : 'Ẩn bài'),
                            ),
                            const PopupMenuItem(value: 'delete', child: Text('Xóa bài')),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${formatRent(post.price)} đ/tháng',
                        style: TextStyle(color: colors.primary,
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text('${numberForInput(post.area)} m²',
                          style: TextStyle(color: colors.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusTag(
                        text: post.availabilityLabel,
                        color: post.availability == 'available'
                            ? const Color(0xff18734a) : const Color(0xff5a6472),
                      ),
                      if (mine || _isAdmin)
                        _StatusTag(
                          text: post.reviewLabel,
                          color: post.reviewStatus == 'pending'
                              ? const Color(0xff9b6500)
                              : post.reviewStatus == 'approved'
                                  ? const Color(0xff2165b0) : const Color(0xffae3544),
                        ),
                      if (post.isHidden)
                        const _StatusTag(text: 'Đang ẩn', color: Color(0xff5a6472)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showDetails(post),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Xem chi tiết'),
              ),
            ),
          ),
          if (_isAdmin && post.reviewStatus == 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _review(post, 'approved'),
                      child: const Text('Duyệt bài', textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _review(post, 'rejected'),
                      child: const Text('Từ chối', textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _postList(List<RentalPost> posts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth > 1180
            ? 1180.0 : constraints.maxWidth;
        final columns = contentWidth >= 1050 ? 3 : contentWidth >= 680 ? 2 : 1;
        final side = (constraints.maxWidth - contentWidth) / 2 + 16;
        final rowCount = (posts.length + columns - 1) ~/ columns;
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(side, 16, side, 100),
          itemCount: rowCount,
          separatorBuilder: (_, index) => const SizedBox(height: 16),
          itemBuilder: (context, row) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 16),
                Expanded(
                  child: row * columns + column < posts.length
                      ? _postCard(posts[row * columns + column])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(
        title: const Text('Bài đăng cho thuê trọ'),
        actions: [
          IconButton(
            tooltip: 'Tải lại danh sách',
            onPressed: _busy ? null : () => setState(_subscribe),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<RentalPost>>(
              stream: _postsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(
                        PostService.errorText(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = snapshot.data!;
                if (posts.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedTab == 1 && _isAdmin
                          ? 'Không có bài đang chờ duyệt.'
                          : 'Chưa có bài đăng.',
                    ),
                  );
                }
                return _postList(posts);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isLandlord
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm bài'),
            )
          : null,
      bottomNavigationBar: _isLandlord || _isAdmin
          ? NavigationBar(
              height: 68,
              selectedIndex: _selectedTab,
              onDestinationSelected: _busy ? null : _changeTab,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Bài công khai',
                ),
                NavigationDestination(
                  icon: Icon(_isLandlord ? Icons.article : Icons.fact_check),
                  label: _isLandlord ? 'Bài của tôi' : 'Chờ duyệt',
                ),
              ],
            )
          : null,
    );
  }
}

class _PostDetailsPage extends StatefulWidget {
  final String postId;
  final PostService service;
  final String role;
  const _PostDetailsPage({
    required this.postId,
    required this.service,
    required this.role,
  });

  @override
  State<_PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<_PostDetailsPage> {
  late final Stream<RentalPost?> _stream;
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.service.watchPost(widget.postId);
  }

  Future<void> _reviewFromDetails(RentalPost post, String decision) async {
    if (_reviewing || widget.role != 'admin' || post.reviewStatus != 'pending') {
      return;
    }
    final updatedAt = post.updatedAt;
    if (updatedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bài chưa cập nhật xong. Hãy thử lại.')),
      );
      return;
    }

    final approving = decision == 'approved';
    setState(() => _reviewing = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(approving ? 'Duyệt bài đăng?' : 'Từ chối bài đăng?'),
          content: Text(
            '${post.title}\n\n'
            '${approving ? 'Duyệt' : 'Từ chối'} nội dung bạn vừa xem?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;

      await widget.service.reviewPost(
        postId: post.id,
        decision: decision,
        expectedUpdatedAt: updatedAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approving ? 'Đã duyệt bài đăng.' : 'Đã từ chối bài đăng.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PostService.errorText(error)),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Widget _reviewBar(RentalPost post) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_reviewing) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _reviewing
                            ? null
                            : () => _reviewFromDetails(post, 'approved'),
                        icon: const Icon(Icons.check),
                        label: const Text('Duyệt bài'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reviewing
                            ? null
                            : () => _reviewFromDetails(post, 'rejected'),
                        icon: const Icon(Icons.close),
                        label: const Text('Từ chối'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SelectableText(
        '$label: ${value.isEmpty ? 'Chưa cập nhật' : value}',
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }

  Widget _detailsInfo(RentalPost post) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          post.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
        ),
        const SizedBox(height: 12),
        SelectableText(
          '${formatRent(post.price)} đ/tháng',
          style: TextStyle(color: colors.primary, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _StatusTag(text: post.availabilityLabel,
                color: post.availability == 'available'
                    ? const Color(0xff18734a) : const Color(0xff5a6472)),
            _StatusTag(text: post.reviewLabel,
                color: post.reviewStatus == 'pending'
                    ? const Color(0xff9b6500)
                    : post.reviewStatus == 'approved'
                        ? const Color(0xff2165b0) : const Color(0xffae3544)),
            if (post.isHidden)
              const _StatusTag(text: 'Đang ẩn', color: Color(0xff5a6472)),
          ],
        ),
        const SizedBox(height: 20),
        _line('Địa chỉ', post.address),
        _line('Diện tích', '${numberForInput(post.area)} m²'),
        const Divider(height: 24),
        _line('Tiện ích', post.amenities),
        _line('Liên hệ', post.contact),
      ],
    );
  }

  Widget _detailsBody(RentalPost post) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 820) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: PostGallery(sources: post.imageUrls)),
                      const SizedBox(width: 28),
                      Expanded(flex: 5, child: _detailsInfo(post)),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PostGallery(sources: post.imageUrls),
                    const SizedBox(height: 24),
                    _detailsInfo(post),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RentalPost?>(
      stream: _stream,
      builder: (context, snapshot) {
        final post = snapshot.hasError ? null : snapshot.data;
        Widget body;
        if (snapshot.hasError) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(PostService.errorText(snapshot.error!)),
            ),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          body = const Center(child: CircularProgressIndicator());
        } else if (post == null) {
          body = const Center(child: Text('Bài đăng không còn tồn tại.'));
        } else {
          body = _detailsBody(post);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Chi tiết bài đăng')),
          body: body,
          bottomNavigationBar: widget.role == 'admin' &&
                  post != null &&
                  post.reviewStatus == 'pending'
              ? _reviewBar(post)
              : null,
        );
      },
    );
  }
}


class _StatusTag extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(text, style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }
}
