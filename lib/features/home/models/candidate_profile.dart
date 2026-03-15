class UserPreferences {
  final List<String> interests;
  final List<String> jobAreas;
  final String employmentType; // e.g., 'Full-time', 'Part-time', 'Freelance'
  final List<String> preferredSkills;
  final List<String> workModes;
  final List<String> companyTypes;
  final List<String> interviewFocus;

  UserPreferences({
    this.interests = const [],
    this.jobAreas = const [],
    this.employmentType = 'Full-time',
    this.preferredSkills = const [],
    this.workModes = const [],
    this.companyTypes = const [],
    this.interviewFocus = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'interests': interests,
      'jobAreas': jobAreas,
      'employmentType': employmentType,
      'preferredSkills': preferredSkills,
      'workModes': workModes,
      'companyTypes': companyTypes,
      'interviewFocus': interviewFocus,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      interests: List<String>.from(map['interests'] ?? []),
      jobAreas: List<String>.from(map['jobAreas'] ?? []),
      employmentType: map['employmentType'] ?? 'Full-time',
      preferredSkills: List<String>.from(map['preferredSkills'] ?? []),
      workModes: List<String>.from(map['workModes'] ?? []),
      companyTypes: List<String>.from(map['companyTypes'] ?? []),
      interviewFocus: List<String>.from(map['interviewFocus'] ?? []),
    );
  }
}

class CandidateProfile {
  final String uid;
  final String targetCompany;
  final String targetRole;
  final String experienceLevel;
  final String qualification;
  final DateTime createdAt;
  final UserPreferences? preferences;

  CandidateProfile({
    required this.uid,
    required this.targetCompany,
    required this.targetRole,
    required this.experienceLevel,
    required this.qualification,
    required this.createdAt,
    this.preferences,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'targetCompany': targetCompany,
      'targetRole': targetRole,
      'experienceLevel': experienceLevel,
      'qualification': qualification,
      'createdAt': createdAt.toIso8601String(),
      'preferences': preferences?.toMap(),
    };
  }

  factory CandidateProfile.fromMap(Map<String, dynamic> map) {
    return CandidateProfile(
      uid: map['uid'] ?? '',
      targetCompany: map['targetCompany'] ?? '',
      targetRole: map['targetRole'] ?? '',
      experienceLevel: map['experienceLevel'] ?? '',
      qualification: map['qualification'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      preferences: map['preferences'] != null ? UserPreferences.fromMap(map['preferences']) : null,
    );
  }
}
