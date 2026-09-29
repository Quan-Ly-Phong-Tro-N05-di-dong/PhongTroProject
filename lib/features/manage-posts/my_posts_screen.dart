import 'package:flutter/material.dart';

class RentalPost {
  final int id;
  String title;
  String address;
  int price;
  int area;
  String description;
  String status;
  int views;
  int contacts;

  RentalPost({
    required this.id,
    required this.title,
    required this.address,
    required this.price,
    required this.area,
    required this.description,
    this.status = 'Hiển thị',
    this.views = 0,
    this.contacts = 0,
  });
}

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final List<RentalPost> _posts = [
    RentalPost(
      id: 1,
      title: 'Phòng trọ cao cấp có ban công, full nội thất',
      address: '45 Nguyễn Thị Minh Khai, Quận 1',
      price: 4500000,
      area: 28,
      description: 'Phòng có ban công, điều hòa, giường và tủ quần áo.',
      views: 312,
      contacts: 18,
    ),
    RentalPost(
      id: 2,
      title: 'Phòng trọ gần ĐH Bách Khoa, an ninh tốt',
      address: '12 Lý Thường Kiệt, Quận 10',
      price: 3200000,
      area: 22,
      description: 'Phòng thoáng mát, giờ giấc tự do, có chỗ để xe.',
      views: 198,
      contacts: 11,
    ),
  ];

  String _keyword = '';
  String _filter = 'Tất cả';
  int _nextId = 3;

  String _formatPrice(int price) {
    final text = price.toString();
    return text.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  List<RentalPost> get _visiblePosts {
    return _posts.where((post) {
      final matchesFilter = _filter == 'Tất cả' || post.status == _filter;
      final keyword = _keyword.trim().toLowerCase();
      final matchesKeyword =
          post.title.toLowerCase().contains(keyword) ||
          post.address.toLowerCase().contains(keyword);
      return matchesFilter && matchesKeyword;
    }).toList();
  }

  Future<void> _openForm({RentalPost? post}) async {
    final result = await Navigator.push<RentalPost>(
      context,
      MaterialPageRoute(
        builder: (_) => PostFormScreen(post: post, nextId: _nextId),
      ),
    );

    if (result == null) return;

    setState(() {
      if (post == null) {
        _posts.insert(0, result);
        _nextId++;
      } else {
        final index = _posts.indexWhere((item) => item.id == post.id);
        if (index != -1) _posts[index] = result;
      }
    });
  }

  void _openDetail(RentalPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          post: post,
          onEdit: () async {
            Navigator.pop(context);
            await _openForm(post: post);
          },
        ),
      ),
    );
  }

  void _openStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostStatisticsScreen(posts: _posts),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = _visiblePosts;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Bài đăng của tôi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Thống kê',
            onPressed: _openStatistics,
            icon: const Icon(Icons.bar_chart_outlined),
          ),
          IconButton(
            tooltip: 'Tạo bài đăng',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _summaryCard('Tổng', _posts.length, const Color(0xFFEAF0F8)),
                _summaryCard(
                  'Hiển thị',
                  _posts.where((post) => post.status == 'Hiển thị').length,
                  const Color(0xFFE3F8EF),
                ),
                _summaryCard(
                  'Chờ duyệt',
                  _posts.where((post) => post.status == 'Chờ duyệt').length,
                  const Color(0xFFFFF5DF),
                ),
                _summaryCard(
                  'Hết hạn',
                  _posts.where((post) => post.status == 'Hết hạn').length,
                  const Color(0xFFFFECEC),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) => setState(() => _keyword = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm theo tiêu đề, khu vực...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['Tất cả', 'Hiển thị', 'Chờ duyệt', 'Hết hạn']
                  .map(
                    (status) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: _filter == status,
                        onSelected: (_) =>
                            setState(() => _filter = status),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: visiblePosts.isEmpty
                ? const Center(child: Text('Không có bài đăng phù hợp'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visiblePosts.length,
                    itemBuilder: (context, index) {
                      final post = visiblePosts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openDetail(post),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 130,
                                width: double.infinity,
                                color: const Color(0xFFDDEBE9),
                                child: const Icon(
                                  Icons.home_outlined,
                                  size: 58,
                                  color: Color(0xFF008F83),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      post.address,
                                      style: const TextStyle(
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_formatPrice(post.price)} đ/tháng  •  ${post.area} m²',
                                      style: const TextStyle(
                                        color: Color(0xFF008F83),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text('👁 ${post.views}'),
                                        const SizedBox(width: 14),
                                        Text('☎ ${post.contacts}'),
                                        const Spacer(),
                                        Text(post.status),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _summaryCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class PostFormScreen extends StatefulWidget {
  final RentalPost? post;
  final int nextId;

  const PostFormScreen({
    super.key,
    this.post,
    required this.nextId,
  });

  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _address;
  late final TextEditingController _price;
  late final TextEditingController _area;
  late final TextEditingController _description;
  late String _status;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _title = TextEditingController(text: post?.title ?? '');
    _address = TextEditingController(text: post?.address ?? '');
    _price = TextEditingController(text: post?.price.toString() ?? '');
    _area = TextEditingController(text: post?.area.toString() ?? '');
    _description = TextEditingController(text: post?.description ?? '');
    _status = post?.status ?? 'Hiển thị';
  }

  @override
  void dispose() {
    _title.dispose();
    _address.dispose();
    _price.dispose();
    _area.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final result = RentalPost(
      id: widget.post?.id ?? widget.nextId,
      title: _title.text.trim(),
      address: _address.text.trim(),
      price: int.parse(_price.text.trim()),
      area: int.parse(_area.text.trim()),
      description: _description.text.trim(),
      status: _status,
      views: widget.post?.views ?? 0,
      contacts: widget.post?.contacts ?? 0,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.post != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa bài đăng' : 'Tạo bài đăng'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _textField(_title, 'Tiêu đề'),
            _textField(_address, 'Địa chỉ'),
            _textField(_price, 'Giá thuê (đồng)', numeric: true),
            _textField(_area, 'Diện tích (m²)', numeric: true),
            _textField(_description, 'Mô tả', maxLines: 4),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: ['Hiển thị', 'Chờ duyệt', 'Hết hạn']
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isEditing ? 'Lưu thay đổi' : 'Đăng bài'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Vui lòng nhập $label';
          }
          if (numeric) {
            final number = int.tryParse(value.trim());
            if (number == null || number <= 0) {
              return 'Vui lòng nhập số lớn hơn 0';
            }
          }
          return null;
        },
      ),
    );
  }
}

class PostDetailScreen extends StatelessWidget {
  final RentalPost post;
  final VoidCallback onEdit;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết bài đăng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 180,
            color: const Color(0xFFDDEBE9),
            child: const Icon(
              Icons.home_outlined,
              size: 80,
              color: Color(0xFF008F83),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            post.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          Text('Địa chỉ: ${post.address}'),
          Text('Giá thuê: ${post.price} đ/tháng'),
          Text('Diện tích: ${post.area} m²'),
          Text('Trạng thái: ${post.status}'),
          const SizedBox(height: 14),
          const Text(
            'Mô tả',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(post.description),
          const SizedBox(height: 14),
          Text('Lượt xem: ${post.views}'),
          Text('Lượt liên hệ: ${post.contacts}'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
            label: const Text('Sửa bài đăng'),
          ),
        ],
      ),
    );
  }
}

class PostStatisticsScreen extends StatelessWidget {
  final List<RentalPost> posts;

  const PostStatisticsScreen({
    super.key,
    required this.posts,
  });

  @override
  Widget build(BuildContext context) {
    final totalViews = posts.fold<int>(
      0,
      (sum, post) => sum + post.views,
    );
    final totalContacts = posts.fold<int>(
      0,
      (sum, post) => sum + post.contacts,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê bài đăng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Tổng bài đăng'),
              trailing: Text('${posts.length}'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Tổng lượt xem'),
              trailing: Text('$totalViews'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Tổng lượt liên hệ'),
              trailing: Text('$totalContacts'),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Theo từng bài đăng',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...posts.map(
            (post) => Card(
              child: ListTile(
                title: Text(post.title),
                subtitle: Text(
                  '${post.views} lượt xem • ${post.contacts} lượt liên hệ',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}