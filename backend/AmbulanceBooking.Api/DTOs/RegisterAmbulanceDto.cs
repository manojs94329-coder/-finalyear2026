namespace AmbulanceBooking.Api.DTOs;

public class RegisterAmbulanceDto
{
    public string DriverName { get; set; } = string.Empty;
    public string DriverPhone { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string Password { get; set; } = string.Empty;
    public string VehicleNumber { get; set; } = string.Empty;
    public string? AmbulanceType { get; set; }
    public decimal? CurrentLatitude { get; set; }
    public decimal? CurrentLongitude { get; set; }
}
