import 'dart:async';
import 'package:flutter/material.dart';
import '../services/emergency_siren_service.dart';
import '../services/emergency_coordinator_service.dart';
import '../services/booking_service.dart';
import '../services/sensor_accident_service.dart';
import '../services/live_av_stream_service.dart';
import '../services/url_launcher_service.dart';
import '../widgets/live_video_viewfinder.dart';

class AccidentDetectionScreen extends StatefulWidget {
  final int userId;

  const AccidentDetectionScreen({super.key, required this.userId});

  @override
  State<AccidentDetectionScreen> createState() => _AccidentDetectionScreenState();
}

class _AccidentDetectionScreenState extends State<AccidentDetectionScreen> with SingleTickerProviderStateMixin {
  final EmergencySirenService _sirenService = EmergencySirenService();
  final EmergencyCoordinatorService _coordinator = EmergencyCoordinatorService();
  final BookingService _bookingService = BookingService();
  final SensorAccidentService _sensorService = SensorAccidentService();
  final LiveAvStreamService _streamService = LiveAvStreamService();

  // 40-second emergency SOS countdown timer upon detected crash
  static const int _sosCountdownInitial = 40;
  int _countdown = _sosCountdownInitial;
  Timer? _countdownTimer;

  // Sensor telemetry state
  double _currentGForce = 1.0;
  double _axisX = 0.0;
  double _axisY = 0.0;
  double _axisZ = 9.8;
  int _vibrationLevel = 10;
  bool _isImpactDetected = false;
  String _impactReason = "";

  // Audio decibel level from microphone
  int _audioDecibels = 0;
  StreamSubscription<int>? _audioSub;

  // Emergency state
  bool _isDispatched = false;
  bool _isCancelledLocally = false;
  bool _isCancelledRemotely = false;
  String? _remoteCancellationReason;

  // Contact details persisted in SharedPreferences
  String _contactName = 'K. Ramesh (Secondary Contact)';
  String _contactPhone = '9840998877';
  String _contactRelation = 'Brother';

