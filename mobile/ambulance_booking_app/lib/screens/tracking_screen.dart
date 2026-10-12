import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/booking_service.dart';
import '../services/ambulance_service.dart';
import '../services/emergency_siren_service.dart';
import '../services/url_launcher_service.dart';

class TrackingScreen extends StatefulWidget {
  final int bookingId;
  final int userId;
  final VoidCallback? onClose;

  const TrackingScreen({super.key, required this.bookingId, required this.userId, this.onClose});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final AmbulanceService _ambulanceService = AmbulanceService();
  final EmergencySirenService _sirenService = EmergencySirenService();

  dynamic _booking;
  bool _isLoading = true;
  Timer? _pollTimer;
  bool _isCancelling = false;

  // Live GPS tracking state
  double? _liveUserLat;
  double? _liveUserLng;
  double? _liveAccuracyMeters;
  bool _isGpsActive = false;
  bool _isCalibrating = false;
  StreamSubscription<Position>? _positionStreamSub;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fetchBooking();
    _initUserGpsTracking();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchBooking());
  }

  @override
  void dispose() {
    _radarController.dispose();
    _positionStreamSub?.cancel();
    _pollTimer?.cancel();
    _sirenService.stopAndRelease();
    super.dispose();
  }

  Future<void> _initUserGpsTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isGpsActive = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isGpsActive = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _liveUserLat = pos.latitude;
          _liveUserLng = pos.longitude;
          _liveAccuracyMeters = pos.accuracy;
          _isGpsActive = true;
        });
      }

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen(
        (Position newPos) {
          if (mounted) {
            setState(() {
              _liveUserLat = newPos.latitude;
              _liveUserLng = newPos.longitude;
              _liveAccuracyMeters = newPos.accuracy;
              _isGpsActive = true;
            });
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isGpsActive = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isGpsActive = false);
    }
  }

  Future<void> _calibrateGpsLocation() async {
    setState(() => _isCalibrating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw "Location services are turned off on your device. Please enable GPS.";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw "GPS permission was denied. Please allow location access in your browser/device.";
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _bookingService.updatePickupLocation(widget.bookingId, pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _liveUserLat = pos.latitude;
          _liveUserLng = pos.longitude;
          _liveAccuracyMeters = pos.accuracy;
          _isGpsActive = true;
          if (_booking != null) {
            _booking["pickupLatitude"] = pos.latitude;
            _booking["pickupLongitude"] = pos.longitude;
          }
          _isCalibrating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0C831F),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "🎯 Live GPS Calibrated! Paramedic unit routed to: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)} (±${pos.accuracy.toStringAsFixed(0)}m accuracy)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCalibrating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Calibration Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showChangeLocationDialog() {
    final tnHubs = [
      {"name": "Dr. M.G.R. Chennai Central / Anna Salai", "address": "Park Town, Chennai 600003", "lat": 13.0827, "lng": 80.2707},
      {"name": "T. Nagar / Panagal Park", "address": "T. Nagar, Chennai 600017", "lat": 13.0418, "lng": 80.2341},
      {"name": "Guindy / Kathipara Junction", "address": "Guindy, Chennai 600032", "lat": 13.0067, "lng": 80.2026},
      {"name": "Velachery / OMR IT Expressway", "address": "Velachery, Chennai 600042", "lat": 12.9759, "lng": 80.2212},
      {"name": "Anna Nagar / Roundtana", "address": "Anna Nagar West, Chennai 600040", "lat": 13.0850, "lng": 80.2100},
      {"name": "Tambaram Railway Station", "address": "Tambaram, Chennai 600045", "lat": 12.9249, "lng": 80.1290},
      {"name": "Gandhipuram / Cross Cut Road", "address": "Coimbatore 641012", "lat": 11.0168, "lng": 76.9558},
      {"name": "Mattuthavani / Bus Terminal", "address": "Madurai 625007", "lat": 9.9391, "lng": 78.1583},
      {"name": "Central Bus Stand / Cantonment", "address": "Tiruchirappalli 620001", "lat": 10.7905, "lng": 78.7047},
      {"name": "Four Roads / Salem Junction", "address": "Salem 636007", "lat": 11.6643, "lng": 78.1460},
      {"name": "Tirunelveli Junction", "address": "Tirunelveli 627001", "lat": 8.7274, "lng": 77.7088},
      {"name": "Katpadi / Green Circle", "address": "Vellore 632014", "lat": 12.9698, "lng": 79.1350},
    ];

    final currentLat = (_booking != null ? _booking["pickupLatitude"] : null) ?? _liveUserLat ?? 13.0827;
    final currentLng = (_booking != null ? _booking["pickupLongitude"] : null) ?? _liveUserLng ?? 80.2707;
    final latController = TextEditingController(text: currentLat.toString());
    final lngController = TextEditingController(text: currentLng.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.edit_location_alt, color: Color(0xFF0C831F), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Change Tracking GPS Pickup Point", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("Update where the ambulance responds to in real-time", style: TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Option 1: Use live device GPS
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _calibrateGpsLocation();
                },
                icon: const Icon(Icons.my_location, color: Colors.white, size: 18),
                label: Text(
                  _liveUserLat != null
                      ? "📍 USE MY PHONE GPS (${_liveUserLat!.toStringAsFixed(4)}, ${_liveUserLng!.toStringAsFixed(4)})"
                      : "📍 DETECT & USE CURRENT DEVICE GPS",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C831F),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Option 2: Custom coordinates
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Enter Exact Coordinates (Fine-Tune)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: "Latitude",
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: lngController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: "Longitude",
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final lat = double.tryParse(latController.text.trim());
                            final lng = double.tryParse(lngController.text.trim());
                            if (lat != null && lng != null) {
                              Navigator.pop(ctx);
                              await _applyNewPickupLocation(lat, lng, "Custom Coordinates");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Set", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Option 3: Major Tamil Nadu Emergency Hubs
              const Text("Quick Select: Tamil Nadu Emergency Hubs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tnHubs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final hub = tnHubs[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFECFDF5),
                        child: Icon(Icons.location_on, color: Color(0xFF0C831F), size: 18),
                      ),
                      title: Text(hub["name"] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        "${hub["address"]} • (${(hub["lat"] as double).toStringAsFixed(4)}, ${(hub["lng"] as double).toStringAsFixed(4)})",
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _applyNewPickupLocation(hub["lat"] as double, hub["lng"] as double, hub["name"] as String);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyNewPickupLocation(double lat, double lng, String label) async {
    setState(() => _isCalibrating = true);
    try {
      await _bookingService.updatePickupLocation(widget.bookingId, lat, lng);
      if (mounted) {
        setState(() {
          if (_booking != null) {
            _booking["pickupLatitude"] = lat;
            _booking["pickupLongitude"] = lng;
          }
          _isCalibrating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0C831F),
            content: Text("📍 Pickup location updated to: $label ($lat, $lng). Paramedic notified!"),
          ),
        );
        _fetchBooking();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCalibrating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update location: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final c = math.cos;
    final a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  Future<void> _fetchBooking() async {
    try {
      final data = await _bookingService.getBooking(widget.bookingId);
      if (data != null && data["ambulanceId"] != null) {
        try {
          final liveAmb = await _ambulanceService.getAmbulance(data["ambulanceId"]);
          if (liveAmb != null) {
            data["ambulance"] = liveAmb;
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _booking = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Cancel Emergency Dispatch?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to cancel this ambulance? The unit is already en route.", style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("NO, KEEP AMBULANCE", style: TextStyle(color: Color(0xFF10B981)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("YES, CANCEL DISPATCH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isCancelling = true);
      try {
        await _bookingService.cancelBooking(widget.bookingId);
        _sirenService.stopAndRelease();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Emergency dispatch cancelled."), backgroundColor: Colors.orange),
          );
          if (widget.onClose != null) widget.onClose!();
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() => _isCancelling = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  int _getStatusStep(String status) {
    switch (status) {
      case "Requested":
        return 0;
      case "Accepted":
        return 1;
      case "InProgress":
        return 2;
      case "Completed":
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF111827),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0C831F))),
      );
    }

    if (_booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Dispatch Details")),
        body: const Center(child: Text("Emergency booking record not found.")),
      );
    }

    final status = _booking["status"] ?? "Requested";
    final step = _getStatusStep(status);
    final ambulance = _booking["ambulance"];
    final hospital = _booking["hospital"];
    final price = _booking["estimatedPrice"] ?? 650.0;
    final addons = _booking["equipmentAddons"] ?? "Oxygen, Stretcher";

    // Coordinates
    final pickupLat = (_booking["pickupLatitude"] is num) ? (_booking["pickupLatitude"] as num).toDouble() : 13.0827;
    final pickupLng = (_booking["pickupLongitude"] is num) ? (_booking["pickupLongitude"] as num).toDouble() : 80.2707;
    final ambLat = (ambulance != null && ambulance["currentLatitude"] is num) ? (ambulance["currentLatitude"] as num).toDouble() : (pickupLat + 0.008);
    final ambLng = (ambulance != null && ambulance["currentLongitude"] is num) ? (ambulance["currentLongitude"] as num).toDouble() : (pickupLng + 0.006);
    final hospLat = (hospital != null && hospital["latitude"] is num) ? (hospital["latitude"] as num).toDouble() : 13.0805;
    final hospLng = (hospital != null && hospital["longitude"] is num) ? (hospital["longitude"] as num).toDouble() : 80.2764;

    final distanceToPickup = _calculateDistanceKm(ambLat, ambLng, pickupLat, pickupLng);
    final dynamicEta = (distanceToPickup * 2.8).ceil().clamp(1, 45);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (widget.onClose != null) widget.onClose!();
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Emergency #${widget.bookingId}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isGpsActive ? const Color(0xFF10B981) : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isGpsActive ? "Live GPS Connected • 100% Tracking" : "GPS Acquiring Satellites...",
                  style: TextStyle(fontSize: 10, color: _isGpsActive ? const Color(0xFF10B981) : Colors.amber),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_sirenService.isSirenActive ? Icons.volume_up : Icons.volume_off, color: _sirenService.isSirenActive ? Colors.red : Colors.white70),
            tooltip: "Toggle Audio Siren Alert",
            onPressed: () async {
              if (_sirenService.isSirenActive) {
                await _sirenService.stopSiren();
              } else {
                await _sirenService.startSiren();
              }
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white70),
            tooltip: "Share Live Tracking Link",
            onPressed: () {
              Clipboard.setData(ClipboardData(text: "EMERGENCY: Ambulance dispatched! Live Tracking URL: http://localhost:5000 (Booking #${widget.bookingId})"));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Tracking link copied to clipboard! Share on WhatsApp/SMS."), backgroundColor: Color(0xFF0C831F)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Big Blinkit ETA Hero Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: status == "Completed"
                    ? [const Color(0xFF065F46), const Color(0xFF047857)]
                    : [const Color(0xFF111827), const Color(0xFF1F2937)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == "Completed" ? const Color(0xFF10B981) : const Color(0xFF0C831F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            status == "Completed" ? "DELIVERED AT HOSPITAL" : "⚡ ARRIVING IN $dynamicEta MINS",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text("₹${price.toInt()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  status == "Requested"
                      ? "Finding & matching closest ambulance..."
                      : status == "Accepted"
                          ? "Paramedic unit accepted! Heading to your pickup location."
                          : status == "InProgress"
                              ? "Ambulance en route with emergency siren & live GPS priority."
                              : "Patient successfully handed over to Hospital Emergency Desk.",
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3),
                ),
                const SizedBox(height: 6),
                Text(
                  "Equipment on board: $addons",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                // Emergency SOS Quick Action Strip
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => UrlLauncherService.openUrl("tel:108"),
                        icon: const Icon(Icons.phone_in_talk, size: 14, color: Colors.white),
                        label: const Text("CALL 108", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => UrlLauncherService.openUrl("tel:112"),
                        icon: const Icon(Icons.local_police, size: 14, color: Colors.white),
                        label: const Text("CALL 112", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final smsUrl = "sms:9444011223?body=${Uri.encodeComponent("EMERGENCY SOS! Booking #${widget.bookingId} active at GPS: https://maps.google.com/?q=$pickupLat,$pickupLng")}";
                          UrlLauncherService.openUrl(smsUrl);
                        },
                        icon: const Icon(Icons.sms, size: 14, color: Colors.black87),
                        label: const Text("SOS SMS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
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
          const SizedBox(height: 16),

          // 2. EMBEDDED LIVE GPS RADAR & TACTICAL MAP WIDGET
          _buildLiveGpsRadarWidget(
            ambLat: ambLat,
            ambLng: ambLng,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            hospLat: hospLat,
            hospLng: hospLng,
            distanceKm: distanceToPickup,
            etaMins: dynamicEta,
            driverName: ambulance != null ? (ambulance["driverName"] ?? "Emergency Paramedic") : "Ambulance Unit",
            hospitalName: hospital != null ? (hospital["name"] ?? "Trauma Center") : "Trauma Center",
          ),
          const SizedBox(height: 16),

          // 3. 4-Stage Blinkit Delivery Stepper
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
                const Text("Dispatch Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                const SizedBox(height: 14),
                _buildProgressRow(0, step, "Emergency Order Dispatched", "Broadcasting to nearest emergency station"),
                _buildProgressRow(1, step, "Driver Assigned & En Route", "Ambulance responding with siren priority"),
                _buildProgressRow(2, step, "Patient Onboard / In Transit", "Heading towards destination hospital"),
                _buildProgressRow(3, step, "Arrived at Emergency Care", "Safe handover to emergency doctors", isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Paramedic & Ambulance Unit Card
          if (ambulance != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.airport_shuttle, color: Color(0xFF0C831F), size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ambulance["driverName"] ?? "Emergency Driver", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                  child: Text(ambulance["vehicleNumber"] ?? "TN01AB1234", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                                const Text(" 4.9 (1,240 trips)", style: TextStyle(fontSize: 11, color: Colors.black54)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Calling Paramedic: ${ambulance["driverPhone"] ?? "9876543210"}")),
                            );
                          },
                          icon: const Icon(Icons.phone, size: 16),
                          label: const Text("Call Driver", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0C831F),
                            side: const BorderSide(color: Color(0xFF0C831F)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (_sirenService.isSirenActive) {
                              await _sirenService.stopSiren();
                            } else {
                              await _sirenService.startSiren();
                            }
                            setState(() {});
                          },
                          icon: Icon(_sirenService.isSirenActive ? Icons.volume_off : Icons.volume_up, size: 16),
                          label: Text(_sirenService.isSirenActive ? "Stop Horn" : "Sound Horn", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _sirenService.isSirenActive ? Colors.red : const Color(0xFF111827),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Google Maps Nav Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final mapsUrl = "https://www.google.com/maps/dir/?api=1&origin=$ambLat,$ambLng&destination=$pickupLat,$pickupLng&travelmode=driving";
                        UrlLauncherService.openUrl(mapsUrl);
                      },
                      icon: const Icon(Icons.map, color: Colors.white, size: 18),
                      label: const Text(
                        "🗺️ OPEN LIVE TRACKING IN GOOGLE MAPS",
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
          const SizedBox(height: 16),

          // 5. Target Hospital Card
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
                    Icon(Icons.local_hospital, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Text("Destination Emergency Center", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  hospital != null ? hospital["name"] : (_booking["destinationHospital"] ?? "Nearest Trauma Center"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                ),
                if (hospital != null) ...[
                  const SizedBox(height: 4),
                  Text(hospital["address"] ?? "", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      "🟢 ${hospital["availableIcuBeds"] ?? 10} ICU Beds Ready & Prepared for Admission",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C831F)),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    final hospRouteUrl = "https://www.google.com/maps/dir/?api=1&origin=$pickupLat,$pickupLng&destination=$hospLat,$hospLng&travelmode=driving";
                    UrlLauncherService.openUrl(hospRouteUrl);
                  },
                  icon: const Icon(Icons.directions, size: 14, color: Color(0xFFDC2626)),
                  label: const Text("HOSPITAL TRAFFIC & ADMISSION ROUTE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    minimumSize: const Size(double.infinity, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 6. Cancel Emergency Booking Button
          if (status != "Completed" && status != "Cancelled")
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isCancelling ? null : _cancelBooking,
                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                label: Text(
                  _isCancelling ? "Cancelling..." : "Cancel Emergency Dispatch",
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // WIDGET: Tactical GPS Radar & Live Map Canvas
  Widget _buildLiveGpsRadarWidget({
    required double ambLat,
    required double ambLng,
    required double pickupLat,
    required double pickupLng,
    required double hospLat,
    required double hospLng,
    required double distanceKm,
    required int etaMins,
    required String driverName,
    required String hospitalName,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // Radar Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C831F).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.radar, color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "LIVE GPS RADAR & VEHICLE TRACKER",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                      ),
                      Text(
                        "Real-time satellite coordinates & dynamic route",
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isGpsActive ? const Color(0xFF065F46) : const Color(0xFF78350F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isGpsActive ? const Color(0xFF10B981) : Colors.amber, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isGpsActive ? const Color(0xFF34D399) : Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isGpsActive ? "GPS LOCKED" : "SEEKING",
                        style: TextStyle(
                          color: _isGpsActive ? const Color(0xFF34D399) : Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Radar Canvas
          ClipRRect(
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _radarController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: TacticalRadarMapPainter(
                      radarProgress: _radarController.value,
                      ambLat: ambLat,
                      ambLng: ambLng,
                      pickupLat: pickupLat,
                      pickupLng: pickupLng,
                      hospLat: hospLat,
                      hospLng: hospLng,
                      liveUserLat: _liveUserLat,
                      liveUserLng: _liveUserLng,
                      distanceKm: distanceKm,
                    ),
                  );
                },
              ),
            ),
          ),

          // Telemetry details bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pin_drop, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 4),
                          const Text("PICKUP:", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text(
                            "${pickupLat.toStringAsFixed(4)}, ${pickupLng.toStringAsFixed(4)}",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.airport_shuttle, color: Color(0xFF38BDF8), size: 14),
                          const SizedBox(width: 4),
                          const Text("AMBULANCE:", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text(
                            "${ambLat.toStringAsFixed(4)}, ${ambLng.toStringAsFixed(4)}",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981), width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "${distanceKm.toStringAsFixed(2)} km",
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        "ETA ~$etaMins mins",
                        style: const TextStyle(color: Colors.white70, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Toolbar: Calibrate & Change Location buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCalibrating ? null : _calibrateGpsLocation,
                    icon: _isCalibrating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.gps_fixed, size: 15, color: Colors.white),
                    label: Text(
                      _isCalibrating ? "Syncing..." : "🎯 Calibrate GPS",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C831F),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showChangeLocationDialog,
                    icon: const Icon(Icons.edit_location_alt, size: 15, color: Colors.white),
                    label: const Text(
                      "📍 Change Location",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(int index, int currentStep, String title, String subtitle, {bool isLast = false}) {
    final isDone = index <= currentStep;
    final isCurrent = index == currentStep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? const Color(0xFF0C831F) : Colors.grey[200],
                border: isCurrent ? Border.all(color: const Color(0xFF10B981), width: 3) : null,
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Center(child: Text("${index + 1}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isDone ? const Color(0xFF0C831F) : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                  color: isDone ? const Color(0xFF111827) : Colors.grey,
                ),
              ),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

// Tactical Radar Map Custom Painter
class TacticalRadarMapPainter extends CustomPainter {
  final double radarProgress; // 0.0 to 1.0
  final double ambLat;
  final double ambLng;
  final double pickupLat;
  final double pickupLng;
  final double hospLat;
  final double hospLng;
  final double? liveUserLat;
  final double? liveUserLng;
  final double distanceKm;

  TacticalRadarMapPainter({
    required this.radarProgress,
    required this.ambLat,
    required this.ambLng,
    required this.pickupLat,
    required this.pickupLng,
    required this.hospLat,
    required this.hospLng,
    this.liveUserLat,
    this.liveUserLng,
    required this.distanceKm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Dark radar background with subtle circular grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar rings
    final maxRadius = math.min(w, h) * 0.45;
    for (double r = 0.25; r <= 1.0; r += 0.25) {
      canvas.drawCircle(center, maxRadius * r, gridPaint);
    }

    // Crosshairs
    final crossPaint = Paint()
      ..color = const Color(0xFF334155).withOpacity(0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), crossPaint);
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), crossPaint);

    // 2. Animated radar sweep line
    final sweepAngle = radarProgress * 2 * math.pi;
    final sweepEnd = Offset(
      center.dx + maxRadius * math.cos(sweepAngle),
      center.dy + maxRadius * math.sin(sweepAngle),
    );

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.4,
        endAngle: sweepAngle,
        colors: [
          Colors.transparent,
          const Color(0xFF10B981).withOpacity(0.25),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      sweepAngle - 0.4,
      0.4,
      true,
      sweepPaint,
    );

    final sweepLinePaint = Paint()
      ..color = const Color(0xFF34D399).withOpacity(0.7)
      ..strokeWidth = 1.5;
    canvas.drawLine(center, sweepEnd, sweepLinePaint);

    // 3. Coordinate normalization onto 2D canvas
    final lats = [ambLat, pickupLat, hospLat];
    final lngs = [ambLng, pickupLng, hospLng];
    if (liveUserLat != null) lats.add(liveUserLat!);
    if (liveUserLng != null) lngs.add(liveUserLng!);

    double minLat = lats.reduce(math.min);
    double maxLat = lats.reduce(math.max);
    double minLng = lngs.reduce(math.min);
    double maxLng = lngs.reduce(math.max);

    // Keep minimum span so markers don't overlap if points are too close
    final latSpan = math.max(maxLat - minLat, 0.008);
    final lngSpan = math.max(maxLng - minLng, 0.008);
    final midLat = (maxLat + minLat) / 2;
    final midLng = (maxLng + minLng) / 2;

    minLat = midLat - latSpan * 0.7;
    maxLat = midLat + latSpan * 0.7;
    minLng = midLng - lngSpan * 0.7;
    maxLng = midLng + lngSpan * 0.7;

    const pad = 42.0;
    Offset toCanvas(double lat, double lng) {
      final nx = (lng - minLng) / (maxLng - minLng);
      final ny = (maxLat - lat) / (maxLat - minLat);
      return Offset(
        pad + nx * (w - 2 * pad),
        pad + ny * (h - 2 * pad),
      );
    }

    final pPickup = toCanvas(pickupLat, pickupLng);
    final pAmb = toCanvas(ambLat, ambLng);
    final pHosp = toCanvas(hospLat, hospLng);
    final pLive = (liveUserLat != null && liveUserLng != null) ? toCanvas(liveUserLat!, liveUserLng!) : null;

    // 4. Route Polyline (Ambulance -> Pickup -> Hospital)
    final routePaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dashPath = Path();
    dashPath.moveTo(pAmb.dx, pAmb.dy);
    dashPath.lineTo(pPickup.dx, pPickup.dy);
    canvas.drawPath(dashPath, routePaint);

    final hospRoutePaint = Paint()
      ..color = const Color(0xFFF43F5E).withOpacity(0.4)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final hospPath = Path();
    hospPath.moveTo(pPickup.dx, pPickup.dy);
    hospPath.lineTo(pHosp.dx, pHosp.dy);
    canvas.drawPath(hospPath, hospRoutePaint);

    // 5. Pulsing sonar waves at Pickup / User position
    final pulseRadius = 12.0 + (radarProgress * 16.0);
    final pulseAlpha = ((1.0 - radarProgress) * 200).toInt().clamp(0, 255);
    final pulsePaint = Paint()
      ..color = const Color(0xFF10B981).withAlpha(pulseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(pPickup, pulseRadius, pulsePaint);

    // 6. Draw Hospital Pin
    _drawMarker(
      canvas,
      pHosp,
      Icons.local_hospital,
      const Color(0xFFEF4444),
      "HOSPITAL",
      isEmergency: true,
    );

    // 7. Draw Ambulance Pin (Moving)
    final ambSirenAlpha = ((math.sin(radarProgress * 2 * math.pi) * 0.5 + 0.5) * 180).toInt().clamp(0, 255);
    final ambSirenPaint = Paint()
      ..color = const Color(0xFF0284C7).withAlpha(ambSirenAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(pAmb, 14.0, ambSirenPaint);

    _drawMarker(
      canvas,
      pAmb,
      Icons.airport_shuttle,
      const Color(0xFF0284C7),
      "AMBULANCE (${distanceKm.toStringAsFixed(1)}km)",
    );

    // 8. Draw Pickup Location Pin
    _drawMarker(
      canvas,
      pPickup,
      Icons.person_pin_circle,
      const Color(0xFF10B981),
      "PICKUP POINT",
    );

    // 9. If live phone GPS is different from pickup, show live phone marker
    if (pLive != null && (pLive - pPickup).distance > 15) {
      _drawMarker(
        canvas,
        pLive,
        Icons.my_location,
        const Color(0xFFF59E0B),
        "YOU (PHONE GPS)",
      );
    }
  }

  void _drawMarker(Canvas canvas, Offset pos, IconData icon, Color color, String label, {bool isEmergency = false}) {
    // Glow halo
    final glow = Paint()
      ..color = color.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(pos, 12, glow);

    // Center disc
    final disc = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 8, disc);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pos, 8, border);

    // Label tag
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.85),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy + 11),
    );
  }

  @override
  bool shouldRepaint(covariant TacticalRadarMapPainter oldDelegate) {
    return oldDelegate.radarProgress != radarProgress ||
        oldDelegate.ambLat != ambLat ||
        oldDelegate.ambLng != ambLng ||
        oldDelegate.pickupLat != pickupLat ||
        oldDelegate.pickupLng != pickupLng ||
        oldDelegate.liveUserLat != liveUserLat ||
        oldDelegate.liveUserLng != liveUserLng;
  }
}
