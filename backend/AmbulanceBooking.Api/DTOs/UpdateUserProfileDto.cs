namespace AmbulanceBooking.Api.DTOs;

public class UpdateUserProfileDto
{
    public string FullName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? BloodGroup { get; set; }
    public string? MedicalDetails { get; set; }
    public string? EmergencyContact { get; set; }
}
