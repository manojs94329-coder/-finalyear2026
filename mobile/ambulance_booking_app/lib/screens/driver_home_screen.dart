import 'dart:async';
import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import '../services/ambulance_service.dart';
import '../services/emergency_siren_service.dart';
import '../services/url_launcher_service.dart';
import '../widgets/live_video_viewfinder.dart';
import '../widgets/live_stream_receiver.dart';
import 'login_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final int ambulanceId;
  final String driverName;

  const DriverHomeScreen({super.key, required this.ambulanceId, required this.driverName});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final BookingService _bookingService = BookingService();
  final AmbulanceService _ambulanceService = AmbulanceService();
  final EmergencySirenService _sirenService = EmergencySirenService();

  dynamic _activeBooking;
  List<dynamic> _history = [];
  bool _isLoading = true;
  String _dutyStatus = "Available";
  Timer? _radarTimer;
  bool _isUpdating = false;

  // Live GPS Telemetry
  double _currentLat = 13.0850;
  double _currentLng = 80.2720;
  Timer? _gpsBroadcastTimer;
  final bool _isBroadcastingGps = true;
  String _gpsStatus = "Transmitting to 108 Command Center";

  @override
  void initState() {
    super.initState();
    _fetchDutyStatus();
    _pollActiveBooking();
    _fetchHistory();
    _initGpsTelemetry();
    _radarTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollActiveBooking();
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _gpsBroadcastTimer?.cancel();
    _sirenService.stopAndRelease();
    super.dispose();
  }

  void _initGpsTelemetry() {
    _gpsBroadcastTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isBroadcastingGps || !mounted) return;
      if (_activeBooking != null) {
        final pLat = (_activeBooking["pickupLatitude"] as num?)?.toDouble() ?? 13.0827;
        final pLng = (_activeBooking["pickupLongitude"] as num?)?.toDouble() ?? 80.2707;
        _currentLat += (pLat - _currentLat) * 0.06;
        _currentLng += (pLng - _currentLng) * 0.06;
      }
      try {
        await _ambulanceService.updateLocation(
          ambulanceId: widget.ambulanceId,
          latitude: _currentLat,
          longitude: _currentLng,
        );
        if (mounted) {
          setState(() {
            _gpsStatus = "Live GPS Active (${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)})";
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _fetchDutyStatus() async {
    try {
      final amb = await _ambulanceService.getAmbulance(widget.ambulanceId);
      if (mounted && amb != null && amb["status"] != null) {
        setState(() => _dutyStatus = amb["status"]);
      }
    } catch (_) {}
  }

  Future<void> _pollActiveBooking() async {
    try {
      final data = await _bookingService.getDriverActiveBooking(widget.ambulanceId);
      if (mounted) {
        // If new incoming emergency request, play sound alert
        if (data != null && data["status"] == "Requested" && (_activeBooking == null || _activeBooking["status"] != "Requested")) {
          _sirenService.startSiren();
        } else if (data == null || data["status"] != "Requested") {
          _sirenService.stopAndRelease();
        }

        setState(() {
          _activeBooking = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final list = await _bookingService.getDriverHistory(widget.ambulanceId);
      if (mounted && list is List) {
        setState(() => _history = list);
      }
    } catch (_) {}
  }

  Future<void> _toggleDuty(String newStatus) async {
    setState(() => _dutyStatus = newStatus);
    try {
      await _ambulanceService.updateStatus(widget.ambulanceId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Duty status changed to $newStatus"), backgroundColor: const Color(0xFF0C831F)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update status: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateTripStatus(String nextStatus) async {
    if (_activeBooking == null || _isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final bookingId = _activeBooking["bookingId"];
      await _bookingService.updateStatus(bookingId, nextStatus);
      _sirenService.stopAndRelease();

      if (nextStatus == "Completed") {
        setState(() {
          _activeBooking = null;
          _dutyStatus = "Available";
        });
        _fetchHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mission Completed! You are now Available."), backgroundColor: Color(0xFF0C831F)),
        );
      } else {
        await _pollActiveBooking();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Status Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _declineBooking() async {
    if (_activeBooking == null) return;
    final bookingId = _activeBooking["bookingId"];
    _sirenService.stopAndRelease();

    try {
      await _bookingService.rejectBooking(bookingId);
      setState(() => _activeBooking = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incident declined. Reallocated to next unit."), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showVictimLiveStreamModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final cond = _activeBooking?["patientCondition"] ?? "Crash Site Live Telemetry";
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.videocam, color: Colors.redAccent, size: 20),
                        SizedBox(width: 8),
                        Text("CRASH SCENE LIVE AV BROADCAST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const LiveStreamReceiver(
                  emergencyId: "",
                  callerRole: "PARAMEDIC IN-CABIN HUD",
                  locationText: "Victim Crash Site • Anna Salai, Chennai",
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PARAMEDIC IN-CABIN RECEPTION", style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text("Triage: $cond", style: const TextStyle(color: Colors.white, fontSize: 12)),
                      const SizedBox(height: 4),
                      const Text("Live Stream Channel: WebRTC 108-Emergency-EnRoute", style: TextStyle(color: Colors.white60, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text("CONTINUE EMERGENCY NAVIGATION", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C831F),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
            Text("Paramedic HUD • ${widget.driverName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            const Text("Blinkit Rapid Emergency Dispatch Partner", style: TextStyle(fontSize: 10, color: Color(0xFF10B981))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              _pollActiveBooking();
              _fetchHistory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Duty Status Switcher Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1F2937),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _dutyStatus == "Available" ? const Color(0xFF10B981) : (_dutyStatus == "Busy" ? const Color(0xFFF59E0B) : Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "DUTY: ${_dutyStatus.toUpperCase()}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: _toggleDuty,
                  color: const Color(0xFF111827),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Text("CHANGE DUTY", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: "Available", child: Text("🟢 Online (Available)", style: TextStyle(color: Colors.greenAccent))),
                    const PopupMenuItem(value: "Busy", child: Text("🟡 Busy on Incident", style: TextStyle(color: Colors.orangeAccent))),
                    const PopupMenuItem(value: "OffDuty", child: Text("⚪ Off-Duty / Break", style: TextStyle(color: Colors.white70))),
                  ],
                ),
              ],
            ),
          ),

          // Live GPS Telemetry Status Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF111827),
            child: Row(
              children: [
                const Icon(Icons.satellite_alt, color: Color(0xFF38BDF8), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _gpsStatus,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                InkWell(
                  onTap: () {
                    UrlLauncherService.openUrl("https://maps.google.com/?q=$_currentLat,$_currentLng");
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pin_drop, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text("MY PIN", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Active Incident HUD or Radar Standby
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_activeBooking != null)
                        _buildActiveMissionCard()
                      else
                        _buildRadarStandbyCard(),

                      const SizedBox(height: 20),

                      // History Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Completed Emergency Runs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
                          Text("${_history.length} completed", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_history.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.15))),
                          child: const Center(
                            child: Text("No completed missions yet for this shift.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                        )
                      else
                        ..._history.map((h) => _buildHistoryCard(h)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMissionCard() {
    final status = _activeBooking["status"] ?? "Requested";
    final isRequested = status == "Requested";
    final user = _activeBooking["user"];
    final hospital = _activeBooking["hospital"];
    final price = _activeBooking["estimatedPrice"] ?? 650.0;
    final addons = _activeBooking["equipmentAddons"] ?? "Oxygen, Stretcher";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isRequested ? Colors.red : const Color(0xFF0C831F), width: 2),
        boxShadow: [
          BoxShadow(color: (isRequested ? Colors.red : const Color(0xFF0C831F)).withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isRequested ? Colors.red : const Color(0xFF0C831F),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(isRequested ? Icons.warning_amber : Icons.navigation, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  isRequested ? "⚡ INCOMING EMERGENCY DISPATCH" : "ACTIVE MISSION: $status",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                Text("₹${price.toInt()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient condition
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PATIENT CONDITION & TRIAGE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red)),
                      const SizedBox(height: 4),
                      Text(
                        _activeBooking["patientCondition"] ?? "Emergency medical response requested",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Equipment Checklist
                Row(
                  children: [
                    const Icon(Icons.checklist, color: Color(0xFF0C831F), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text("Required Equipment: $addons", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0C831F))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Patient Profile
                if (user != null)
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF111827),
                        child: Text(user["fullName"]?[0] ?? "P", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user["fullName"] ?? "Emergency Citizen", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("Blood Group: ${user["bloodGroup"] ?? "O+"} • Contact: ${user["phoneNumber"] ?? ""}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),

                // Destination Hospital
                Row(
                  children: [
                    const Icon(Icons.local_hospital, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Target: ${hospital != null ? hospital["name"] : (_activeBooking["destinationHospital"] ?? "Nearest Trauma Center")}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Live GPS Google Maps Turn-by-Turn Navigation Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0C831F).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.navigation, color: Color(0xFF0C831F), size: 18),
                          const SizedBox(width: 6),
                          const Text("LIVE GPS NAVIGATION & RADAR", style: TextStyle(color: Color(0xFF0C831F), fontWeight: FontWeight.bold, fontSize: 11)),
                          const Spacer(),
                          Text(
                            "Pickup: ${(_activeBooking["pickupLatitude"] ?? 13.0827).toStringAsFixed(4)}, ${(_activeBooking["pickupLongitude"] ?? 80.2707).toStringAsFixed(4)}",
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final pLat = _activeBooking["pickupLatitude"] ?? 13.0827;
                            final pLng = _activeBooking["pickupLongitude"] ?? 80.2707;
                            final navUrl = "https://www.google.com/maps/dir/?api=1&origin=$_currentLat,$_currentLng&destination=$pLat,$pLng&travelmode=driving";
                            UrlLauncherService.openUrl(navUrl);
                          },
                          icon: const Icon(Icons.directions, color: Colors.white, size: 18),
                          label: const Text(
                            "🗺️ START GOOGLE MAPS TURN-BY-TURN (TO PATIENT)",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C831F),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final hLat = hospital != null ? (hospital["latitude"] ?? 13.0805) : 13.0805;
                            final hLng = hospital != null ? (hospital["longitude"] ?? 80.2764) : 80.2764;
                            final hospUrl = "https://www.google.com/maps/dir/?api=1&origin=$_currentLat,$_currentLng&destination=$hLat,$hLng&travelmode=driving";
                            UrlLauncherService.openUrl(hospUrl);
                          },
                          icon: const Icon(Icons.local_hospital, color: Colors.white, size: 16),
                          label: const Text(
                            "🏥 NAVIGATE TO DESTINATION HOSPITAL",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final pLat = _activeBooking["pickupLatitude"] ?? 13.0827;
                                final pLng = _activeBooking["pickupLongitude"] ?? 80.2707;
                                UrlLauncherService.openUrl("https://maps.google.com/?q=$pLat,$pLng");
                              },
                              icon: const Icon(Icons.pin_drop, size: 14, color: Color(0xFF0C831F)),
                              label: const Text("PATIENT PIN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C831F))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF0C831F)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final bookingId = _activeBooking["bookingId"] ?? 1;
                                final agoraUrl = "https://emergency-agora.stream/room/emergency_booking_$bookingId";
                                UrlLauncherService.openUrl(agoraUrl);
                              },
                              icon: const Icon(Icons.videocam, size: 14, color: Color(0xFF2563EB)),
                              label: const Text("AGORA LIVE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Victim Live Video & Audio Feed Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.videocam, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            "LIVE VICTIM AV TRANSMISSION ACTIVE",
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                            child: const Text("LIVE FEED", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Crash scene camera and microphone are actively streaming to your vehicle cabin.",
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: _showVictimLiveStreamModal,
                          icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 18),
                          label: const Text(
                            "📹 WATCH VICTIM LIVE VIDEO & AUDIO",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Workflow Action Buttons
                if (isRequested)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _declineBooking,
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: const Text("DECLINE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isUpdating ? null : () => _updateTripStatus("Accepted"),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text("ACCEPT CALL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0C831F), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  )
                else if (status == "Accepted")
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : () => _updateTripStatus("InProgress"),
                      icon: const Icon(Icons.directions_car, color: Colors.white),
                      label: const Text("EN ROUTE TO SCENE (SIREN ON)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0C831F), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  )
                else if (status == "InProgress")
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : () => _updateTripStatus("Completed"),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text("HANDOVER AT HOSPITAL (COMPLETE)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarStandbyCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 3),
            ),
            child: const Icon(Icons.radar, color: Color(0xFF0C831F), size: 48),
          ),
          const SizedBox(height: 16),
          const Text("RADAR ACTIVE • SCANNING FOR CALLS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text("You are queued at high-priority for any incoming emergency within 10 km.", style: TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
            child: const Text("Target Dispatch SLA: < 60 seconds", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C831F))),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check, color: Color(0xFF0C831F), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Emergency Run #${item["bookingId"]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("Hospital: ${item["destinationHospital"] ?? "General"}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Text(
            "₹${item["estimatedPrice"] ?? 650}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0C831F)),
          ),
        ],
      ),
    );
  }
}
