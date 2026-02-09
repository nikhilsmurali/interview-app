import 'package:ai_interviewer/features/home/models/community_model.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'Trending'; // 'Trending', 'People'
  
  // Mock Data
  final List<Community> _allCommunities = [
    Community(
      id: '1',
      name: 'Flutter Devs',
      description: 'A place for all things Flutter. Share your apps, ask questions, and grow together!',
      tags: ['#flutter', '#dart', '#mobile'],
      memberCount: 1250,
      members: [
        Member(id: 'm1', name: 'Alice', avatarUrl: '', gitUrl: 'https://github.com/alice', linkedInUrl: 'https://linkedin.com/in/alice', role: 'Admin'),
        Member(id: 'm2', name: 'Bob', avatarUrl: '', gitUrl: 'https://github.com/bob'),
      ],
    ),
    Community(
      id: '2',
      name: 'AI Enthusiasts',
      description: 'Discussing the latest in LLMs, GenAI, and machine learning.',
      tags: ['#ai', '#ml', '#genai'],
      memberCount: 890,
      members: [
        Member(id: 'm3', name: 'Charlie', avatarUrl: '', linkedInUrl: 'https://linkedin.com/in/charlie'),
      ],
    ),
    Community(
      id: '3',
      name: 'Crypto & Web3',
      description: 'Blockchain development, smart contracts, and the future of web3.',
      tags: ['#crypto', '#web3', '#bchain'],
      memberCount: 3400,
      members: [],
    ),
  ];

  List<Community> _filteredCommunities = [];

  @override
  void initState() {
    super.initState();
    _filteredCommunities = _allCommunities;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCommunities = _allCommunities.where((c) {
        return c.name.toLowerCase().contains(query) || 
               c.tags.any((t) => t.toLowerCase().contains(query));
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _joinCommunity(Community community) {
    setState(() {
      community.isJoined = !community.isJoined;
    });
    // In a real app, this would update backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(community.isJoined ? 'Joined ${community.name}' : 'Left ${community.name}')),
    );
  }

  void _showMembersAPI(Community community) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Members of ${community.name}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: community.members.length,
                  separatorBuilder: (c, i) => const Divider(color: Colors.white24),
                  itemBuilder: (context, index) {
                    final member = community.members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Text(member.name[0], style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(member.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(member.role, style: const TextStyle(color: Colors.white70)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (member.gitUrl != null)
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.github, color: Colors.white, size: 20),
                              onPressed: () => launchUrl(Uri.parse(member.gitUrl!)),
                            ),
                          if (member.linkedInUrl != null)
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.linkedin, color: Colors.blue, size: 20),
                              onPressed: () => launchUrl(Uri.parse(member.linkedInUrl!)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Dark background
      child: Column(
        children: [
          // 1. Search & Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Explore Communities...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),

          // 2. Tabs (Trending vs People)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  _buildTab('Trending', true),
                  _buildTab('People', false),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // 3. Trending Tags
          if (_selectedTab == 'Trending')
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildTag('#cryptogrowth'),
                  _buildTag('#HODL'),
                  _buildTag('#flutter'),
                  _buildTag('#AI'),
                  _buildTag('#jobsearch'),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // 4. Content List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredCommunities.length,
              itemBuilder: (context, index) {
                final community = _filteredCommunities[index];
                return _buildCommunityCard(community);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, bool isFirst) {
    final isSelected = _selectedTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      alignment: Alignment.center,
      child: Text(tag, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _buildCommunityCard(Community community) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orangeAccent,
                child: Text(community.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(community.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${community.memberCount} members', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              if (community.isJoined)
                 IconButton(
                   icon: const Icon(Icons.info_outline, color: Colors.white70),
                   onPressed: () => _showMembersAPI(community),
                 ),
            ],
          ),
          const SizedBox(height: 12),
          Text(community.description, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: community.tags.map((t) => Text(t, style: const TextStyle(color: Colors.blueAccent))).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _joinCommunity(community),
              style: ElevatedButton.styleFrom(
                backgroundColor: community.isJoined ? Colors.grey.withValues(alpha: 0.2) : const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(community.isJoined ? 'Joined' : 'Join Community'),
            ),
          ),
        ],
      ),
    );
  }
}
