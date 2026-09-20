class AmbulanceModel {
  final int ambulanceId;
  final String driverName;
  final String driverPhone;
  final String vehicleNumber;
  final double? currentLatitude;
  final double? currentLongitude;
  final String status;
  AmbulanceModel({required this.ambulanceId, required this.driverName, required this.driverPhone, required this.vehicleNumber, this.currentLatitude, this.currentLongitude, required this.status});
  factory AmbulanceModel.fromJson(Map<String, dynamic> json) => AmbulanceModel(ambulanceId: json['ambulanceId'], driverName: json['driverName'], driverPhone: json['driverPhone'], vehicleNumber: json['vehicleNumber'], currentLatitude: json['currentLatitude']?.toDouble(), currentLongitude: json['currentLongitude']?.toDouble(), status: json['status']);
}
