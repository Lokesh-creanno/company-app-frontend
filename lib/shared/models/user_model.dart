class UserModel {
  final String id;
  final String employeeId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String role;
  final String? department;
  final String? designation;
  final String? profilePhoto;
  final String? joiningDate;
  final DateTime? lastLogin;

  const UserModel({
    required this.id,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.role,
    this.department,
    this.designation,
    this.profilePhoto,
    this.joiningDate,
    this.lastLogin,
  });

  String get fullName => '$firstName $lastName';
  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager' || role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    employeeId: json['employeeId'],
    firstName: json['firstName'],
    lastName: json['lastName'],
    email: json['email'],
    phone: json['phone'],
    role: json['role'],
    department: json['department'],
    designation: json['designation'],
    profilePhoto: json['profilePhoto'],
    joiningDate: json['joiningDate'],
    lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'employeeId': employeeId, 'firstName': firstName,
    'lastName': lastName, 'email': email, 'phone': phone,
    'role': role, 'department': department, 'designation': designation,
    'profilePhoto': profilePhoto, 'joiningDate': joiningDate,
  };
}
