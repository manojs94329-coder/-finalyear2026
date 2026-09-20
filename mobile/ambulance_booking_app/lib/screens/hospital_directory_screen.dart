import 'package:flutter/material.dart';
import '../services/hospital_service.dart';
import '../services/url_launcher_service.dart';

class HospitalDirectoryScreen extends StatefulWidget {
  final Function(dynamic hospital)? onSelectHospital;

  const HospitalDirectoryScreen({super.key, this.onSelectHospital});

  @override
  State<HospitalDirectoryScreen> createState() => _HospitalDirectoryScreenState();
}

class _HospitalDirectoryScreenState extends State<HospitalDirectoryScreen> {
  final HospitalService _hospitalService = HospitalService();
  List<dynamic> _hospitals = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _selectedCity = "All Cities";

  final List<String> _cities = [
    "All Cities",
    "Chennai",
    "Coimbatore",
    "Madurai",
    "Vellore",
    "Trichy",
  ];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() => _isLoading = true);
    try {
      final list = await _hospitalService.getHospitals(lat: 13.0827, lng: 80.2707);
      setState(() {
        _hospitals = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getRespectiveAmbulance(dynamic h) {
    final int id = h["hospitalId"] ?? 1;
    switch (id) {
      case 1:
        return {
          "vehicleNumber": "TN-01-EM-1080",
          "driverName": "M. Murugan",
          "role": "108 Senior ALS Paramedic",
          "phone": "+91 98765 43210",
          "type": "Advanced Life Support (ALS) • ICU on Wheels",
          "equipment": ["ICU Ventilator", "Biphasic Defibrillator", "Syringe Pump", "High-Flow O2", "Spine Board"],
          "status": "Stationed at Bay 1",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 13.0805,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 80.2764,
        };
      case 2:
        return {
          "vehicleNumber": "TN-07-ICU-2026",
          "driverName": "S. Selvam",
          "role": "Apollo Cardiac & Trauma Paramedic",
          "phone": "+91 98401 22334",
          "type": "Cardiac Life Support (ACLS)",
          "equipment": ["12-Lead ECG", "Cardiac Monitor", "Pacemaker", "Biphasic Defib", "Transport Ventilator"],
          "status": "Stationed at ER Bay",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 13.0604,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 80.2496,
        };
      case 3:
        return {
          "vehicleNumber": "TN-09-TR-1008",
          "driverName": "K. Anbarasan",
          "role": "MIOT Emergency Trauma Specialist",
          "phone": "+91 97909 11223",
          "type": "Trauma Life Support (TLS)",
          "equipment": ["Portable Ultrasound", "Multipara Monitor", "Vacuum Splints", "O2 Resuscitator"],
          "status": "Stationed at Trauma Wing",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 13.0204,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 80.1772,
        };
      case 4:
        return {
          "vehicleNumber": "TN-02-SR-1081",
          "driverName": "P. Ramesh",
          "role": "SRMC Rapid Response Medic",
          "phone": "+91 94441 55667",
          "type": "Basic & Advanced Life Support",
          "equipment": ["Transport Ventilator", "Automated CPR", "Glucometer", "BVM", "Suction Pump"],
          "status": "Stationed at Porur Hub",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 13.0382,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 80.1444,
        };
      case 5:
        return {
          "vehicleNumber": "TN-05-SM-1085",
          "driverName": "R. Vignesh",
          "role": "SIMS Critical Care Technician",
          "phone": "+91 99620 44332",
          "type": "Advanced Life Support (ALS)",
          "equipment": ["Defibrillator", "Patient Monitor", "Dual Infusion Pumps", "Oxygen Pipeline"],
          "status": "Stationed at Emergency Port",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 13.0526,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 80.2098,
        };
      case 6:
        return {
          "vehicleNumber": "TN-06-KH-1082",
          "driverName": "V. Kumar",
          "role": "Kauvery Critical Care Transit",
          "phone": "+91 98840 77889",
          "type": "Critical Care Transit Unit (CCTU)",
          "equipment": ["Hamilton T1 Transport Ventilator", "Arterial Line Monitor", "Defibrillator"],
          "status": "Stationed at Alwarpet ER",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 13.0336,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 80.2505,
        };
      case 7:
        return {
          "vehicleNumber": "TN-38-EM-1080",
          "driverName": "R. Senthil",
          "role": "Coimbatore 108 Ortho-Trauma",
          "phone": "+91 94430 88991",
          "type": "Trauma & Orthopedic Unit",
          "equipment": ["Vacuum Mattresses", "Traction Splints", "Emergency Hemostatic Kit", "O2 Tank"],
          "status": "Stationed at Coimbatore Bay",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 11.0267,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 76.9458,
        };
      case 8:
        return {
          "vehicleNumber": "TN-58-EM-1080",
          "driverName": "M. Pandian",
          "role": "Madurai GRH Command Paramedic",
          "phone": "+91 98421 99002",
          "type": "Advanced Life Support (ALS)",
          "equipment": ["Emergency Resuscitator", "Defibrillator", "Multiparameter Monitor", "O2 Pipeline"],
          "status": "Stationed at Madurai ER",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 9.9288,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 78.1312,
        };
      case 9:
        return {
          "vehicleNumber": "TN-23-EM-1080",
          "driverName": "D. Joshua",
          "role": "CMC Vellore Mobile ICU Lead",
          "phone": "+91 94860 33445",
          "type": "Intensive Care Unit (ICU on Wheels)",
          "equipment": ["High-End Transport Ventilator", "Defibrillator", "Syringe Drivers", "Tele-ICU Link"],
          "status": "Stationed at Vellore Campus",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 12.9260,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 79.1353,
        };
      case 10:
        return {
          "vehicleNumber": "TN-45-EM-1080",
          "driverName": "G. Ravi",
          "role": "Trichy 108 Rapid Medic",
          "phone": "+91 97890 22331",
          "type": "Cardiac & Trauma Unit",
          "equipment": ["ECG Telemetry", "External Defibrillator", "Suction Unit", "Airway Management"],
          "status": "Stationed at Trichy Bay",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 10.8058,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 78.6856,
        };
      default:
        return {
          "vehicleNumber": "TN-01-EM-1080",
          "driverName": "108 Duty Paramedic",
          "role": "Tamil Nadu 108 Emergency Service",
          "phone": "108",
          "type": "Advanced Life Support (ALS)",
          "equipment": ["Oxygen Tank", "Defibrillator", "Stretcher", "First Aid Kit"],
          "status": "Stationed & Ready",
          "lat": (h["latitude"] as num?)?.toDouble() ?? 13.0827,
          "lng": (h["longitude"] as num?)?.toDouble() ?? 80.2707,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _hospitals.where((h) {
      final name = (h["name"] ?? "").toString().toLowerCase();
      final address = (h["address"] ?? "").toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || address.contains(_searchQuery.toLowerCase());
      
      final matchesCity = _selectedCity == "All Cities" || 
        address.contains(_selectedCity.toLowerCase()) || 
        name.contains(_selectedCity.toLowerCase());
        
      return matchesSearch && matchesCity;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tamil Nadu Hospitals & ICU Beds", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            Text("Live ICU Bed Tracker • Stationed 108 Ambulances", style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadHospitals,
            tooltip: "Refresh Bed Status",
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF111827),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search hospital name or city (e.g. Apollo, Madurai, CMC)...",
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                    filled: true,
                    fillColor: const Color(0xFF1F2937),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _cities.map((city) {
                      final isSelected = _selectedCity == city;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(city, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.grey[300])),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0C831F),
                          backgroundColor: const Color(0xFF1F2937),
                          side: BorderSide(color: isSelected ? const Color(0xFF10B981) : Colors.transparent),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCity = city);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_hospital_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text("No hospital centers found matching criteria", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHospitals,
                        color: const Color(0xFF0C831F),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final h = filtered[index];
                            final icuBeds = (h["availableIcuBeds"] as num?)?.toInt() ?? 0;
                            final totalBeds = (h["totalBeds"] as num?)?.toInt() ?? 100;
                            final isHigh = icuBeds >= 25;
                            final isModerate = icuBeds >= 15 && icuBeds < 25;
                            final amb = _getRespectiveAmbulance(h);
                            final equipmentList = (amb["equipment"] as List<String>?) ?? [];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
                                ],
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Hospital Header
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.local_hospital, color: Color(0xFF0C831F), size: 28),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                h["name"] ?? "Hospital",
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      h["address"] ?? "",
                                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (h["distanceKm"] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "⚡ ${h["distanceKm"]} km",
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C831F)),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // 2. ICU Bed Status Card
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isHigh
                                            ? const Color(0xFFECFDF5)
                                            : isModerate
                                                ? const Color(0xFFFFFBEB)
                                                : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isHigh
                                              ? const Color(0xFF10B981)
                                              : isModerate
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFFEF4444),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.bed,
                                                size: 18,
                                                color: isHigh
                                                    ? const Color(0xFF0C831F)
                                                    : isModerate
                                                        ? const Color(0xFFD97706)
                                                        : const Color(0xFFDC2626),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "$icuBeds Available ICU Beds",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: isHigh
                                                      ? const Color(0xFF0C831F)
                                                      : isModerate
                                                          ? const Color(0xFFD97706)
                                                          : const Color(0xFFDC2626),
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.black12),
                                                ),
                                                child: Text(
                                                  "$icuBeds / $totalBeds Total Beds",
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: (icuBeds / (totalBeds > 0 ? totalBeds : 1)).clamp(0.05, 1.0),
                                              backgroundColor: Colors.white,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                isHigh
                                                    ? const Color(0xFF10B981)
                                                    : isModerate
                                                        ? const Color(0xFFF59E0B)
                                                        : const Color(0xFFEF4444),
                                              ),
                                              minHeight: 6,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                isHigh
                                                    ? "🟢 High Capacity • Immediate ICU Admission"
                                                    : isModerate
                                                        ? "🟡 Moderate Capacity • Emergency Care Ready"
                                                        : "🔴 High Demand • Rapid Intake Available",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isHigh
                                                      ? const Color(0xFF0C831F)
                                                      : isModerate
                                                          ? const Color(0xFFB45309)
                                                          : const Color(0xFFB91C1C),
                                                ),
                                              ),
                                              Text(
                                                "24x7 Ready",
                                                style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // 3. Respective Stationed 108 Ambulance Unit
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF334155)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.emergency, color: Color(0xFF10B981), size: 18),
                                              const SizedBox(width: 8),
                                              const Text(
                                                "STATIONED 108 AMBULANCE SERVICE",
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0C831F).withOpacity(0.3),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFF10B981)),
                                                ),
                                                child: Text(
                                                  amb["status"] ?? "Stationed",
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF34D399), fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0F172A),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFF10B981)),
                                                ),
                                                child: Text(
                                                  amb["vehicleNumber"] ?? "TN-01-EM-1080",
                                                  style: const TextStyle(
                                                    fontFamily: "monospace",
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Color(0xFF34D399),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "${amb["driverName"]} (${amb["role"]})",
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      amb["type"] ?? "Advanced Life Support",
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: equipmentList.map((eq) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF334155),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.check, size: 10, color: Color(0xFF34D399)),
                                                    const SizedBox(width: 4),
                                                    Text(eq, style: const TextStyle(fontSize: 10, color: Color(0xFFE2E8F0))),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    final lat = amb["lat"] as double;
                                                    final lng = amb["lng"] as double;
                                                    final mapUrl = UrlLauncherService.getGoogleMapsPointUrl(lat, lng);
                                                    UrlLauncherService.openUrl(mapUrl);
                                                  },
                                                  icon: const Icon(Icons.map, size: 14, color: Colors.white),
                                                  label: const Text("Ambulance GPS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF2563EB),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text("Calling Paramedic (${amb["driverName"]}): ${amb["phone"]}")),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.phone_in_talk, size: 14, color: Color(0xFF34D399)),
                                                  label: const Text("Call Medic", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFF10B981)),
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
                                    const SizedBox(height: 14),

                                    // 4. Action Buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text("Calling Emergency Desk: ${h["contactPhone"]}")),
                                              );
                                            },
                                            icon: const Icon(Icons.phone, size: 15),
                                            label: Text(h["contactPhone"] ?? "Desk", style: const TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF111827),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              if (widget.onSelectHospital != null) {
                                                widget.onSelectHospital!(h);
                                                Navigator.pop(context);
                                              } else {
                                                Navigator.pop(context, h);
                                              }
                                            },
                                            icon: const Icon(Icons.check_circle_outline, size: 15),
                                            label: const Text("Select Center", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0C831F),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          ),
        ],
      ),
    );
  }
}
