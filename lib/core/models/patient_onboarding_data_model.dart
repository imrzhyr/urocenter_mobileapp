class PatientOnboardingData {
  final String userId;
  final String name; // Assuming name comes from auth/previous step
  final String? profilePictureUrl; // RE-ADDED
  final int? age; // From ProfileSetup
  final String? gender; // From ProfileSetup
  final String? height; // ADDED
  final String? weight; // ADDED
  final String? country; // ADDED
  final String? city; // ADDED
  // Height/Weight/Location skipped for brevity in intro card, but could be added
  final List<String> conditions; // Selected checkboxes from MedicalHistory
  final String? otherConditions; // Text field from MedicalHistory
  final String? medications; // Text field or indication of None/Uploaded from MedicalHistory
  final String? allergies; // Text field or indication of None from MedicalHistory
  final String? surgicalHistory; // Text field or indication of None from MedicalHistory
  final List<Map<String, String>> documents; // From DocumentUpload

  PatientOnboardingData({
    required this.userId,
    required this.name,
    this.profilePictureUrl, // RE-ADDED
    this.age,
    this.gender,
    this.height, // ADDED
    this.weight, // ADDED
    this.country, // ADDED
    this.city, // ADDED
    this.conditions = const [],
    this.otherConditions,
    this.medications,
    this.allergies,
    this.surgicalHistory,
    this.documents = const [],
  });
} 