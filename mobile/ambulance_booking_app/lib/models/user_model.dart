class UserModel {
  final int userId;
  final String fullName;
  final String phoneNumber;
  final String? email;
  UserModel({required this.userId, required this.fullName, required this.phoneNumber, this.email});
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(userId: json['userId'], fullName: json['fullName'], phoneNumber: json['phoneNumber'], email: json['email']);
}
