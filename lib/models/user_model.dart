class UserModel {
  final int? id;
  final String? username;
  final String? name;
  final String? email;
  final String? token;
  final String? password;
  final String? googleId;
  final String loginMethod;

  UserModel({
    this.id,
    this.username,
    this.name,
    this.email,
    this.token,
    this.password,
    this.googleId,
    required this.loginMethod,
  });

  // From API JSON
  factory UserModel.fromJson(Map<String, dynamic> json, String method,
      {String? token, String? password}) {
    final user = json['user'];
    return UserModel(
      id: user['id'],
      username: user['username'],
      name: user['name'],
      email: user['email'],
      googleId: user['google_id'],
      token: token ?? json['token'], // Use provided token or extract from JSON
      password: password,
      loginMethod: method,
    );
  }

  // From Local SQLite
  factory UserModel.fromDb(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      username: map['username'],
      name: map['name'],
      email: map['email'],
      token: map['token'],
      password: map['password'],
      googleId: map['google_id'],
      loginMethod: map['login_method'] ?? 'manual',
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'token': token,
      'password': password,
      'google_id': googleId,
      'login_method': loginMethod,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // Added copyWith for immutability updates
  UserModel copyWith({
    int? id,
    String? username,
    String? name,
    String? email,
    String? token,
    String? password,
    String? googleId,
    String? loginMethod,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      token: token ?? this.token,
      password: password ?? this.password,
      googleId: googleId ?? this.googleId,
      loginMethod: loginMethod ?? this.loginMethod,
    );
  }
}
