import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// User model representing application user profile data
class User {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final bool isVerified;
  final bool onboardingCompleted;
  final String? onboardingStep;
  final bool hasPaid;
  final bool isAdmin;
  final int? age;
  final String? gender;
  final double? height;
  final double? weight;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? medicalHistory;

  User({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.isVerified = false,
    this.onboardingCompleted = false,
    this.onboardingStep,
    this.hasPaid = false,
    this.isAdmin = false,
    this.age,
    this.gender,
    this.height,
    this.weight,
    required this.createdAt,
    this.updatedAt,
    this.medicalHistory,
  });

  /// Create a copy of this User with specified fields updated
  User copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? email,
    bool? isVerified,
    bool? onboardingCompleted,
    String? onboardingStep,
    bool? hasPaid,
    bool? isAdmin,
    int? age,
    String? gender,
    double? height,
    double? weight,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? medicalHistory,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      hasPaid: hasPaid ?? this.hasPaid,
      isAdmin: isAdmin ?? this.isAdmin,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      medicalHistory: medicalHistory ?? this.medicalHistory,
    );
  }

  /// Convert User object to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'email': email,
      'isVerified': isVerified,
      'onboardingCompleted': onboardingCompleted,
      'onboardingStep': onboardingStep,
      'hasPaid': hasPaid,
      'isAdmin': isAdmin,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'medicalHistory': medicalHistory,
    };
  }

  /// Create User object from Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      isVerified: map['isVerified'] ?? false,
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      onboardingStep: map['onboardingStep'],
      hasPaid: map['hasPaid'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      age: map['age'],
      gender: map['gender'],
      height: map['height'] != null ? (map['height'] as num).toDouble() : null,
      weight: map['weight'] != null ? (map['weight'] as num).toDouble() : null,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
      medicalHistory: map['medicalHistory'],
    );
  }

  /// Convert User object to JSON string
  String toJson() => json.encode(toMap());

  /// Create User object from JSON string
  factory User.fromJson(String source) => User.fromMap(json.decode(source));

  @override
  String toString() {
    return 'User(id: $id, fullName: $fullName, phoneNumber: $phoneNumber, isVerified: $isVerified, onboardingCompleted: $onboardingCompleted, onboardingStep: $onboardingStep, isAdmin: $isAdmin)';
  }

  /// Empty user for initial state
  factory User.empty() {
    return User(
      id: '',
      fullName: '',
      phoneNumber: '',
      onboardingStep: 'profile_setup',
      createdAt: DateTime.now(),
    );
  }

  /// Check if this is an empty user
  bool get isEmpty => id.isEmpty;
} 