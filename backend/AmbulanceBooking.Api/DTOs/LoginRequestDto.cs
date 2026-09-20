namespace AmbulanceBooking.Api.DTOs;

public class LoginRequestDto
{
    public string PhoneOrEmail { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string Role { get; set; } = "User";
}
