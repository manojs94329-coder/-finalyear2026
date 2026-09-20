import 'package:flutter/material.dart';
import 'user_home_screen.dart';
import 'driver_home_screen.dart';
import 'admin_dashboard_screen.dart';
import 'register_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String initialRole;
  const LoginScreen({super.key, this.initialRole = "User"});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  late String selectedRole;
  bool isLoading = false;
  final AuthService authService = AuthService();

  @override
  void initState() {
    super.initState();
    selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _fillDriverDemo() {
    setState(() {
      selectedRole = "Driver";
      phoneController.text = "robert.driver@emergency.com";
      passwordController.text = "Password123!";
    });
    login();
  }

  void _fillPatientDemo() {
    setState(() {
      selectedRole = "User";
      phoneController.text = "sarah.patient@gmail.com";
      passwordController.text = "Password123!";
    });
    login();
  }

  void _fillAdminDemo() {
    setState(() {
      selectedRole = "Admin";
      phoneController.text = "admin@emergency.com";
      passwordController.text = "Password123!";
    });
    login();
  }

  Future<void> login() async {
    final identifier = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter phone/email/vehicle and password.")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await authService.login(identifier, password, selectedRole);

      if (!mounted) return;

      if (response["role"] == "User") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UserHomeScreen(userId: response["id"], userName: response["name"] ?? "Citizen")),
        );
      } else if (response["role"] == "Driver") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DriverHomeScreen(ambulanceId: response["id"], driverName: response["name"] ?? "Driver")),
        );
      } else if (response["role"] == "Admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminDashboardScreen(adminId: response["id"] ?? 1, adminName: response["name"] ?? "System Admin")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login failed: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = selectedRole == "Driver";
    final isAdmin = selectedRole == "Admin";

    final themeColor = isDriver
        ? const Color(0xFF0C831F)
        : isAdmin
            ? const Color(0xFF4F46E5)
            : const Color(0xFFDC2626);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Tamil Nadu Emergency & Ambulance Response (108)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                // Top Role Switcher Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      _buildRoleTab("User", "👤 Patient", const Color(0xFFDC2626)),
                      _buildRoleTab("Driver", "🚑 Driver", const Color(0xFF0C831F)),
                      _buildRoleTab("Admin", "🛡️ Admin", const Color(0xFF4F46E5)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Main Login Card
                Card(
                  elevation: 6,
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: themeColor.withOpacity(0.5), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Role Icon & Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDriver
                                ? Icons.airport_shuttle
                                : isAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.emergency,
                            size: 46,
                            color: themeColor,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          isDriver
                              ? "Ambulance Driver Base"
                              : isAdmin
                                  ? "Hospital Admin Console"
                                  : "Patient & Family Portal",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDriver
                              ? "Incident Radar, Live GPS & Turn-by-Turn Dispatch"
                              : isAdmin
                                  ? "Live Fleet Oversight & Bed Management"
                                  : "1-Tap SOS, Crash Sensors & Live Tracking",
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),

                        // Username / Phone / Email field
                        TextField(
                          controller: phoneController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: isDriver ? "Driver Phone, Email, or Vehicle #" : "Phone, Email, or Name",
                            labelStyle: const TextStyle(color: Colors.white60),
                            hintText: isDriver ? "e.g. 9876543210 or robert.driver@emergency.com" : "e.g. 9876543210",
                            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                            prefixIcon: Icon(isDriver ? Icons.drive_eta : Icons.person, color: themeColor),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password field
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Password",
                            labelStyle: const TextStyle(color: Colors.white60),
                            prefixIcon: Icon(Icons.lock, color: themeColor),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Main Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    isDriver ? "SIGN IN AS DRIVER" : isAdmin ? "SIGN IN AS ADMIN" : "SIGN IN AS PATIENT",
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Quick 1-Tap Demo Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isLoading
                                ? null
                                : isDriver
                                    ? _fillDriverDemo
                                    : isAdmin
                                        ? _fillAdminDemo
                                        : _fillPatientDemo,
                            icon: const Icon(Icons.bolt, size: 18),
                            label: Text(
                              isDriver
                                  ? "⚡ QUICK LOGIN (TN 108 Driver - M. Murugan)"
                                  : isAdmin
                                      ? "⚡ QUICK LOGIN (TN State Emergency Admin)"
                                      : "⚡ QUICK LOGIN (Sarah Sundaram - Chennai)",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: themeColor.withOpacity(0.6)),
                              foregroundColor: themeColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 10),

                        // Register links
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isDriver ? "New Ambulance Driver?" : "Don't have an account?",
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(initialIndex: isDriver ? 1 : 0),
                                  ),
                                );
                              },
                              child: Text(
                                isDriver ? "Register Ambulance" : "Register Now",
                                style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Dedicated Quick-Access Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickChip("🚑 Driver Base", "Driver", const Color(0xFF0C831F)),
                    _buildQuickChip("👤 Patient App", "User", const Color(0xFFDC2626)),
                    _buildQuickChip("🛡️ Admin Console", "Admin", const Color(0xFF4F46E5)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(String role, String label, Color color) {
    final isSelected = selectedRole == role;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedRole = role;
            phoneController.clear();
            passwordController.clear();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, String role, Color color) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedRole = role;
          if (role == "Driver") _fillDriverDemo();
          else if (role == "User") _fillPatientDemo();
          else if (role == "Admin") _fillAdminDemo();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}
