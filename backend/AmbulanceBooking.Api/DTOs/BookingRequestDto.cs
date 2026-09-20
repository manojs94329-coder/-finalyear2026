namespace AmbulanceBooking.Api.DTOs;

public class BookingRequestDto
{
    public int UserId { get; set; }
    public decimal PickupLatitude { get; set; }
    public decimal PickupLongitude { get; set; }
    public string? DestinationHospital { get; set; }
    public string? PatientCondition { get; set; }
    public decimal? EstimatedPrice { get; set; } = 650.00m;
    public string? EquipmentAddons { get; set; }
    public int? HospitalId { get; set; }
    public int? EstimatedEtaMinutes { get; set; } = 8;
}
