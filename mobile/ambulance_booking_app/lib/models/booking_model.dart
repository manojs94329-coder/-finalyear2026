class BookingModel {
  final int bookingId;
  final String status;
  final double pickupLatitude;
  final double pickupLongitude;
  final String? destinationHospital;
  BookingModel({required this.bookingId, required this.status, required this.pickupLatitude, required this.pickupLongitude, this.destinationHospital});
  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(bookingId: json['bookingId'], status: json['status'], pickupLatitude: json['pickupLatitude'].toDouble(), pickupLongitude: json['pickupLongitude'].toDouble(), destinationHospital: json['destinationHospital']);
}
