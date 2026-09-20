namespace AmbulanceBooking.Api.DTOs;

public class HospitalDto
{
    public int HospitalId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string ContactPhone { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public bool HasEmergencyIcu { get; set; }
    public int AvailableIcuBeds { get; set; }
    public int TotalBeds { get; set; }
    public double? DistanceKm { get; set; }
}

public class UpdateBedCapacityDto
{
    public int AvailableIcuBeds { get; set; }
}
