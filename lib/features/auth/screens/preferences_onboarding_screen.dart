import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/home/models/candidate_profile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PreferencesOnboardingScreen extends StatefulWidget {
  final bool isEditing;
  const PreferencesOnboardingScreen({super.key, this.isEditing = false});

  @override
  State<PreferencesOnboardingScreen> createState() => _PreferencesOnboardingScreenState();
}

class _PreferencesOnboardingScreenState extends State<PreferencesOnboardingScreen> {
  final List<String> _interests = ['Mobile Development', 'Frontend', 'Backend', 'AI/ML', 'Cloud Computing', 'Cybersecurity', 'Design', 'Data Science'];
  final List<String> _selectedInterests = [];

  final List<String> _jobAreas = ['Software Engineering', 'Product Management', 'UI/UX Design', 'Data Engineering', 'DevOps', 'QA Testing'];
  final List<String> _selectedJobAreas = [];

  final List<String> _employmentTypes = ['Full-time', 'Part-time', 'Freelance', 'Internship'];
  String _selectedEmploymentType = 'Full-time';

  final List<String> _workModes = ['Remote', 'Hybrid', 'On-site'];
  final List<String> _selectedWorkModes = [];

  final List<String> _companyTypes = ['Big Tech', 'Unicorn / Scale-up', 'Early Startup', 'Agency', 'Public Sector'];
  final List<String> _selectedCompanyTypes = [];

  final List<String> _interviewFocus = ['Technical', 'System Design', 'Behavioral / HR', 'Managerial'];
  final List<String> _selectedInterviewFocus = [];

  final TextEditingController _skillsController = TextEditingController();
  final List<String> _skills = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingPreferences();
    }
  }

  Future<void> _loadExistingPreferences() async {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user != null) {
      final profile = await FirestoreService().getProfile(user.uid);
      if (profile != null && profile.preferences != null) {
        setState(() {
          _selectedInterests.addAll(profile.preferences!.interests);
          _selectedJobAreas.addAll(profile.preferences!.jobAreas);
          _selectedEmploymentType = profile.preferences!.employmentType;
          _skills.addAll(profile.preferences!.preferredSkills);
          _selectedWorkModes.addAll(profile.preferences!.workModes);
          _selectedCompanyTypes.addAll(profile.preferences!.companyTypes);
          _selectedInterviewFocus.addAll(profile.preferences!.interviewFocus);
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).user;
      if (user != null) {
        final existingProfile = await FirestoreService().getProfile(user.uid);
        
        final updatedPreferences = UserPreferences(
          interests: _selectedInterests,
          jobAreas: _selectedJobAreas,
          employmentType: _selectedEmploymentType,
          preferredSkills: _skills,
          workModes: _selectedWorkModes,
          companyTypes: _selectedCompanyTypes,
          interviewFocus: _selectedInterviewFocus,
        );

        final updatedProfile = CandidateProfile(
          uid: user.uid,
          targetCompany: existingProfile?.targetCompany ?? '',
          targetRole: existingProfile?.targetRole ?? '',
          experienceLevel: existingProfile?.experienceLevel ?? 'Junior',
          qualification: existingProfile?.qualification ?? 'Bachelor\'s',
          createdAt: existingProfile?.createdAt ?? DateTime.now(),
          preferences: updatedPreferences,
        );

        await FirestoreService().saveProfile(updatedProfile);
        
        if (mounted) {
          if (widget.isEditing) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving preferences: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Preferences' : 'Your Preferences'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isEditing) ...[
              Text(
                'Help us personalize your experience!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ll use this to tailor your "For You" feed and interview questions.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 32),
            ],

            _buildSectionTitle('Scope of Interest'),
            const SizedBox(height: 12),
            _buildChoiceChips(_interests, _selectedInterests),

            const SizedBox(height: 32),
            _buildSectionTitle('Preferred Job Areas'),
            const SizedBox(height: 12),
            _buildChoiceChips(_jobAreas, _selectedJobAreas),

            const SizedBox(height: 32),
            _buildSectionTitle('Interview Focus Areas'),
            const SizedBox(height: 12),
            _buildChoiceChips(_interviewFocus, _selectedInterviewFocus),

            const SizedBox(height: 32),
            _buildSectionTitle('Employment Type'),
            const SizedBox(height: 12),
            _buildDropdown(),

            const SizedBox(height: 32),
            _buildSectionTitle('Work Mode'),
            const SizedBox(height: 12),
            _buildChoiceChips(_workModes, _selectedWorkModes),

            const SizedBox(height: 32),
            _buildSectionTitle('Target Company Type'),
            const SizedBox(height: 12),
            _buildChoiceChips(_companyTypes, _selectedCompanyTypes),

            const SizedBox(height: 32),
            _buildSectionTitle('Skills you want to focus on'),
            const SizedBox(height: 12),
            _buildSkillsInput(),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                    ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                    : Text(widget.isEditing ? 'Save Changes' : 'Continue to Home'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildChoiceChips(List<String> options, List<String> selectedList) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedList.contains(option);
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                selectedList.add(option);
              } else {
                selectedList.remove(option);
              }
            });
          },
          selectedColor: const Color(0xFFFF5A00).withOpacity(0.2),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFFFF5A00) : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? const Color(0xFFFF5A00) : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedEmploymentType,
          isExpanded: true,
          dropdownColor: Theme.of(context).colorScheme.surface,
          items: _employmentTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedEmploymentType = val);
          },
        ),
      ),
    );
  }

  Widget _buildSkillsInput() {
    return Column(
      children: [
        TextField(
          controller: _skillsController,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Add a skill (e.g. Flutter, React, AWS)',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFFFF5A00)),
              onPressed: () {
                if (_skillsController.text.isNotEmpty) {
                  setState(() {
                    _skills.add(_skillsController.text.trim());
                    _skillsController.clear();
                  });
                }
              },
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onSubmitted: (val) {
            if (val.isNotEmpty) {
              setState(() {
                _skills.add(val.trim());
                _skillsController.clear();
              });
            }
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _skills.map((skill) {
            return Chip(
              label: Text(skill),
              onDeleted: () => setState(() => _skills.remove(skill)),
              deleteIconColor: Colors.redAccent,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            );
          }).toList(),
        ),
      ],
    );
  }
}
