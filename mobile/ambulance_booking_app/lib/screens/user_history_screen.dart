import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import 'tracking_screen.dart';

class UserHistoryScreen extends StatefulWidget {
  final int userId;
  const UserHistoryScreen({super.key, required this.userId});

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  final BookingService _bookingService = BookingService();
  bool _isLoading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await _bookingService.getUserBookings(widget.userId);
      if (!mounted) return;
      setState(() {
        _history = res is List ? res : [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case "Requested":
        return Colors.orange;
      case "Accepted":
        return Colors.blue;
      case "InProgress":
        return Colors.indigo;
      case "Completed":
        return Colors.green;
      case "Cancelled":
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text("Emergency Booking History"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 70, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        "No emergency bookings found yet.",
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final status = item["status"]?.toString() ?? "Requested";
                      final ambulance = item["ambulance"];
                      final isActive = status == "Requested" || status == "Accepted" || status == "InProgress";

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Incident #${item["bookingId"]}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _getStatusColor(status)),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                children: [
                                  const Icon(Icons.local_hospital, size: 18, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Destination: ${item["destinationHospital"] ?? "Not specified"}",
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Condition: ${item["patientCondition"] ?? "Emergency"}",
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                              if (ambulance != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.airport_shuttle, size: 18, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Ambulance: ${ambulance["vehicleNumber"]} (${ambulance["driverName"]})",
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                "Requested: ${item["bookingTime"]?.toString().replaceAll("T", " ").split(".").first ?? ""}",
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              if (isActive) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.navigation, size: 16),
                                    label: const Text("Track Ambulance Live"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TrackingScreen(bookingId: item["bookingId"], userId: widget.userId),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
