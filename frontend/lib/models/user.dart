class User {
  final String name;
  final String? lastName;
  final String? photoUrl;
  final String? location;

  User({required this.name, this.lastName, this.photoUrl, this.location});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] as String? ?? '',
      lastName: json['last_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      location: json['location'] as String?,
    );
  }
}
