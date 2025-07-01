// lib/model/user.dart

class User {
  final String token;
  final int userId;
  final String mobileMask;

  User({required this.token, required this.userId, required this.mobileMask});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      token: json['token'],
      userId: json['hxUser']['id'],
      mobileMask: json['hxUser']['mobile'],
    );
  }

  // 新增序列化方法
  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'mobileMask': mobileMask,
  };
}
