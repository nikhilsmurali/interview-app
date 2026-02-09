class Member {
  final String id;
  final String name;
  final String avatarUrl;
  final String? gitUrl;
  final String? linkedInUrl;
  final String role; // 'Admin', 'Member', etc.

  const Member({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.gitUrl,
    this.linkedInUrl,
    this.role = 'Member',
  });
}

class Community {
  final String id;
  final String name;
  final String description;
  final List<String> tags;
  final int memberCount;
  final List<Member> members;
  bool isJoined;

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    required this.memberCount,
    required this.members,
    this.isJoined = false,
  });
}
