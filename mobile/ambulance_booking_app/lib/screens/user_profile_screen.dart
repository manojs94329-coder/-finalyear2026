import 'package:flutter/material.dart';
import '../services/user_service.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _medicalController = TextEditingController();
  String _selectedBloodGroup = "O+";

  final List<String> _bloodGroups = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyController.dispose();
    _medicalController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _userService.getUserProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _nameController.text = user["fullName"] ?? "";
        _phoneController.text = user["phoneNumber"] ?? "";
        _emailController.text = user["email"] ?? "";
        _emergencyController.text = user["emergencyContact"] ?? "";
        _medicalController.text = user["medicalDetails"] ?? "";
        if (user["bloodGroup"] != null && _bloodGroups.contains(user["bloodGroup"])) {
          _selectedBloodGroup = user["bloodGroup"];
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading profile: $e")));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await _userService.updateUserProfile(widget.userId, {
        "fullName": _nameController.text.trim(),
        "phoneNumber": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "bloodGroup": _selectedBloodGroup,
        "emergencyContact": _emergencyController.text.trim(),
        "medicalDetails": _medicalController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Medical profile saved successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text("Medical & Emergency Profile"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.health_and_safety, color: Colors.red, size: 30),
                          SizedBox(width: 10),
                          Text(
                            "Patient Health Info",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "This info is automatically forwarded to emergency responders and paramedics during dispatch.",
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const Divider(height: 24),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBloodGroup,
                        decoration: const InputDecoration(labelText: "Blood Group", border: OutlineInputBorder(), prefixIcon: Icon(Icons.bloodtype)),
                        items: _bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (val) => setState(() => _selectedBloodGroup = val!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emergencyController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Emergency Contact Phone",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.contact_phone),
                          helperText: "Relative or primary guardian to notify in an emergency",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _medicalController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Allergies & Pre-existing Conditions",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.medical_information),
                          helperText: "e.g. Diabetic, Asthma, Penicillin allergy, Cardiac history",
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text(_isSaving ? "Saving..." : "Save Emergency Profile"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: _isSaving ? null : _saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
