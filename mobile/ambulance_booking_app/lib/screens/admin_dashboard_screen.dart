import 'dart:async';
import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/hospital_service.dart';
import '../services/url_launcher_service.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int adminId;
  final String adminName;

  const AdminDashboardScreen({super.key, required this.adminId, required this.adminName});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final HospitalService _hospitalService = HospitalService();

  late TabController _tabController;
  dynamic _dashboardMetrics;
  List<dynamic> _bookings = [];
  List<dynamic> _ambulances = [];
  List<dynamic> _pendingAmbulances = [];
  List<dynamic> _users = [];
  List<dynamic> _hospitals = [];

  bool _isLoading = true;
  String _selectedStatusFilter = "All";
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchAllData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetchAllData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final metrics = await _adminService.getDashboardMetrics();
      final bookings = await _adminService.getAllBookings();
      final ambulances = await _adminService.getAmbulances();
      final pending = await _adminService.getPendingAmbulances();
      final users = await _adminService.getUsers();
      final hospitals = await _hospitalService.getHospitals();

      if (mounted) {
        setState(() {
          _dashboardMetrics = metrics;
          _bookings = bookings is List ? bookings : [];
          _ambulances = ambulances is List ? ambulances : [];
          _pendingAmbulances = pending is List ? pending : [];
          _users = users is List ? users : [];
          _hospitals = hospitals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveAmbulance(int ambulanceId) async {
    try {
      await _adminService.approveAmbulance(ambulanceId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ambulance approved for emergency fleet!"), backgroundColor: Color(0xFF0C831F)),
      );
      _fetchAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Approval error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _adjustHospitalBeds(int hospitalId, int delta) async {
    final hospital = _hospitals.firstWhere((h) => h["hospitalId"] == hospitalId, orElse: () => null);
    if (hospital == null) return;
    final current = hospital["availableIcuBeds"] ?? 10;
    final newCount = (current + delta).clamp(0, 500);

    try {
      await _hospitalService.updateBeds(hospitalId, newCount);
      _fetchAllData(silent: true);
    } catch (_) {}
  }

  void _showManualDispatchDialog(dynamic booking) {
    int? selectedAmbId;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Dispatch Unit for Incident #${booking["bookingId"]}", style: const TextStyle(color: Colors.white, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select available ambulance unit:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    dropdownColor: const Color(0xFF1F2937),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1F2937),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    items: _ambulances.map<DropdownMenuItem<int>>((amb) {
                      final isAvail = amb["status"] == "Available";
                      return DropdownMenuItem<int>(
                        value: amb["ambulanceId"],
                        child: Text(
                          "${amb["driverName"]} (${amb["vehicleNumber"]}) - ${amb["status"]}",
                          style: TextStyle(color: isAvail ? const Color(0xFF10B981) : Colors.white70, fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedAmbId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  onPressed: selectedAmbId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await _adminService.assignAmbulance(booking["bookingId"], selectedAmbId!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Ambulance reassigned successfully!"), backgroundColor: Color(0xFF0C831F)),
                            );
                            _fetchAllData();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0C831F)),
                  child: const Text("DISPATCH UNIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Command Center • ${widget.adminName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            const Text("Blinkit Emergency Hub & Dark-Store Fleet Monitor", style: TextStyle(fontSize: 10, color: Color(0xFF10B981))),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => _fetchAllData()),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          isScrollable: true,
          tabs: [
            Tab(text: "LIVE INCIDENTS (${_bookings.length})"),
            Tab(text: "🗺️ GPS RADAR (${_ambulances.length})"),
            Tab(text: "FLEET HUB (${_ambulances.length})"),
            Tab(text: "ICU BEDS (${_hospitals.length})"),
            Tab(text: "APPROVALS (${_pendingAmbulances.length})"),
            Tab(text: "USERS (${_users.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)))
          : Column(
              children: [
                // 1. KPI SLA Metric Ribbon
                _buildSlaRibbon(),

                // 2. Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIncidentsTab(),
                      _buildGpsRadarTab(),
                      _buildFleetTab(),
                      _buildHospitalsTab(),
                      _buildApprovalsTab(),
                      _buildUsersTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSlaRibbon() {
    final activeCount = _dashboardMetrics != null ? (_dashboardMetrics["activeBookings"] ?? 0) : 0;
    final totalIcu = _dashboardMetrics != null ? (_dashboardMetrics["totalIcuBedsAvailable"] ?? 84) : 84;
    final availFleet = _dashboardMetrics != null ? (_dashboardMetrics["availableAmbulances"] ?? 0) : 0;
    final totalFleet = _dashboardMetrics != null ? (_dashboardMetrics["totalAmbulances"] ?? 0) : 0;

    return Container(
      color: const Color(0xFF1F2937),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildKpiCard("8-MIN SLA", "98.7% On-Time", const Color(0xFF10B981), Icons.bolt),
          _buildKpiCard("ACTIVE RUNS", "$activeCount Ongoing", activeCount > 0 ? Colors.redAccent : Colors.white70, Icons.emergency),
          _buildKpiCard("ICU BEDS", "$totalIcu Live Open", const Color(0xFF38BDF8), Icons.bed),
          _buildKpiCard("FLEET", "$availFleet / $totalFleet Ready", const Color(0xFFFBBF24), Icons.airport_shuttle),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildIncidentsTab() {
    final filtered = _selectedStatusFilter == "All"
        ? _bookings
        : _bookings.where((b) => b["status"] == _selectedStatusFilter).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["All", "Requested", "Accepted", "InProgress", "Completed"].map((filter) {
                final isSelected = _selectedStatusFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0C831F),
                    backgroundColor: Colors.grey[200],
                    onSelected: (_) => setState(() => _selectedStatusFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text("No incident records found", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final b = filtered[index];
                    final status = b["status"] ?? "Requested";

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status == "Completed" ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(status.toUpperCase(), style: TextStyle(color: status == "Completed" ? const Color(0xFF0C831F) : Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                              const SizedBox(width: 8),
                              Text("Run #${b["bookingId"]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const Spacer(),
                              Text("₹${b["estimatedPrice"] ?? 650}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0C831F))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(b["patientCondition"] ?? "Emergency Incident", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text("Hospital: ${b["destinationHospital"] ?? "Nearest"}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.pin_drop, size: 14, color: Colors.redAccent),
                              const SizedBox(width: 4),
                              Text(
                                "Pickup: ${(b["pickupLatitude"] ?? 13.0827).toStringAsFixed(4)}, ${(b["pickupLongitude"] ?? 80.2707).toStringAsFixed(4)}",
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  final pLat = b["pickupLatitude"] ?? 13.0827;
                                  final pLng = b["pickupLongitude"] ?? 80.2707;
                                  final amb = _ambulances.firstWhere((a) => a["ambulanceId"] == b["ambulanceId"], orElse: () => null);
                                  final aLat = amb != null ? (amb["currentLatitude"] ?? 13.0850) : 13.0850;
                                  final aLng = amb != null ? (amb["currentLongitude"] ?? 80.2720) : 80.2720;
                                  final routeUrl = "https://www.google.com/maps/dir/?api=1&origin=$aLat,$aLng&destination=$pLat,$pLng&travelmode=driving";
                                  UrlLauncherService.openUrl(routeUrl);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.map, color: Color(0xFF2563EB), size: 12),
                                      SizedBox(width: 4),
                                      Text("MAP ROUTE", style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (status != "Completed") ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showManualDispatchDialog(b),
                                icon: const Icon(Icons.swap_horiz, size: 16),
                                label: const Text("MANUAL DISPATCH / REASSIGN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111827), visualDensity: VisualDensity.compact),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGpsRadarTab() {
    final activeBookings = _bookings.where((b) => b["status"] == "Requested" || b["status"] == "Accepted" || b["status"] == "InProgress").toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Global Map Launch Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF0284C7).withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.satellite_alt, color: Color(0xFF38BDF8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TAMIL NADU FLEET GPS COMMAND CENTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text("Real-time GPS telemetry linked directly with Google Maps", style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    const overviewUrl = "https://www.google.com/maps/dir/?api=1&origin=13.0850,80.2720&destination=13.0805,80.2764&waypoints=13.0827,80.2707&travelmode=driving";
                    UrlLauncherService.openUrl(overviewUrl);
                  },
                  icon: const Icon(Icons.map, color: Colors.white, size: 18),
                  label: const Text(
                    "🗺️ OPEN TAMIL NADU FLEET RADAR IN GOOGLE MAPS",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Active Emergency Missions Section
        if (activeBookings.isNotEmpty) ...[
          const Text(
            "ACTIVE EMERGENCY MISSIONS (IN-TRANSIT ON GOOGLE MAPS)",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          ...activeBookings.map((b) {
            final pLat = (b["pickupLatitude"] as num?)?.toDouble() ?? 13.0827;
            final pLng = (b["pickupLongitude"] as num?)?.toDouble() ?? 80.2707;
            final amb = _ambulances.firstWhere((a) => a["ambulanceId"] == b["ambulanceId"], orElse: () => null);
            final aLat = amb != null ? ((amb["currentLatitude"] as num?)?.toDouble() ?? 13.0850) : 13.0850;
            final aLng = amb != null ? ((amb["currentLongitude"] as num?)?.toDouble() ?? 80.2720) : 80.2720;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emergency, color: Colors.red, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Mission #${b["bookingId"]} • ${b["status"]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                        Text("Target: ${b["destinationHospital"] ?? "Trauma Center"}", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        Text("Pickup GPS: ${pLat.toStringAsFixed(4)}, ${pLng.toStringAsFixed(4)}", style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final routeUrl = "https://www.google.com/maps/dir/?api=1&origin=$aLat,$aLng&destination=$pLat,$pLng&travelmode=driving";
                      UrlLauncherService.openUrl(routeUrl);
                    },
                    icon: const Icon(Icons.map, size: 14, color: Colors.white),
                    label: const Text("MAP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
        ],

        const Text(
          "LIVE AMBULANCE GPS BEACONS (TAMIL NADU FLEET)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),

        ..._ambulances.map((amb) {
          final lat = (amb["currentLatitude"] as num?)?.toDouble() ?? 13.0850;
          final lng = (amb["currentLongitude"] as num?)?.toDouble() ?? 80.2720;
          final isAvail = amb["status"] == "Available";

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAvail ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.airport_shuttle, color: isAvail ? const Color(0xFF0C831F) : Colors.red, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${amb["driverName"]} (${amb["vehicleNumber"]})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.gps_fixed, size: 12, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            "GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAvail ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              amb["status"] ?? "Available",
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isAvail ? const Color(0xFF0C831F) : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    UrlLauncherService.openUrl("https://maps.google.com/?q=$lat,$lng");
                  },
                  icon: const Icon(Icons.pin_drop, size: 14, color: Colors.white),
                  label: const Text("MAP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFleetTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ambulances.length,
      itemBuilder: (context, index) {
        final amb = _ambulances[index];
        final isAvail = amb["status"] == "Available";
        final lat = (amb["currentLatitude"] as num?)?.toDouble() ?? 13.0850;
        final lng = (amb["currentLongitude"] as num?)?.toDouble() ?? 80.2720;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.airport_shuttle, color: Color(0xFF0C831F), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(amb["driverName"] ?? "Driver", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("${amb["vehicleNumber"]} • ${amb["ambulanceType"] ?? "ALS"}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    Text("GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}", style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                    Text("Phone: ${amb["driverPhone"]}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAvail ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      amb["status"] ?? "Available",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAvail ? const Color(0xFF0C831F) : Colors.red),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      UrlLauncherService.openUrl("https://maps.google.com/?q=$lat,$lng");
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        children: [
                          Icon(Icons.pin_drop, color: Color(0xFF2563EB), size: 12),
                          SizedBox(width: 2),
                          Text("MAP", style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHospitalsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hospitals.length,
      itemBuilder: (context, index) {
        final h = _hospitals[index];
        final beds = h["availableIcuBeds"] ?? 10;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_hospital, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h["name"] ?? "Hospital", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(h["address"] ?? "", style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("Hotline: ${h["contactPhone"]}", style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                        onPressed: () => _adjustHospitalBeds(h["hospitalId"], -1),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text("$beds", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF0C831F)),
                        onPressed: () => _adjustHospitalBeds(h["hospitalId"], 1),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const Text("ICU Beds", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApprovalsTab() {
    if (_pendingAmbulances.isEmpty) {
      return const Center(
        child: Text("No pending ambulance registrations.", style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingAmbulances.length,
      itemBuilder: (context, index) {
        final amb = _pendingAmbulances[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(amb["driverName"] ?? "Driver", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("Plate: ${amb["vehicleNumber"]} • Phone: ${amb["driverPhone"]}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _approveAmbulance(amb["ambulanceId"]),
                icon: const Icon(Icons.check, size: 16),
                label: const Text("APPROVE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0C831F)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF111827),
                child: Text(u["fullName"]?[0] ?? "U", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u["fullName"] ?? "Citizen", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text("Phone: ${u["phoneNumber"]} • Email: ${u["email"]}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    if (u["bloodGroup"] != null)
                      Text("Blood: ${u["bloodGroup"]} • Allergy: ${u["medicalDetails"] ?? "None"}", style: const TextStyle(fontSize: 10, color: Color(0xFF0C831F), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
