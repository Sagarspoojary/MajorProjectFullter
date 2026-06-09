import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String profileImage;
  final String provider;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String accountStatus; // e.g. "active", "suspended"
  final String role; // e.g. "user", "admin"

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.profileImage,
    required this.provider,
    required this.createdAt,
    required this.lastLogin,
    required this.accountStatus,
    required this.role,
  });

  // copyWith method
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? profileImage,
    String? provider,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? accountStatus,
    String? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      accountStatus: accountStatus ?? this.accountStatus,
      role: role ?? this.role,
    );
  }

  // toMap for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'profileImage': profileImage,
      'provider': provider,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': Timestamp.fromDate(lastLogin),
      'accountStatus': accountStatus,
      'role': role,
    };
  }

  // fromMap from Firestore
  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else {
        return DateTime.now();
      }
    }

    return UserModel(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      profileImage: map['profileImage'] ?? '',
      provider: map['provider'] ?? 'email',
      createdAt: parseDateTime(map['createdAt']),
      lastLogin: parseDateTime(map['lastLogin']),
      accountStatus: map['accountStatus'] ?? 'active',
      role: map['role'] ?? 'user',
    );
  }

  // Helper method for empty user
  factory UserModel.empty() {
    return UserModel(
      uid: '',
      fullName: '',
      email: '',
      profileImage: '',
      provider: 'email',
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      accountStatus: 'active',
      role: 'user',
    );
  }
}
