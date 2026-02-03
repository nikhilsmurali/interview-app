class CandidateProfile {
  final String uid;
  final String targetCompany;
  final String targetRole;
  final String experienceLevel;
  final String qualification;
  final DateTime createdAt;

  CandidateProfile({
    required this.uid,
    required this.targetCompany,
    required this.targetRole,
    required this.experienceLevel,
    required this.qualification,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'targetCompany': targetCompany,
      'targetRole': targetRole,
      'experienceLevel': experienceLevel,
      'qualification': qualification,
      'createdAt': createdAt.toIso8601String(),
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
    );
  }
}
