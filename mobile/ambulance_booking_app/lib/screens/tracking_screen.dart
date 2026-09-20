import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _TrackingScreenState extends State<TrackingScreen> {
  final BookingService _bookingService = BookingService();
  final AmbulanceService _ambulanceService = AmbulanceService();
  final EmergencySirenService _sirenService = EmergencySirenService();

  dynamic _booking;
  bool _isLoading = true;
  Timer? _pollTimer;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _fetchBooking();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchBooking());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sirenService.stopAndRelease();
    super.dispose();
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
    final eta = _booking["estimatedEtaMinutes"] ?? 8;
    final price = _booking["estimatedPrice"] ?? 650.0;
    final addons = _booking["equipmentAddons"] ?? "Oxygen, Stretcher";

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
            const Text("Live GPS Telemetry & Paramedic HUD", style: TextStyle(fontSize: 10, color: Color(0xFF10B981))),
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
                            status == "Completed" ? "DELIVERED AT HOSPITAL" : "⚡ ARRIVING IN $eta MINS",
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
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. 4-Stage Blinkit Delivery Stepper
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

          // 3. Paramedic & Ambulance Unit Card
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
                  // Live Distance & GPS Status Badge
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.satellite_alt, color: Color(0xFF0284C7), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Live GPS Beacon • ${_calculateDistanceKm(ambulance["currentLatitude"] ?? 13.0850, ambulance["currentLongitude"] ?? 80.2720, _booking["pickupLatitude"] ?? 13.0827, _booking["pickupLongitude"] ?? 80.2707).toStringAsFixed(2)} km away",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0369A1)),
                              ),
                              Text(
                                "Ambulance: ${(ambulance["currentLatitude"] ?? 13.0850).toStringAsFixed(4)}, ${(ambulance["currentLongitude"] ?? 80.2720).toStringAsFixed(4)}",
                                style: const TextStyle(fontSize: 10, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            "~${(_calculateDistanceKm(ambulance["currentLatitude"] ?? 13.0850, ambulance["currentLongitude"] ?? 80.2720, _booking["pickupLatitude"] ?? 13.0827, _booking["pickupLongitude"] ?? 80.2707) * 2.8).ceil().clamp(1, 45)} MINS",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final aLat = ambulance["currentLatitude"] ?? 13.0850;
                        final aLng = ambulance["currentLongitude"] ?? 80.2720;
                        final pLat = _booking["pickupLatitude"] ?? 13.0827;
                        final pLng = _booking["pickupLongitude"] ?? 80.2707;
                        final mapsUrl = "https://www.google.com/maps/dir/?api=1&origin=$aLat,$aLng&destination=$pLat,$pLng&travelmode=driving";
                        UrlLauncherService.openUrl(mapsUrl);
                      },
                      icon: const Icon(Icons.map, color: Colors.white, size: 18),
                      label: const Text(
                        "🗺️ TRACK AMBULANCE IN GOOGLE MAPS",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
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
                            final pLat = _booking["pickupLatitude"] ?? 13.0827;
                            final pLng = _booking["pickupLongitude"] ?? 80.2707;
                            UrlLauncherService.openUrl("https://maps.google.com/?q=$pLat,$pLng");
                          },
                          icon: const Icon(Icons.pin_drop, size: 14, color: Color(0xFF0C831F)),
                          label: const Text("MY PICKUP PIN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C831F))),
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
                            final pLat = _booking["pickupLatitude"] ?? 13.0827;
                            final pLng = _booking["pickupLongitude"] ?? 80.2707;
                            final hLat = hospital != null ? (hospital["latitude"] ?? 13.0805) : 13.0805;
                            final hLng = hospital != null ? (hospital["longitude"] ?? 80.2764) : 80.2764;
                            final hospRouteUrl = "https://www.google.com/maps/dir/?api=1&origin=$pLat,$pLng&destination=$hLat,$hLng&travelmode=driving";
                            UrlLauncherService.openUrl(hospRouteUrl);
                          },
                          icon: const Icon(Icons.local_hospital, size: 14, color: Color(0xFFDC2626)),
                          label: const Text("HOSPITAL ROUTE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDC2626)),
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

          // 4. Target Hospital Card with ICU Bed count
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
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Cancel Emergency Booking Button
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
