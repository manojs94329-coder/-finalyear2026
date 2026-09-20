import 'dart:async';
import 'package:flutter/material.dart';
import '../services/emergency_coordinator_service.dart';
import '../services/url_launcher_service.dart';
import '../widgets/live_video_viewfinder.dart';
import '../widgets/live_stream_receiver.dart';

class EmergencyRemoteUnbookScreen extends StatefulWidget {
  final String emergencyId;

  const EmergencyRemoteUnbookScreen({super.key, required this.emergencyId});

  @override
  State<EmergencyRemoteUnbookScreen> createState() => _EmergencyRemoteUnbookScreenState();
}

class _EmergencyRemoteUnbookScreenState extends State<EmergencyRemoteUnbookScreen> {
  final EmergencyCoordinatorService _coordinator = EmergencyCoordinatorService();
  EmergencySessionData? _session;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadEmergencyDetails();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadEmergencyDetails(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEmergencyDetails({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final session = await _coordinator.fetchEmergencySession(widget.emergencyId);
    if (mounted) {
      setState(() {
        _session = session;
        _isLoading = false;
        if (session == null && !silent) {
          _errorMessage = "Emergency session '${widget.emergencyId}' not found.";
        }
      });
    }
  }

  Future<void> _handleRemoteUnbook() async {
    final reasonController = TextEditingController(text: "False alarm - victim is safe with me.");
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text("Confirm Remote Unbook", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you sure you want to cancel this emergency? This will immediately stop the victim's emergency siren and stand down responders.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Cancellation Reason",
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("GO BACK", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("CONFIRM & STOP ALARM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    setState(() => _isSubmitting = true);
    final success = await _coordinator.cancelEmergencyRemotely(
      emergencyId: widget.emergencyId,
      cancelledBy: "SecondaryUser",
      reason: reasonController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Emergency cancelled remotely. Victim siren stopped."),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadEmergencyDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to cancel emergency. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = _session?.status.contains("CANCELLED") == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Emergency Secondary Portal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(onPressed: _loadEmergencyDetails, child: const Text("RETRY")),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Container(
                      constraints: const Duration(milliseconds: 100) == const Duration(milliseconds: 100)
                          ? const BoxConstraints(maxWidth: 600)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Status Banner
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isCancelled ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCancelled ? const Color(0xFF10B981) : Colors.redAccent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCancelled ? Icons.check_circle : Icons.emergency,
                                  color: isCancelled ? const Color(0xFF34D399) : Colors.white,
                                  size: 40,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isCancelled ? "EMERGENCY CANCELLED" : "ACTIVE CRASH ALERT!",
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isCancelled
                                            ? "Cancelled by: ${_session?.cancelledBy ?? 'Secondary Contact'} (${_session?.cancellationReason ?? 'Safe'})"
                                            : "Impact detected. Loud siren active on victim device.",
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Victim Details Card
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("VICTIM TELEMETRY", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                const SizedBox(height: 12),
                                _buildDetailRow(Icons.person, "Victim", _session?.victimName ?? "Unknown"),
                                const Divider(color: Colors.white10, height: 18),
                                _buildDetailRow(Icons.pin_drop, "Coordinates", "${_session?.latitude.toStringAsFixed(4)}, ${_session?.longitude.toStringAsFixed(4)}"),
                                const Divider(color: Colors.white10, height: 18),
                                _buildDetailRow(
                                  Icons.battery_charging_full,
                                  "Device Battery",
                                  "${_session?.batteryLevel}% ${_session?.isCriticalBattery == true ? '[CRITICAL LOW]' : ''}",
                                  valueColor: _session?.isCriticalBattery == true ? Colors.orangeAccent : const Color(0xFF10B981),
                                ),
                                const Divider(color: Colors.white10, height: 18),
                                _buildDetailRow(
                                  Icons.satellite_alt,
                                  "Transmission",
                                  _session?.transmissionPath.replaceAll('_', ' ') ?? 'Cellular Data',
                                  valueColor: const Color(0xFF60A5FA),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Interactive Live GPS Google Maps Tracking Card
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
                                      child: const Icon(Icons.satellite_alt, color: Color(0xFF38BDF8), size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("LIVE SATELLITE & GPS TRACKING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text("Real-time telemetry synchronized with ambulance fleet", style: TextStyle(color: Colors.white60, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                                          SizedBox(width: 4),
                                          Text("LIVE BEACON", style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Route coordinates info
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.person_pin_circle, color: Colors.redAccent, size: 20),
                                          const SizedBox(width: 8),
                                          const Text("Victim Crash Site (TN):", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                          const Spacer(),
                                          Text(
                                            "Anna Salai (${_session?.latitude.toStringAsFixed(4) ?? '13.0827'}, ${_session?.longitude.toStringAsFixed(4) ?? '80.2707'})",
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      const Divider(color: Colors.white10, height: 16),
                                      Row(
                                        children: [
                                          const Icon(Icons.airport_shuttle, color: Color(0xFF10B981), size: 20),
                                          const SizedBox(width: 8),
                                          const Text("Ambulance Unit:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                          const Spacer(),
                                          const Text(
                                            "TN-01-EM-1080 (108 Chennai ICU)",
                                            style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Google Maps Launch Buttons
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final victimLat = _session?.latitude ?? 13.0827;
                                      final victimLng = _session?.longitude ?? 80.2707;
                                      // Launch Google Maps Driving Route from responding ambulance to victim
                                      final mapsUrl = "https://www.google.com/maps/dir/?api=1&origin=13.0850,80.2720&destination=$victimLat,$victimLng&travelmode=driving";
                                      UrlLauncherService.openUrl(mapsUrl);
                                    },
                                    icon: const Icon(Icons.map_outlined, color: Colors.white),
                                    label: const Text(
                                      "🗺️ OPEN LIVE ROUTE IN GOOGLE MAPS",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          final victimLat = _session?.latitude ?? 13.0827;
                                          final victimLng = _session?.longitude ?? 80.2707;
                                          final pointUrl = "https://maps.google.com/?q=$victimLat,$victimLng";
                                          UrlLauncherService.openUrl(pointUrl);
                                        },
                                        icon: const Icon(Icons.pin_drop, size: 16, color: Colors.redAccent),
                                        label: const Text("CRASH SITE PIN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.redAccent),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          final agoraUrl = _session?.agoraStreamUrl ?? "https://emergency-agora.stream/room/auto";
                                          UrlLauncherService.openUrl(agoraUrl);
                                        },
                                        icon: const Icon(Icons.videocam, size: 16, color: Color(0xFF38BDF8)),
                                        label: const Text("JOIN AGORA LIVE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFF38BDF8)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Live Video & Audio Feed Card for Secondary User
                          if (!isCancelled) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.videocam, color: Colors.redAccent, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        "LIVE CRASH SCENE VIDEO & AUDIO",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                                      ),
                                      Spacer(),
                                      Text("STREAM ACTIVE", style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  LiveStreamReceiver(
                                    emergencyId: widget.emergencyId,
                                    callerRole: "SECONDARY CONTACT PORTAL",
                                    locationText: "Victim Crash Site • Anna Salai, Chennai",
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // Large Unbook / Cancel Button
                          if (!isCancelled)
                            SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _handleRemoteUnbook,
                                icon: _isSubmitting
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.cancel, size: 24),
                                label: Text(
                                  _isSubmitting ? "CANCELLING..." : "UNBOOK / CANCEL EMERGENCY (FALSE ALARM)",
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 4,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF10B981)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.verified, color: Color(0xFF10B981), size: 36),
                                  SizedBox(height: 8),
                                  Text(
                                    "Emergency Successfully Stood Down",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Victim device siren has been silenced and audio resources released.",
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white54),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
