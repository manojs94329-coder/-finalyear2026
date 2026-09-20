namespace AmbulanceBooking.Api.Services;

public interface IJwtService
{
    string GenerateToken(int id, string name, string role);
}
