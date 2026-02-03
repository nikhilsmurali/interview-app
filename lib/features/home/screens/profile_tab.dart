import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/auth/widgets/auth_text_field.dart';
import 'package:ai_interviewer/features/auth/widgets/primary_button.dart';
import 'package:ai_interviewer/features/home/models/candidate_profile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final TextEditingController _customCompanyController = TextEditingController();
  final TextEditingController _customRoleController = TextEditingController();
  
  String? _selectedCompany;
  String? _selectedRole;
  String? _experienceLevel;
  String? _qualification;
  bool _isLoading = false;

  final List<String> _companies = [
    'Google',
    'Microsoft',
    'Amazon',
    'Meta',
    'Netflix',
    'Apple',
    'Spotify',
    'Other'
  ];

  final List<String> _roles = [
    'Software Engineer',
    'Frontend Developer',
    'Backend Developer',
    'Full Stack Developer',
    'Mobile Developer',
    'Product Manager',
    'Data Scientist',
    'UI/UX Designer',
    'Other'
  ];

  final List<String> _experienceLevels = [
    'Intern',
    'Junior (0-2 years)',
    'Mid (2-5 years)',
    'Senior (5+ years)',
    'Lead / Manager'
  ];

  final List<String> _qualifications = [
    'High School',
    'Bachelor\'s Degree',
    'Master\'s Degree',
    'PhD',
    'Other'
  ];

  @override
  void dispose() {
    _customCompanyController.dispose();
    _customRoleController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final company = _selectedCompany == 'Other' ? _customCompanyController.text : _selectedCompany;
    final role = _selectedRole == 'Other' ? _customRoleController.text : _selectedRole;

    if (company == null || company.isEmpty ||
        role == null || role.isEmpty ||
        _experienceLevel == null ||
        _qualification == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).user;
      if (user == null) return;

      final profile = CandidateProfile(
        uid: user.uid,
        targetCompany: company,
        targetRole: role,
        experienceLevel: _experienceLevel!,
        qualification: _qualification!,
        createdAt: DateTime.now(),
      );

      await FirestoreService().saveProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile Saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white38)),
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1B4B),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                onPressed: () {
                  Provider.of<AuthService>(context, listen: false).signOut();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Keep your target details updated.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 32),

          _buildDropdown(
            value: _selectedCompany,
            hint: 'Target Company',
            items: _companies,
            onChanged: (val) => setState(() => _selectedCompany = val),
          ),
          if (_selectedCompany == 'Other') ...[
            const SizedBox(height: 8),
            AuthTextField(
              controller: _customCompanyController,
              hintText: 'Enter Company Name',
              icon: Icons.business,
            ),
          ],

          const SizedBox(height: 16),

          _buildDropdown(
            value: _selectedRole,
            hint: 'Target Role',
            items: _roles,
            onChanged: (val) => setState(() => _selectedRole = val),
          ),
          if (_selectedRole == 'Other') ...[
            const SizedBox(height: 8),
            AuthTextField(
              controller: _customRoleController,
              hintText: 'Enter Role Name',
              icon: Icons.work_outline,
            ),
          ],

          const SizedBox(height: 16),
          _buildDropdown(
            value: _experienceLevel,
            hint: 'Experience Level',
            items: _experienceLevels,
            onChanged: (val) => setState(() => _experienceLevel = val),
          ),

          const SizedBox(height: 16),
          _buildDropdown(
            value: _qualification,
            hint: 'Highest Qualification',
            items: _qualifications,
            onChanged: (val) => setState(() => _qualification = val),
          ),

          const SizedBox(height: 48),

          SizedBox(
            width: double.infinity,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : PrimaryButton(
                    text: 'Save Changes',
                    onPressed: _saveProfile,
                  ),
          ),
        ],
      ),
    );
  }
}
