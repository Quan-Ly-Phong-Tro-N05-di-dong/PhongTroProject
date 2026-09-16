class User {
  final String name;
  final int age;

  const User({required this.name, required this.age});

  // Class method (Factory Constructor) tạo đối tượng từ logic cụ thể
  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      name: data['name'] as String,
      age: data['age'] as int,
    );
  }

  // Method thông thường để lấy dữ liệu dạng chuỗi
  String getInfo() => 'Tên: $name - Tuổi: $age';
}

