// TODO: Implement user_model.dart
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? profilePictureUrl;
  final String gender;
  final int age;
  final double weight; // in kg

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.profilePictureUrl,
    required this.gender,
    required this.age,
    required this.weight,
  });

  // Factory constructor to create a User from JSON (for API integration later)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      profilePictureUrl: json['profilePictureUrl'],
      gender: json['gender'],
      age: json['age'],
      weight: json['weight'].toDouble(),
    );
  }

  // Method to convert User to JSON (for API integration later)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
      'gender': gender,
      'age': age,
      'weight': weight,
    };
  }
}