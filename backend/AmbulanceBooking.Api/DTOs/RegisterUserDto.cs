namespace AmbulanceBooking.Api.DTOs;

public class RegisterUserDto
{
    public string FullName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string Password { get; set; } = string.Empty;
    public string? BloodGroup { get; set; }
    public string? MedicalDetails { get; set; }
    public string? EmergencyContact { get; set; }
}
