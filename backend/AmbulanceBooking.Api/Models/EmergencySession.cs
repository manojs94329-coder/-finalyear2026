namespace AmbulanceBooking.Api.Models;

public class EmergencySession
{
    public string EmergencyId { get; set; } = string.Empty;
    public int UserId { get; set; }
    public string VictimName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string SecondaryContactName { get; set; } = string.Empty;
    public string SecondaryContactPhone { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public int BatteryLevel { get; set; } = 100;
    public bool IsCriticalBattery { get; set; } = false;
    public string TransmissionPath { get; set; } = "Cellular_Data"; // "Satellite_SOS" or "Cellular_Data"
    public string Status { get; set; } = "ACTIVE_EMERGENCY"; // ACTIVE_EMERGENCY, CANCELLED_BY_USER, CANCELLED_BY_SECONDARY_USER, RESOLVED
    public string AgoraChannel { get; set; } = string.Empty;
    public string AgoraStreamUrl { get; set; } = string.Empty;
    public string GoogleMapsUrl { get; set; } = string.Empty;
    public string UnbookUrl { get; set; } = string.Empty;
    public string? CancellationReason { get; set; }
    public string? CancelledBy { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CancelledAt { get; set; }
    public DateTime? LastBatteryAlertAt { get; set; }
}
