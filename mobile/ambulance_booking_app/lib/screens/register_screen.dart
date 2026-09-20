import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final int initialIndex;
  const RegisterScreen({super.key, this.initialIndex = 0});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // User Controllers
  final _userNameController = TextEditingController();
  final _userPhoneController = TextEditingController();
  final _userEmailController = TextEditingController();
  final _userPasswordController = TextEditingController();
  final _userEmergencyController = TextEditingController();
  final _userMedicalController = TextEditingController();
  String _selectedBloodGroup = "O+";

  // Driver Controllers
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _driverEmailController = TextEditingController();
  final _driverPasswordController = TextEditingController();
  final _driverVehicleController = TextEditingController();
  String _selectedAmbulanceType = "Basic Life Support";

  // Admin Controllers
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  final List<String> _bloodGroups = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];
  final List<String> _ambulanceTypes = [
    "Basic Life Support",
    "Advanced Life Support",
    "Patient Transport",
    "Neonatal Ambulance"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialIndex.clamp(0, 2));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userNameController.dispose();
    _userPhoneController.dispose();
    _userEmailController.dispose();
    _userPasswordController.dispose();
    _userEmergencyController.dispose();
    _userMedicalController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _driverEmailController.dispose();
    _driverPasswordController.dispose();
    _driverVehicleController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _registerUser() async {
    if (_userNameController.text.trim().isEmpty ||
        _userPhoneController.text.trim().isEmpty ||
        _userPasswordController.text.trim().isEmpty) {
      _showMessage("Please fill in all required fields (Name, Phone, Password)", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.registerUser(
        fullName: _userNameController.text.trim(),
        phoneNumber: _userPhoneController.text.trim(),
        email: _userEmailController.text.trim(),
        password: _userPasswordController.text.trim(),
        bloodGroup: _selectedBloodGroup,
        emergencyContact: _userEmergencyController.text.trim(),
        medicalDetails: _userMedicalController.text.trim(),
      );
      if (!mounted) return;
      _showSuccessDialog("User Account Created!", "You can now log in with your phone number or email.");
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith("Exception: ")) msg = msg.substring("Exception: ".length);
      _showMessage(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerDriver() async {
    if (_driverNameController.text.trim().isEmpty ||
        _driverPhoneController.text.trim().isEmpty ||
        _driverPasswordController.text.trim().isEmpty ||
        _driverVehicleController.text.trim().isEmpty) {
      _showMessage("Please fill in all required fields (Name, Phone, Password, Vehicle #)", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.registerDriver(
        driverName: _driverNameController.text.trim(),
        driverPhone: _driverPhoneController.text.trim(),
        email: _driverEmailController.text.trim(),
        password: _driverPasswordController.text.trim(),
        vehicleNumber: _driverVehicleController.text.trim(),
        ambulanceType: _selectedAmbulanceType,
      );
      if (!mounted) return;
      _showSuccessDialog(
        "Ambulance Registered!",
        "Your ambulance is pending admin approval. An admin can approve it from the Admin Dashboard before you log in.",
      );
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith("Exception: ")) msg = msg.substring("Exception: ".length);
      _showMessage(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerAdmin() async {
    if (_adminNameController.text.trim().isEmpty ||
        _adminEmailController.text.trim().isEmpty ||
        _adminPasswordController.text.trim().isEmpty) {
      _showMessage("Please fill in Name, Email, and Password", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.registerAdmin(
        fullName: _adminNameController.text.trim(),
        email: _adminEmailController.text.trim(),
        password: _adminPasswordController.text.trim(),
      );
      if (!mounted) return;
      _showSuccessDialog("Admin Account Created!", "You can now log in to the Command Center.");
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith("Exception: ")) msg = msg.substring("Exception: ".length);
      _showMessage(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(content),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // return to login
            },
            child: const Text("Go to Login"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text("Create New Account"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: "User"),
            Tab(icon: Icon(Icons.airport_shuttle), text: "Driver"),
            Tab(icon: Icon(Icons.admin_panel_settings), text: "Admin"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserForm(),
          _buildDriverForm(),
          _buildAdminForm(),
        ],
      ),
    );
  }

  Widget _buildUserForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("User / Patient Registration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _userNameController,
                decoration: const InputDecoration(labelText: "Full Name *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Phone Number *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedBloodGroup,
                decoration: const InputDecoration(labelText: "Blood Group", border: OutlineInputBorder(), prefixIcon: Icon(Icons.bloodtype)),
                items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                onChanged: (val) => setState(() => _selectedBloodGroup = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userEmergencyController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Emergency Contact Phone", border: OutlineInputBorder(), prefixIcon: Icon(Icons.contact_phone)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userMedicalController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Known Medical Conditions / Allergies", border: OutlineInputBorder(), prefixIcon: Icon(Icons.medical_services)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _registerUser,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_isLoading ? "Registering..." : "Register as User", style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Ambulance Driver Registration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "After registering, an Admin must approve your vehicle before you can log in.",
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _driverNameController,
                decoration: const InputDecoration(labelText: "Driver Name *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _driverPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Driver Phone *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _driverEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _driverPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _driverVehicleController,
                decoration: const InputDecoration(labelText: "Vehicle Number (e.g. TN01AB1234) *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.directions_car)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedAmbulanceType,
                decoration: const InputDecoration(labelText: "Ambulance Type", border: OutlineInputBorder(), prefixIcon: Icon(Icons.medical_information)),
                items: _ambulanceTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) => setState(() => _selectedAmbulanceType = val!),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _registerDriver,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_isLoading ? "Registering..." : "Register Ambulance & Driver", style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Administrator Registration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _adminNameController,
                decoration: const InputDecoration(labelText: "Admin Full Name *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.admin_panel_settings)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adminEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Admin Email *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adminPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _registerAdmin,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_isLoading ? "Registering..." : "Register as Admin", style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
