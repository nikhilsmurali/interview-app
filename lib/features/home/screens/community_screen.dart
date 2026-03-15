import 'dart:convert';
import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/home/models/candidate_profile.dart';
import 'package:ai_interviewer/features/home/models/community_model.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  
  // Mock Data
  final List<Community> _allCommunities = [
    Community(
      id: '1',
      name: 'Flutter Devs',
      description: 'A place for all things Flutter. Share your apps, ask questions, and grow together!',
      tags: ['#flutter', '#dart', '#mobile'],
      memberCount: 1250,
      members: [],
    ),
    Community(
      id: '2',
      name: 'AI Enthusiasts',
      description: 'Discussing the latest in LLMs, GenAI, and machine learning.',
      tags: ['#ai', '#ml', '#genai'],
      memberCount: 890,
      members: [],
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
  
  bool _isLoadingGlobal = true;
  List<dynamic> _techNews = [];
  List<dynamic> _jobNews = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Re-render to show/hide FAB based on index
    });
    _filteredCommunities = _allCommunities;
    _searchController.addListener(_onSearchChanged);
    
    _fetchGlobalData();
    _loadUserPreferences();
  }

  UserPreferences? _userPrefs;
  bool _isLoadingPrefs = true;

  Future<void> _loadUserPreferences() async {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user != null) {
      final profile = await FirestoreService().getProfile(user.uid);
      if (mounted) {
        setState(() {
          _userPrefs = profile?.preferences;
          _isLoadingPrefs = false;
        });
      }
    }
  }

  Future<void> _fetchGlobalData() async {
    const String apiKey = 'pub_11efeff7a6bf426ca9373be97da2e182';
    try {
      // Fetch Tech News
      final newsRes = await http.get(Uri.parse('https://newsdata.io/api/1/news?apikey=$apiKey&q=tech&language=en'));
      if (newsRes.statusCode == 200) {
        final data = jsonDecode(newsRes.body);
        if (data['results'] != null) {
          _techNews = (data['results'] as List).take(5).toList();
        }
      }

      // Fetch Job related News
      final jobsRes = await http.get(Uri.parse('https://newsdata.io/api/1/news?apikey=$apiKey&q=tech AND (hiring OR jobs)&language=en'));
      if (jobsRes.statusCode == 200) {
        final data = jsonDecode(jobsRes.body);
        if (data['results'] != null) {
          _jobNews = (data['results'] as List).take(5).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching global data: $e");
    } finally {
      if (mounted) setState(() => _isLoadingGlobal = false);
    }
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
    _tabController.dispose();
    super.dispose();
  }

  void _joinCommunity(Community community) {
    setState(() {
      community.isJoined = !community.isJoined;
      
      final user = Provider.of<AuthService>(context, listen: false).user;
      if (user != null) {
        if (community.isJoined) {
          // Add current user to members
          community.members.add(Member(
            id: user.uid,
            name: user.displayName ?? 'User',
            avatarUrl: user.photoURL ?? '',
            role: 'Member',
          ));
        } else {
          // Remove current user from members
          community.members.removeWhere((m) => m.id == user.uid);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(community.isJoined ? 'Joined ${community.name}' : 'Left ${community.name}')),
    );
  }

  void _showMembersAPI(Community community) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: community.members.length,
                  separatorBuilder: (c, i) => Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                  itemBuilder: (context, index) {
                    final member = community.members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Text(member.name[0], style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(member.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      subtitle: Text(member.role, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (member.gitUrl != null)
                            IconButton(
                              icon: FaIcon(FontAwesomeIcons.github, color: Theme.of(context).colorScheme.onSurface, size: 20),
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

  void _showCreateCommunityDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Create Community', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Community Name',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A00)),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  final newCommunity = Community(
                    id: DateTime.now().toString(),
                    name: nameController.text,
                    description: descController.text,
                    tags: ['#new'],
                    memberCount: 1,
                    members: [],
                    isJoined: true,
                  );
                  _allCommunities.add(newCommunity);
                  _onSearchChanged(); // Refresh list
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Community Created!')),
                );
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Column(
          children: [
          // 1. Search & Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Explore Communities & News...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              labelColor: const Color(0xFFFF5A00),
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  height: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 24),
                      SizedBox(height: 4),
                      Text('For You', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  height: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.language_rounded, size: 24),
                      SizedBox(height: 4),
                      Text('Global', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  height: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_rounded, size: 24),
                      SizedBox(height: 4),
                      Text('People', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // FOR YOU TAB
                _buildForYouTab(),

                // GLOBAL TAB
                _buildGlobalTab(),

                // PEOPLE TAB (Original Content)
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _filteredCommunities.length,
                  itemBuilder: (context, index) {
                    final community = _filteredCommunities[index];
                    return _buildCommunityCard(community);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      if (_tabController.index == 2)
        Positioned(
          right: 16,
          bottom: 100, // Above the floating navbar area
          child: FloatingActionButton.extended(
            onPressed: _showCreateCommunityDialog,
            backgroundColor: isDark ? Colors.white : Colors.black,
            icon: Icon(Icons.add, color: isDark ? const Color(0xFFFF5A00) : Colors.white),
            label: Text("Create Community", style: TextStyle(color: isDark ? const Color(0xFFFF5A00) : Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalTab() {
    if (_isLoadingGlobal) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A00)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(
          'Latest Tech News',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_techNews.isEmpty)
          const Text("No news available at the moment.", style: TextStyle(color: Colors.white54)),
        ..._techNews.map((news) => _buildNewsCard(
          title: news['title'] ?? 'No Title',
          date: news['pubDate'] ?? '',
          source: news['source_id'] ?? 'News',
          url: news['link'],
        )),
        
        const SizedBox(height: 32),
        Text(
          'Recent Job Openings',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_jobNews.isEmpty)
           const Text("No job news available at the moment.", style: TextStyle(color: Colors.white54)),
        ..._jobNews.map((job) => _buildJobCard(
          title: job['title'] ?? 'No Title',
          source: job['source_id'] ?? 'Source',
          url: job['link'],
        )),
      ],
    );
  }

  Widget _buildNewsCard({required String title, required String date, required String source, String? url}) {
    return GestureDetector(
      onTap: () {
        if (url != null) launchUrl(Uri.parse(url));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(source, style: const TextStyle(color: Color(0xFFFF5A00), fontSize: 12)),
                const Spacer(),
                Expanded(child: Text(date, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 10), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard({required String title, required String source, String? url}) {
    return GestureDetector(
      onTap: () {
        if (url != null) launchUrl(Uri.parse(url));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: const Icon(Icons.work, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(source, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }



  Widget _buildCommunityCard(Community community) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
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
                    Text(community.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${community.memberCount} members', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              if (community.isJoined)
                  IconButton(
                    icon: const Icon(Icons.people_alt, color: Colors.blueAccent),
                    onPressed: () => _showMembersAPI(community),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          Text(community.description, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
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
                backgroundColor: community.isJoined ? Colors.grey.withValues(alpha: 0.2) : const Color(0xFFFF5A00),
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

  Widget _buildForYouTab() {
    if (_isLoadingPrefs || _isLoadingGlobal) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A00)));
    }

    if (_userPrefs == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_suggest, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Finish setting up your profile", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/preferences'),
              child: const Text("Set Preferences"),
            ),
          ],
        ),
      );
    }

    // Filter news based on interests
    final preferredNews = _techNews.where((news) {
      final title = (news['title'] ?? '').toString().toLowerCase();
      return _userPrefs!.interests.any((interest) => title.contains(interest.toLowerCase()));
    }).toList();

    // Filter communities based on interests/skills
    final preferredCommunities = _allCommunities.where((c) {
      return _userPrefs!.interests.any((interest) => c.name.toLowerCase().contains(interest.toLowerCase())) ||
             _userPrefs!.preferredSkills.any((skill) => c.tags.contains('#${skill.toLowerCase()}'));
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchGlobalData();
        await _loadUserPreferences();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Color(0xFFFF5A00), size: 20),
              const SizedBox(width: 8),
              Text(
                'Top Picks for You',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (preferredNews.isEmpty && preferredCommunities.isEmpty)
             _buildEmptyForYouState(),

          if (preferredNews.isNotEmpty) ...[
            Text('Trending in ${(_userPrefs!.interests..shuffle()).firstOrNull ?? "your areas"}', 
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 8),
            ...preferredNews.take(3).map((news) => _buildNewsCard(
              title: news['title'] ?? 'No Title',
              date: news['pubDate'] ?? '',
              source: news['source_id'] ?? 'News',
              url: news['link'],
            )),
          ],

          const SizedBox(height: 24),
          if (preferredCommunities.isNotEmpty) ...[
             Text('Communities you might like', 
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
             const SizedBox(height: 8),
             ...preferredCommunities.take(2).map((c) => _buildCommunityCard(c)),
          ],

          const SizedBox(height: 24),
          Text(
            'Explore ${_userPrefs!.employmentType} Opportunities',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._jobNews.take(3).map((job) => _buildJobCard(
            title: job['title'] ?? 'No Title',
            source: job['source_id'] ?? 'Source',
            url: job['link'],
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyForYouState() {
     return Container(
       padding: const EdgeInsets.all(24),
       decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.surface,
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05)),
       ),
       child: const Column(
         children: [
           Icon(Icons.bubble_chart, size: 48, color: Colors.grey),
           SizedBox(height: 16),
           Text(
             "We're still learning your preferences. Try adding more interests in your profile!",
             textAlign: TextAlign.center,
             style: TextStyle(color: Colors.grey),
           ),
         ],
       ),
     );
  }
}
