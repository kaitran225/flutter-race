class User {
  final String username;
  final double balance;

  const User({required this.username, required this.balance});

  User copyWith({String? username, double? balance}) => User(
        username: username ?? this.username,
        balance: balance ?? this.balance,
      );

  @override
  String toString() => 'User($username, $balance)';
}
