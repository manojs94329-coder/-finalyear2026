import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/booking_service.dart';
import '../services/hospital_service.dart';
import '../services/emergency_siren_service.dart';
import '../services/emergency_coordinator_service.dart';
import '../services/live_av_stream_service.dart';
import 'tracking_screen.dart';
import 'user_profile_screen.dart';
import 'user_history_screen.dart';
import 'hospital_directory_screen.dart';
import 'first_aid_guide_screen.dart';
import 'accident_detection_screen.dart';
import 'login_screen.dart';
import '../services/url_launcher_service.dart';

class UserHomeScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const UserHomeScreen({super.key, required this.userId, required this.userName});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final BookingService _bookingService = BookingService();
  final HospitalService _hospitalService = HospitalService();
  final EmergencySirenService _sirenService = EmergencySirenService();
  final EmergencyCoordinatorService _coordinator = EmergencyCoordinatorService();
  final LiveAvStreamService _streamService = LiveAvStreamService();

  double _lat = 13.0827;
  double _lng = 80.2707;
  String _currentAddress = "Dr. M.G.R. Central, Anna Salai, Chennai, Tamil Nadu 600003";
  bool _isLocating = false;

  // Selected Blinkit Fleet Tier
  int _selectedTierIndex = 0;
  final List<Map<String, dynamic>> _fleetTiers = [
    {
      "name": "ICU on Wheels",
      "tag": "CRITICAL",
      "eta": 6,
      "price": 1200.0,
      "icon": Icons.emergency,
      "color": const Color(0xFFDC2626),
      "desc": "Built-in Ventilator, Multi-Para Monitor & Emergency Doctor",
    },
    {
      "name": "Cardiac & Stroke Unit",
      "tag": "CARDIAC",
      "eta": 7,
      "price": 1000.0,
      "icon": Icons.monitor_heart,
      "color": const Color(0xFFEA580C),
      "desc": "Defibrillator, 12-Lead ECG, Resuscitation Drugs & Paramedic",
    },
    {
      "name": "Trauma & Accident Unit",
      "tag": "URGENT",
      "eta": 8,
      "price": 800.0,
      "icon": Icons.local_hospital,
      "color": const Color(0xFFF59E0B),
      "desc": "Spine Board, Vacuum Splints, Hemorrhage Control & Stretcher",
    },
    {
      "name": "Basic Life Support (BLS)",
      "tag": "STANDARD",
      "eta": 10,
      "price": 500.0,
      "icon": Icons.airport_shuttle,
      "color": const Color(0xFF0C831F),
      "desc": "Continuous Flow Oxygen, Stretcher, First Aid & EMT Attendant",
    },
    {
      "name": "Patient Wheelchair Transit",
      "tag": "NON-CRITICAL",
      "eta": 12,
      "price": 350.0,
      "icon": Icons.accessible,
      "color": const Color(0xFF2563EB),
      "desc": "Hydraulic Wheelchair Ramp, Comfortable Senior Transport",
    },
  ];

  // Medical Add-ons
  bool _addonOxygen = true;
  bool _addonStretcher = true;
  bool _addonParamedic = false;
  bool _addonWheelchair = false;

  // Destination Hospital
  dynamic _selectedHospital;

  // Active booking polling
  dynamic _activeBooking;
  Timer? _pollTimer;
  bool _isDispatching = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _fetchHospitals();
    _checkActiveBooking();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkActiveBooking());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sirenService.stopAndRelease();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _currentAddress = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)} (GPS Exact)";
          _isLocating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showTamilNaduLocationPicker() {
    final tnHubs = [
      {"name": "Dr. M.G.R. Chennai Central / Anna Salai", "address": "Park Town, Chennai, Tamil Nadu 600003", "lat": 13.0827, "lng": 80.2707},
      {"name": "T. Nagar / Panagal Park", "address": "T. Nagar, Chennai, Tamil Nadu 600017", "lat": 13.0418, "lng": 80.2341},
      {"name": "Guindy / Kathipara Junction", "address": "Guindy, Chennai, Tamil Nadu 600032", "lat": 13.0067, "lng": 80.2026},
      {"name": "Velachery / OMR IT Expressway", "address": "Velachery, Chennai, Tamil Nadu 600042", "lat": 12.9759, "lng": 80.2212},
      {"name": "Anna Nagar / Roundtana", "address": "Anna Nagar West, Chennai, Tamil Nadu 600040", "lat": 13.0850, "lng": 80.2100},
      {"name": "Gandhipuram / Cross Cut Road", "address": "Coimbatore, Tamil Nadu 641012", "lat": 11.0168, "lng": 76.9558},
      {"name": "Mattuthavani / Bus Terminal", "address": "Madurai, Tamil Nadu 625007", "lat": 9.9391, "lng": 78.1583},
      {"name": "Central Bus Stand / Cantonment", "address": "Tiruchirappalli, Tamil Nadu 620001", "lat": 10.7905, "lng": 78.7047},
      {"name": "Four Roads / Salem Junction", "address": "Salem, Tamil Nadu 636007", "lat": 11.6643, "lng": 78.1460},
      {"name": "Katpadi / Green Circle", "address": "Vellore, Tamil Nadu 632014", "lat": 12.9698, "lng": 79.1350},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_city, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                const Text("Select Tamil Nadu Location", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _fetchLocation();
                  },
                  icon: const Icon(Icons.my_location, size: 16, color: Color(0xFF10B981)),
                  label: const Text("LIVE GPS", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: tnHubs.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, i) {
                  final h = tnHubs[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.pin_drop, color: Color(0xFF10B981), size: 18),
                    ),
                    title: Text(h["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(h["address"] as String, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    onTap: () {
                      setState(() {
                        _lat = (h["lat"] as num).toDouble();
                        _lng = (h["lng"] as num).toDouble();
                        _currentAddress = h["address"] as String;
                      });
                      _fetchHospitals();
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchHospitals() async {
    try {
      final list = await _hospitalService.getHospitals(lat: _lat, lng: _lng);
      if (list.isNotEmpty) {
        setState(() {
          _selectedHospital = list.first;
        });
      }
    } catch (_) {}
  }

  Map<String, dynamic> _getStationedAmbulance(dynamic hospital) {
    if (hospital == null) {
      return {
        "vehicle": "TN-01-EM-1080",
        "medic": "M. Murugan",
        "type": "ALS ICU Unit",
        "phone": "+91 98765 43210",
      };
    }
    final int id = hospital["hospitalId"] ?? 1;
    switch (id) {
      case 1:
        return {"vehicle": "TN-01-EM-1080", "medic": "M. Murugan", "type": "ALS ICU Unit", "phone": "+91 98765 43210"};
      case 2:
        return {"vehicle": "TN-07-ICU-2026", "medic": "S. Selvam", "type": "Cardiac Life Support (ACLS)", "phone": "+91 98401 22334"};
      case 3:
        return {"vehicle": "TN-09-TR-1008", "medic": "K. Anbarasan", "type": "Trauma Life Support", "phone": "+91 97909 11223"};
      case 4:
        return {"vehicle": "TN-02-SR-1081", "medic": "P. Ramesh", "type": "BLS / ALS Rapid Unit", "phone": "+91 94441 55667"};
      case 5:
        return {"vehicle": "TN-05-SM-1085", "medic": "R. Vignesh", "type": "Critical Care ALS", "phone": "+91 99620 44332"};
      case 6:
        return {"vehicle": "TN-06-KH-1082", "medic": "V. Kumar", "type": "Critical Care Transit", "phone": "+91 98840 77889"};
      case 7:
        return {"vehicle": "TN-38-EM-1080", "medic": "R. Senthil", "type": "Coimbatore Ortho-Trauma", "phone": "+91 94430 88991"};
      case 8:
        return {"vehicle": "TN-58-EM-1080", "medic": "M. Pandian", "type": "Madurai Command ALS", "phone": "+91 98421 99002"};
      case 9:
        return {"vehicle": "TN-23-EM-1080", "medic": "D. Joshua", "type": "CMC Vellore Mobile ICU", "phone": "+91 94860 33445"};
      case 10:
        return {"vehicle": "TN-45-EM-1080", "medic": "G. Ravi", "type": "Trichy Cardiac Unit", "phone": "+91 97890 22331"};
      default:
        return {"vehicle": "TN-01-EM-1080", "medic": "108 Duty Paramedic", "type": "108 Emergency", "phone": "108"};
    }
  }

  Future<void> _checkActiveBooking() async {
    try {
      final list = await _bookingService.getUserBookings(widget.userId);
      if (list is List && list.isNotEmpty) {
        final ongoing = list.firstWhere(
          (b) => b["status"] == "Requested" || b["status"] == "Accepted" || b["status"] == "InProgress",
          orElse: () => null,
        );
        if (mounted) setState(() => _activeBooking = ongoing);
      }
    } catch (_) {}
  }

  double _calculateTotal() {
    double total = _fleetTiers[_selectedTierIndex]["price"];
    if (_addonOxygen) total += 150;
    if (_addonStretcher) total += 200;
    if (_addonParamedic) total += 300;
    if (_addonWheelchair) total += 100;
    return total;
  }

  String _getAddonsString() {
    List<String> items = [];
    if (_addonOxygen) items.add("Oxygen Cylinder");
    if (_addonStretcher) items.add("Folding Stretcher");
    if (_addonParamedic) items.add("Paramedic Doctor");
    if (_addonWheelchair) items.add("Wheelchair Access");
    return items.isEmpty ? "Standard Medical Kit" : items.join(", ");
  }

  Future<void> _dispatchBlinkitAmbulance({bool isSos = false}) async {
    if (_isDispatching) return;
    setState(() => _isDispatching = true);

    try {
      // Refresh live GPS with 2s timeout so SOS never blocks
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
            .timeout(const Duration(seconds: 2));
        _lat = pos.latitude;
        _lng = pos.longitude;
      } catch (_) {}

      final tier = _fleetTiers[_selectedTierIndex];

      // If SOS, also trigger EmergencyCoordinatorSession + Live Camera & Audio Relay to Driver
      if (isSos) {
        try {
          final session = await _coordinator.createEmergencySession(
            userId: widget.userId,
            victimName: widget.userName,
            victimPhone: "9840112233",
            contactName: "Emergency Family Contact",
            contactPhone: "9444011223",
            lat: _lat,
            lng: _lng,
          );
          _streamService.startLiveBroadcastWithRelay(
            emergencyId: session?.emergencyId ?? "SOS-LIVE",
            onAudioLevel: (_) {},
            onFrameCaptured: (_, __) {},
            onReady: (_, __) {},
          );
        } catch (_) {}
      }

      final res = await _bookingService.requestAmbulance(
        userId: widget.userId,
        pickupLat: _lat,
        pickupLng: _lng,
        destinationHospital: _selectedHospital != null
            ? _selectedHospital["name"]
            : "Rajiv Gandhi Govt General Hospital (RGGGH Trauma Care)",
        hospitalId: _selectedHospital != null ? _selectedHospital["hospitalId"] : null,
        patientCondition: isSos
            ? "[CODE RED - 1-TAP EMERGENCY SOS] Priority ICU Dispatch + Live Audio/Video Telemetry"
            : "[${tier["name"]}] ${_getAddonsString()}",
        estimatedPrice: isSos ? 1200.0 : _calculateTotal(),
        equipmentAddons: isSos
            ? "ICU Ventilator, Biphasic Defibrillator, Oxygen Cylinder, Paramedic Doctor"
            : _getAddonsString(),
        estimatedEtaMinutes: isSos ? 4 : (tier["eta"] ?? 8),
      );

      final bookingId = res["bookingId"] ?? 1;
      setState(() => _isDispatching = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isSos ? const Color(0xFFDC2626) : const Color(0xFF0C831F),
            content: Row(
              children: [
                const Icon(Icons.emergency_share, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSos
                        ? "🚨 EMERGENCY SOS DISPATCHED! ICU Ambulance & Live Video/Audio Active!"
                        : "Ambulance #${bookingId} Dispatched Successfully!",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrackingScreen(
              bookingId: bookingId,
              userId: widget.userId,
              onClose: _checkActiveBooking,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isDispatching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dispatch Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _triggerSosWithCountdown() async {
    // Immediately activate high-decibel emergency siren
    await _sirenService.startSiren();

    int count = 40; // 40-second SOS alarm standard
    Timer? t;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            t ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (count > 1) {
                setDialogState(() => count--);
              } else {
                timer.cancel();
                _sirenService.stopAndRelease();
                Navigator.pop(ctx);
                _dispatchBlinkitAmbulance(isSos: true);
              }
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: Color(0xFFEF4444), width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 2),
                      ),
                      child: const Icon(Icons.emergency, color: Color(0xFFEF4444), size: 46),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "🚨 EMERGENCY SOS ACTIVE",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Loud Siren Active • Auto-dispatching nearest 108 ICU unit & Live Video/Audio in $count seconds",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F1D1D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(
                        "${count}s",
                        style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.gps_fixed, color: Color(0xFF10B981), size: 15),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "GPS Locked: ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}",
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.videocam, color: Color(0xFF38BDF8), size: 15),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Camera & Mic Stream Ready for Driver & Family",
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 0s Instant Dispatch Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          t?.cancel();
                          _sirenService.stopAndRelease();
                          Navigator.pop(ctx);
                          _dispatchBlinkitAmbulance(isSos: true);
                        },
                        icon: const Icon(Icons.bolt, color: Colors.white, size: 22),
                        label: const Text(
                          "⚡ DISPATCH AMBULANCE NOW (0s)",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Direct Emergency Dialer & SMS Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => UrlLauncherService.openUrl("tel:108"),
                            icon: const Icon(Icons.phone_in_talk, size: 15, color: Color(0xFF34D399)),
                            label: const Text("CALL 108", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF34D399)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => UrlLauncherService.openUrl("tel:112"),
                            icon: const Icon(Icons.local_police, size: 15, color: Color(0xFF60A5FA)),
                            label: const Text("CALL 112", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF60A5FA)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final smsUrl = "sms:9444011223?body=${Uri.encodeComponent("EMERGENCY SOS! Need immediate ambulance at GPS: https://maps.google.com/?q=$_lat,$_lng")}";
                              UrlLauncherService.openUrl(smsUrl);
                            },
                            icon: const Icon(Icons.sms, size: 15, color: Colors.amber),
                            label: const Text("SOS SMS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.amber),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Cancel False Alarm Button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          t?.cancel();
                          _sirenService.stopAndRelease();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.volume_off, color: Colors.white70, size: 18),
                        label: const Text(
                          "🔇 CANCEL FALSE ALARM & STOP SIREN",
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTier = _fleetTiers[_selectedTierIndex];
    final totalCost = _calculateTotal();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          // 1. Signature Blinkit Header (Delivery Address + Lightning SLA)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C831F),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "⚡ ${selectedTier["eta"]} MINS ARRIVAL",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.car_crash_outlined, color: Colors.redAccent),
                          tooltip: "Crash & Impact Detection System",
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccidentDetectionScreen(userId: widget.userId))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.medical_services_outlined, color: Colors.white70),
                          tooltip: "First Aid Guides",
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FirstAidGuideScreen())),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history, color: Colors.white70),
                          tooltip: "Trip History",
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserHistoryScreen(userId: widget.userId))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person, color: Colors.white70),
                          tooltip: "Medical Profile",
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: widget.userId))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                          tooltip: "Sign Out",
                          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _fetchLocation,
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Delivering Medical Help to:",
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                            ),
                            Text(
                              _isLocating ? "Fetching live GPS coordinates..." : _currentAddress,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Active Incident Alert Banner (if booking in progress)
          if (_activeBooking != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emergency, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Active Emergency #${_activeBooking["bookingId"]}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                        Text("Status: ${_activeBooking["status"]} • En route", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map, color: Color(0xFF2563EB), size: 22),
                    tooltip: "Track in Google Maps",
                    onPressed: () {
                      final pLat = _activeBooking["pickupLatitude"] ?? _lat;
                      final pLng = _activeBooking["pickupLongitude"] ?? _lng;
                      final amb = _activeBooking["ambulance"];
                      final aLat = amb != null ? (amb["currentLatitude"] ?? 13.0850) : 13.0850;
                      final aLng = amb != null ? (amb["currentLongitude"] ?? 80.2720) : 80.2720;
                      final mapsUrl = "https://www.google.com/maps/dir/?api=1&origin=$aLat,$aLng&destination=$pLat,$pLng&travelmode=driving";
                      UrlLauncherService.openUrl(mapsUrl);
                    },
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackingScreen(
                          bookingId: _activeBooking["bookingId"],
                          userId: widget.userId,
                          onClose: _checkActiveBooking,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, visualDensity: VisualDensity.compact),
                    child: const Text("TRACK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),

          // 3. Main Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                // Upgraded Multi-Channel Emergency SOS Command Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF991B1B)]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _dispatchBlinkitAmbulance(isSos: true),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                              ),
                              child: const Icon(Icons.emergency_share, color: Color(0xFFDC2626), size: 30),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("🚨 1-TAP EMERGENCY SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                                SizedBox(height: 2),
                                Text("Instant ICU Dispatch • Live Camera/Audio • 40s Siren", style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _dispatchBlinkitAmbulance(isSos: true),
                            icon: const Icon(Icons.bolt, size: 16),
                            label: const Text("SOS NOW", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFB91C1C),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _triggerSosWithCountdown,
                              icon: const Icon(Icons.volume_up, size: 15, color: Colors.white),
                              label: const Text("40s SIREN ALARM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => UrlLauncherService.openUrl("tel:108"),
                              icon: const Icon(Icons.phone_in_talk, size: 15, color: Colors.white),
                              label: const Text("CALL 108", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final smsUrl = "sms:9444011223?body=${Uri.encodeComponent("EMERGENCY SOS! Need immediate ambulance at GPS: https://maps.google.com/?q=$_lat,$_lng")}";
                                UrlLauncherService.openUrl(smsUrl);
                              },
                              icon: const Icon(Icons.sms, size: 15, color: Colors.white),
                              label: const Text("SOS SMS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70),
                                padding: const EdgeInsets.symmetric(vertical: 6),
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

                // Crash & Impact Detector Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.car_crash, color: Colors.redAccent, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("CRASH & IMPACT SENSOR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("60s Loud Siren • SMS • Satellite SOS • Remote Unbook", style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AccidentDetectionScreen(userId: widget.userId)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("TEST SENSOR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Blinkit Quick Fleet Selector
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Select Ambulance Tier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
                    Text("Arriving in 6-12 mins", style: TextStyle(fontSize: 11, color: Color(0xFF0C831F), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),

                // Horizontal Fleet Carousel
                SizedBox(
                  height: 170,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fleetTiers.length,
                    itemBuilder: (context, index) {
                      final tier = _fleetTiers[index];
                      final isSelected = _selectedTierIndex == index;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedTierIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 220,
                          margin: const EdgeInsets.only(right: 12, bottom: 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0C831F) : Colors.grey.withOpacity(0.2),
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? const Color(0xFF0C831F).withOpacity(0.12) : Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (tier["color"] as Color).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(tier["icon"], color: tier["color"], size: 22),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "⚡ ${tier["eta"]} mins",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0C831F)),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                tier["name"],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tier["desc"],
                                style: const TextStyle(fontSize: 10, color: Colors.black54),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "₹${tier["price"].toInt()}",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF0C831F) : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isSelected ? "SELECTED" : "ADD",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Blinkit Medical Add-ons (Equipment Checklist)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.healing, color: Color(0xFF0C831F), size: 18),
                          SizedBox(width: 8),
                          Text("Medical Equipment & Add-ons", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildAddonTile("🤿 Medical Oxygen Cylinder", "+₹150", _addonOxygen, (v) => setState(() => _addonOxygen = v!)),
                      _buildAddonTile("🛏️ Folding Stretcher + 2 Attendants", "+₹200", _addonStretcher, (v) => setState(() => _addonStretcher = v!)),
                      _buildAddonTile("🩺 Certified Emergency Paramedic", "+₹300", _addonParamedic, (v) => setState(() => _addonParamedic = v!)),
                      _buildAddonTile("♿ Hydraulic Wheelchair Access", "+₹100", _addonWheelchair, (v) => setState(() => _addonWheelchair = v!)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Destination Hospital with live ICU bed indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_hospital, color: Color(0xFFDC2626), size: 18),
                              SizedBox(width: 8),
                              Text("Target Emergency Hospital", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const HospitalDirectoryScreen()),
                              );
                              if (picked != null) {
                                setState(() => _selectedHospital = picked);
                              }
                            },
                            child: const Text("CHANGE", style: TextStyle(color: Color(0xFF0C831F), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_selectedHospital != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.local_hospital, color: Color(0xFF0C831F), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_selectedHospital["name"] ?? "Hospital", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
                                        const SizedBox(height: 2),
                                        Text(
                                          "🟢 ${_selectedHospital["availableIcuBeds"] ?? 10} ICU Beds Available • ${_selectedHospital["distanceKm"] ?? "2.4"} km away",
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF0C831F), fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (_) {
                                  final amb = _getStationedAmbulance(_selectedHospital);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.emergency, color: Color(0xFF10B981), size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    amb["vehicle"] ?? "",
                                                    style: const TextStyle(fontFamily: "monospace", color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    "• ${amb["type"]}",
                                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                "Medic: ${amb["medic"]} (${amb["phone"]})",
                                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            if (_selectedHospital["latitude"] != null && _selectedHospital["longitude"] != null) {
                                              UrlLauncherService.openUrl(
                                                UrlLauncherService.getGoogleMapsPointUrl(
                                                  (_selectedHospital["latitude"] as num).toDouble(),
                                                  (_selectedHospital["longitude"] as num).toDouble(),
                                                ),
                                              );
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.map, size: 12, color: Colors.white),
                                                SizedBox(width: 4),
                                                Text("GPS", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalDirectoryScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.format_list_bulleted, size: 14, color: Color(0xFF0C831F)),
                                SizedBox(width: 6),
                                Text(
                                  "View All Tamil Nadu Hospitals & 108 Fleet →",
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C831F)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Emergency Tools Grid
                const Text("Emergency Response Features", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    _buildToolCard(
                      title: "First Aid Guides",
                      sub: "CPR & Choking Protocols",
                      icon: Icons.medical_services,
                      color: const Color(0xFF0C831F),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FirstAidGuideScreen())),
                    ),
                    _buildToolCard(
                      title: "Crash Detection",
                      sub: "Auto-Sensor & Siren",
                      icon: Icons.car_crash,
                      color: const Color(0xFFDC2626),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccidentDetectionScreen(userId: widget.userId))),
                    ),
                    _buildToolCard(
                      title: "ICU Bed Directory",
                      sub: "Nearby Medical Centers",
                      icon: Icons.local_hospital,
                      color: const Color(0xFF2563EB),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalDirectoryScreen())),
                    ),
                    _buildToolCard(
                      title: "Medical Profile",
                      sub: "Blood Group & Allergies",
                      icon: Icons.badge,
                      color: const Color(0xFF7C3AED),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: widget.userId))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),

      // 4. Floating Blinkit Bottom Dispatch Bar
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("₹${totalCost.toInt()}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                        child: const Text("SUBSIDIZED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0C831F))),
                      ),
                    ],
                  ),
                  Text("${selectedTier["name"]} • ⚡ ${selectedTier["eta"]} mins", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isDispatching ? null : () => _dispatchBlinkitAmbulance(),
                icon: _isDispatching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bolt, color: Colors.white, size: 20),
                label: Text(
                  _isDispatching ? "DISPATCHING..." : "DISPATCH IN ${selectedTier["eta"]} MINS",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C831F),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddonTile(String title, String price, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: value,
            activeColor: const Color(0xFF0C831F),
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
          ),
          Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0C831F))),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF111827))),
                  Text(sub, style: const TextStyle(fontSize: 9, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
