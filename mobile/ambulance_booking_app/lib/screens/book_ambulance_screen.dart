import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/booking_service.dart';
import 'tracking_screen.dart';

class BookAmbulanceScreen extends StatefulWidget {
  final int userId;
  final String? initialCondition;

  const BookAmbulanceScreen({super.key, required this.userId, this.initialCondition});

  @override
  State<BookAmbulanceScreen> createState() => _BookAmbulanceScreenState();
}

class _BookAmbulanceScreenState extends State<BookAmbulanceScreen> {
  final hospitalController = TextEditingController();
  final conditionController = TextEditingController();
  final addressController = TextEditingController();

  bool isLoading = false;
  bool isLocating = false;
  double? currentLat;
  double? currentLng;
  final BookingService bookingService = BookingService();

  String selectedTriage = "Critical (Code Red)";
  String selectedAmbulanceType = "Advanced Life Support (ALS)";

  final List<String> triageLevels = [
    "Critical (Code Red)",
    "Urgent (Code Yellow)",
    "Standard (Code Green)",
  ];

  final List<String> ambulanceTypes = [
    "Advanced Life Support (ALS)",
    "Basic Life Support (BLS)",
    "Patient Transport Ambulance",
    "Neonatal Intensive Care",
  ];

  final List<String> emergencyHospitals = [
    "Rajiv Gandhi Govt General Hospital (RGGGH), Chennai",
    "Apollo Hospitals Main & Trauma, Greams Rd, Chennai",
    "MIOT International Multi-Specialty Hospital, Chennai",
    "Sri Ramachandra Medical Centre (SRMC), Porur, Chennai",
    "SIMS Hospital, Vadapalani, Chennai",
    "Kauvery Hospital Chennai, Alwarpet",
    "Ganga Hospital & Trauma Care Centre, Coimbatore",
    "Government Rajaji Hospital (GRH Trauma), Madurai",
    "Christian Medical College (CMC Trauma), Vellore",
    "Kauvery Hospital Trichy, Tiruchirappalli",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCondition != null) {
      conditionController.text = widget.initialCondition!;
    }
    hospitalController.text = emergencyHospitals.first;
    _detectLocation();
  }

  @override
  void dispose() {
    hospitalController.dispose();
    conditionController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useFallbackLocation("Location services disabled. Using default hospital district.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _useFallbackLocation("GPS permission denied. Using standard city coordinates.");
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        currentLat = position.latitude;
        currentLng = position.longitude;
        addressController.text = "GPS: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} (Current Location)";
        isLocating = false;
      });
    } catch (e) {
      _useFallbackLocation("GPS sensor unavailable ($e). Using default city coordinates.");
    }
  }

  void _useFallbackLocation(String reason) {
    if (!mounted) return;
    setState(() {
      currentLat = 13.0827;
      currentLng = 80.2707;
      addressController.text = "Anna Salai, Chennai Central, Tamil Nadu 600003";
      isLocating = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> requestAmbulance() async {
    if (currentLat == null || currentLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Detecting location... Please wait a second.")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final combinedCondition = "[$selectedTriage | $selectedAmbulanceType] ${conditionController.text.trim().isEmpty ? "Emergency Dispatch" : conditionController.text.trim()}";

      final response = await bookingService.requestAmbulance(
        userId: widget.userId,
        pickupLatitude: currentLat!,
        pickupLongitude: currentLng!,
        destinationHospital: hospitalController.text.trim(),
        patientCondition: combinedCondition,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response["message"] ?? "Ambulance dispatched!"),
          backgroundColor: Colors.green.shade700,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingScreen(bookingId: response["bookingId"]),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request failed: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text("Request Emergency Ambulance"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Triage Emergency Level Banner
                const Text(
                  "Emergency Triage Level",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedTriage,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning, color: Colors.red),
                  ),
                  items: triageLevels
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => selectedTriage = v!),
                ),
                const SizedBox(height: 16),

                // Ambulance Type
                const Text(
                  "Required Ambulance Unit",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedAmbulanceType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.airport_shuttle, color: Colors.blue),
                  ),
                  items: ambulanceTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedAmbulanceType = v!),
                ),
                const SizedBox(height: 16),

                // Pickup Location
                const Text(
                  "Pickup Location",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.my_location, color: Colors.red),
                    suffixIcon: isLocating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _detectLocation,
                            tooltip: "Re-detect GPS",
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Destination Hospital
                const Text(
                  "Destination Hospital",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: emergencyHospitals.first,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_hospital, color: Colors.green),
                  ),
                  items: emergencyHospitals
                      .map((h) => DropdownMenuItem(value: h, child: Text(h, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => hospitalController.text = v!),
                ),
                const SizedBox(height: 16),

                // Patient Condition Notes
                const Text(
                  "Patient Symptoms / Notes",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: conditionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "e.g. Severe chest pain, breathing difficulty, unconscious, car collision",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services, color: Colors.red),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.notifications_active, size: 24),
                    label: Text(
                      isLoading ? "Broadcasting Emergency..." : "DISPATCH AMBULANCE NOW",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    onPressed: isLoading ? null : requestAmbulance,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
