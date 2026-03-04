import '../models/user_model.dart';

class UserRepository {
  // This simulates saving user data to a database or API
  Future<void> saveUser(UserModel user) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    print("Saving user: ${user.name} to database...");
    // In a real app, you would make an API call here:
    // await _api.post('/users', data: user.toJson());
  }

  // This simulates fetching user data
  Future<UserModel?> getUser(String userId) async {
    await Future.delayed(const Duration(seconds: 1));
    // Simulate retrieving data
    return null; // Return null if user not found
  }
}