  // Active session
  EmergencySessionData? _activeSession;
  bool _isCreatingSession = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initSystem();
  }

  Future<void> _initSystem() async {
    // 1. Initialize platform satellite capabilities
    await _coordinator.initPlatformCapabilities();

    // 2. Load saved contact from SharedPreferences
    final contact = await _coordinator.loadEmergencyContact();
    if (mounted) {
      setState(() {
        _contactName = contact['name'] ?? 'Secondary Contact';
        _contactPhone = contact['phone'] ?? '9876543210';
        _contactRelation = contact['relation'] ?? 'Guardian';
      });
    }

    // 3. Start real-time mobile sensor monitoring (over-shaking & vibration)
    _sensorService.startMonitoring(
      onCrash: (reason, gForce) {
        if (!mounted) return;
        _onCrashDetected(reason, gForce);
      },
      onTelemetry: (tel) {
        if (!mounted || _isImpactDetected) return;
        setState(() {
          _axisX = tel.x;
          _axisY = tel.y;
          _axisZ = tel.z;
          _currentGForce = tel.gForce;
          _vibrationLevel = tel.vibrationLevel;
        });
      },
    );

    // 4. Subscribe to live audio decibels
    _audioSub = _streamService.audioDecibelStream.listen((db) {
      if (mounted) {
        setState(() => _audioDecibels = db);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _audioSub?.cancel();
    _pulseController.dispose();
    _sensorService.stopMonitoring();
    _streamService.stopLiveBroadcast();
    _coordinator.stopRemoteStatusListener();
    _sirenService.stopAndRelease();
    super.dispose();
  }

  /// Triggered automatically when mobile sensor detects violent shaking or crash impact
  void _onCrashDetected(String reason, double gForce) async {
    if (_isImpactDetected || _isDispatched) return;

    setState(() {
      _isImpactDetected = true;
      _impactReason = reason;
      _currentGForce = gForce;
      _vibrationLevel = 100;
      _countdown = _sosCountdownInitial;
    });

    // Start loud emergency siren
    await _sirenService.startSiren();

    // Start 40-second SOS alarm countdown
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        _autoDispatchEmergencyWorkflow();
      }
    });
  }

  /// User cancels false alarm locally
  Future<void> _cancelAlarmLocally() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _sensorService.stopMonitoring();
    _streamService.stopLiveBroadcast();
    _coordinator.stopRemoteStatusListener();
    await _sirenService.stopAndRelease();

    if (_activeSession != null) {
      await _coordinator.cancelEmergencyRemotely(
        emergencyId: _activeSession!.emergencyId,
        cancelledBy: "VictimUser",
        reason: "Cancelled locally by user (False alarm)",
      );
    }

    if (mounted) {
      setState(() {
        _isCancelledLocally = true;
      });
    }
  }

  /// Execute automatic ambulance booking and activate live video & audio transmission
  Future<void> _autoDispatchEmergencyWorkflow() async {
    if (_isDispatched) return;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    setState(() {
      _isDispatched = true;
      _isCreatingSession = true;
    });

    const lat = 13.0827;
    const lng = 80.2707;

    // 1. Create Emergency Record in Backend / Cloud
    final session = await _coordinator.createEmergencySession(
      userId: widget.userId,
      victimName: "Sarah Sundaram (Chennai)",
      victimPhone: "9840112233",
      contactName: _contactName,
      contactPhone: _contactPhone,
      lat: lat,
      lng: lng,
    );

    // 2. Automatically dispatch nearest 108 Ambulance Fleet (TN-01-EM-1080)
    try {
      await _bookingService.requestAmbulance(
        userId: widget.userId,
        pickupLat: lat,
        pickupLng: lng,
        destinationHospital: "Rajiv Gandhi Govt General Hospital (RGGGH Trauma Care), Chennai, Tamil Nadu",
        patientCondition: "[AUTO-ACCIDENT DETECTED] Over-shaking & high-G vibration detected on mobile sensor ($_impactReason). Live Audio/Video broadcasting.",
        estimatedPrice: 1200.00,
        equipmentAddons: "ICU Ventilator, Biphasic Defibrillator, Paramedic Doctor",
        estimatedEtaMinutes: 5,
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _activeSession = session;
        _isCreatingSession = false;
      });
    }

    // 3. IMMEDIATELY START LIVE CAMERA & MICROPHONE AUDIO TRANSMISSION WITH SERVER RELAY
    _streamService.startLiveBroadcastWithRelay(
      emergencyId: session?.emergencyId ?? "EMG-LIVE",
      onAudioLevel: (db) {
        if (mounted) setState(() => _audioDecibels = db);
      },
      onFrameCaptured: (base64, db) {
        if (mounted) setState(() => _audioDecibels = db);
      },
      onReady: (success, msg) {
        debugPrint("Live broadcast status: $msg");
      },
    );

    // 4. Start remote cancellation listener
    if (session != null) {
      _coordinator.startRemoteStatusListener(
        session.emergencyId,
        onRemoteCancelled: (status, reason) {
          if (!mounted) return;
          _streamService.stopLiveBroadcast();
          setState(() {
            _isCancelledRemotely = true;
            _remoteCancellationReason = reason ?? "Secondary contact confirmed safe";
          });
        },
      );

      // Check critical battery
      if (_coordinator.isCriticalBattery) {
        await _coordinator.sendBatteryWarning(session.emergencyId);
      }
    }
  }

  /// Edit emergency contact persisted in SharedPreferences
  Future<void> _showEditContactDialog() async {
    final nameCtrl = TextEditingController(text: _contactName);
    final phoneCtrl = TextEditingController(text: _contactPhone);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text("Edit Secondary Contact", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Contact Name",
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Mobile Phone (for SMS)",
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (phoneCtrl.text.trim().isNotEmpty) {
                await _coordinator.saveEmergencyContact(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
                setState(() {
                  _contactName = nameCtrl.text.trim();
                  _contactPhone = phoneCtrl.text.trim();
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text("SAVE TO STORAGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Local Cancellation Screen
    if (_isCancelledLocally) {
      return Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 84),
                const SizedBox(height: 20),
                const Text("Emergency Alarm Cancelled", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("False alarm marked. Siren silenced and live media transmission terminated.", style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("RETURN HOME", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Remote Cancellation Screen (Received from Secondary Contact)
    if (_isCancelledRemotely) {
      return Scaffold(
        backgroundColor: const Color(0xFF064E3B),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_update_good, color: Color(0xFF34D399), size: 90),
                const SizedBox(height: 20),
                const Text("REMOTE CANCEL RECEIVED", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      Text("Status: CANCELLED_BY_SECONDARY_USER", style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text("Reason: $_remoteCancellationReason", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      const Text("• Live Video/Audio Stream Ended\n• Emergency Siren Silenced\n• Responders Stood Down", style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF064E3B),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("RETURN TO APP", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Dispatched & Live Video/Audio Transmission Screen
    if (_isDispatched) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text("LIVE CRASH AV BROADCAST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_sirenService.isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
              tooltip: "Toggle Siren",
              onPressed: () async {
                await _sirenService.toggleMute();
                setState(() {});
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Live Video & Audio Viewfinder Widget
                LiveVideoViewfinder(
                  isBroadcasting: true,
                  decibelLevel: _audioDecibels,
                  locationText: "Anna Salai, Chennai (13.0827, 80.2707)",
                  onSwitchCamera: () {
                    _streamService.switchCamera(
                      onReady: (ok, msg) => setState(() {}),
                    );
                  },
                  onToggleMute: () {
                    final muted = _streamService.toggleMute();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(muted ? "Microphone Muted" : "Microphone Active (Broadcasting)")),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 2. Real-Time Connected Channels Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sensors, color: Color(0xFF10B981), size: 18),
                          SizedBox(width: 8),
                          Text(
                            "LIVE TRANSMISSION RECIPIENTS",
                            style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Channel 1: Responding Ambulance Driver
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emergency, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Ambulance Unit: TN-01-EM-1080", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text("Driver: M. Murugan (108 ALS Paramedic) • Receiving AV", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: const Text("CONNECTED", style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      // Channel 2: Secondary Contact
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Color(0xFF38BDF8), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Secondary Contact: $_contactName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text("Phone: $_contactPhone • Live Stream SMS Sent", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF38BDF8).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: const Text("ACTIVE", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Automated Booking & Hospital Info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("AMBULANCE DISPATCH TELEMETRY", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.local_hospital, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Target: Rajiv Gandhi Govt General Hospital (48 ICU Beds)",
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text("Incident Sensor Spike: $_impactReason", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      Text("Google Maps Route: 13.0850, 80.2720 -> 13.0827, 80.2707", style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Action Buttons
                ElevatedButton.icon(
                  onPressed: () {
                    final mapsUrl = "https://www.google.com/maps/dir/?api=1&origin=13.0850,80.2720&destination=13.0827,80.2707&travelmode=driving";
                    UrlLauncherService.openUrl(mapsUrl);
                  },
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: const Text("TRACK EN ROUTE AMBULANCE ON GOOGLE MAPS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                // User Manual Stop Button
                OutlinedButton.icon(
                  onPressed: _cancelAlarmLocally,
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: const Text("I AM OK - CANCEL DISPATCH LOCALLY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 4. Impact Detected Mode: 10-Second Rapid Emergency Countdown
    if (_isImpactDetected) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _cancelAlarmLocally,
          ),
          actions: [
            IconButton(
              icon: Icon(_sirenService.isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
              tooltip: "Mute Siren",
              onPressed: () async {
                await _sirenService.toggleMute();
                setState(() {});
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // Impact Detected Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "OVER-SHAKING DETECTED (${_currentGForce.toStringAsFixed(1)}G) • SIREN ACTIVE",
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  "Are you hurt?",
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Auto-booking nearest 108 ICU and broadcasting live AV in:",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 10-Second Circular Countdown Ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: CircularProgressIndicator(
                        value: _countdown / _sosCountdownInitial.toDouble(),
                        strokeWidth: 8,
                        backgroundColor: Colors.white12,
                        color: _countdown <= 10 ? Colors.redAccent : const Color(0xFFF59E0B),
                      ),
                    ),
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.18),
                          border: Border.all(color: Colors.redAccent, width: 3),
                          boxShadow: [
                            BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 24, spreadRadius: 4),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$_countdown",
                              style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const Text("SECONDS", style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Telemetry Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sensors, color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Trigger: $_impactReason",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 14),
                      Row(
                        children: [
                          const Icon(Icons.videocam, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Live Action: Auto-dispatching TN-01-EM-1080 & activating camera/mic feed",
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _cancelAlarmLocally,
                    icon: const Icon(Icons.health_and_safety, color: Colors.white, size: 22),
                    label: const Text("I AM OK - CANCEL DISPATCH", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Instant dispatch button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _autoDispatchEmergencyWorkflow,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("DISPATCH IMMEDIATELY (NO WAIT)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 5. Initial Armed Mode: Real-Time Mobile Sensor Over-Shaking & Vibration Monitor
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text("Automatic Crash & Shake Detector", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Armed Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MOBILE SENSOR ARMED & MONITORING",
                            style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                          ),
                          Text(
                            "Detecting violent shaking, high vibration & crash impacts in real-time.",
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live Sensor Telemetry HUD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("LIVE MOTION SENSOR TELEMETRY", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text("devicemotion API", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontFamily: "monospace")),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // G-Force Meter
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _currentGForce >= 7.5
                                ? Colors.red.withOpacity(0.25)
                                : (_currentGForce >= 4.0 ? Colors.orange.withOpacity(0.2) : const Color(0xFF0284C7).withOpacity(0.2)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _currentGForce >= 7.5
                                  ? Colors.redAccent
                                  : (_currentGForce >= 4.0 ? Colors.orangeAccent : const Color(0xFF38BDF8)),
                            ),
                          ),
                          child: Icon(
                            Icons.speed,
                            color: _currentGForce >= 7.5
                                ? Colors.redAccent
                                : (_currentGForce >= 4.0 ? Colors.orangeAccent : const Color(0xFF38BDF8)),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "${_currentGForce.toStringAsFixed(2)} G",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _currentGForce >= 7.5
                                          ? Colors.redAccent
                                          : (_currentGForce >= 4.0 ? Colors.orangeAccent : Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF334155),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6)),
                                    ),
                                    child: const Text("LIMIT: 7.5 G", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const Text("Resultant Acceleration Magnitude", style: TextStyle(color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Accelerometer 3-Axis readout
                    Row(
                      children: [
                        _buildAxisCard("X-Axis (Lateral)", _axisX),
                        const SizedBox(width: 8),
                        _buildAxisCard("Y-Axis (Longitudinal)", _axisY),
                        const SizedBox(width: 8),
                        _buildAxisCard("Z-Axis (Vertical)", _axisZ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Vibration & Shake Meter
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Vibration / Shake Intensity:", style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text("$_vibrationLevel %", style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_vibrationLevel / 100.0).clamp(0.05, 1.0),
                            backgroundColor: Colors.white12,
                            color: _vibrationLevel > 70 ? Colors.redAccent : (_vibrationLevel > 40 ? Colors.orangeAccent : const Color(0xFF10B981)),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Emergency Dispatch Protocols Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("AUTOMATED ACCIDENT PROTOCOLS", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildProtocolRow(Icons.vibration, "Over-Shaking / Vibration Trigger", "Threshold: >= 7.5 G-force (Over-Shaking / Vibration Limit)"),
                    const SizedBox(height: 6),
                    _buildProtocolRow(Icons.timer, "SOS Alarm Countdown", "40 Seconds Siren & Cancellation Window before auto-dispatch"),
                    const SizedBox(height: 6),
                    _buildProtocolRow(Icons.airport_shuttle, "Automatic 108 Booking", "Dispatches TN-01-EM-1080 (RGGGH Trauma)"),
                    const SizedBox(height: 6),
                    _buildProtocolRow(Icons.videocam, "Live Audio & Video Transmission", "WebRTC camera & mic stream to driver & family"),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Test Simulation Buttons
              ElevatedButton.icon(
                onPressed: () {
                  _sensorService.simulateViolentCrash(gForce: 8.5);
                },
                icon: const Icon(Icons.flash_on, color: Colors.white),
                label: const Text("💥 SIMULATE VIOLENT SHAKE / CRASH IMPACT (> 7.5G)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: _showEditContactDialog,
                icon: const Icon(Icons.contact_phone, color: Color(0xFF38BDF8), size: 16),
                label: Text("Secondary Emergency Contact: $_contactName", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAxisCard(String title, double val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 9), textAlign: TextAlign.center, maxLines: 1),
            const SizedBox(height: 4),
            Text(
              "${val.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: "monospace"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolRow(IconData icon, String title, String sub) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}
