import 'api_service.dart';

class HospitalService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> getHospitals({double? lat, double? lng}) async {
    String query = "";
    if (lat != null && lng != null) {
      query = "?lat=$lat&lng=$lng";
    }
    final response = await _api.get("/Hospitals$query");
    if (response is List) return response;
    return [];
  }

  Future<dynamic> getHospital(int id) async {
    return await _api.get("/Hospitals/$id");
  }

  Future<dynamic> updateBeds(int id, int availableBeds) async {
    return await _api.put("/Hospitals/$id/beds", {
      "availableIcuBeds": availableBeds,
    });
  }
}
