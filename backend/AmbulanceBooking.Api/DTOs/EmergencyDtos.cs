namespace AmbulanceBooking.Api.DTOs;

public class CreateEmergencyDto
{
    public int UserId { get; set; }
    public string VictimName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string SecondaryContactName { get; set; } = string.Empty;
    public string SecondaryContactPhone { get; set; } = string.Empty;
    public double Latitude { get; set; } = 13.0827;
    public double Longitude { get; set; } = 80.2707;
    public int BatteryLevel { get; set; } = 100;
    public string TransmissionPath { get; set; } = "Cellular_Data";
    public string? BaseUrl { get; set; }
}

public class CancelEmergencyDto
{
    public string CancelledBy { get; set; } = "SecondaryUser"; // SecondaryUser or VictimUser
    public string Reason { get; set; } = "False alarm confirmed by secondary contact";
}

public class BatteryWarningDto
{
    public int BatteryLevel { get; set; }
}

public class EmergencyResponseDto
{
    public string EmergencyId { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string VictimName { get; set; } = string.Empty;
    public string SecondaryContactPhone { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public int BatteryLevel { get; set; }
    public bool IsCriticalBattery { get; set; }
    public string TransmissionPath { get; set; } = string.Empty;
    public string GoogleMapsUrl { get; set; } = string.Empty;
    public string AgoraStreamUrl { get; set; } = string.Empty;
    public string UnbookUrl { get; set; } = string.Empty;
    public string? CancellationReason { get; set; }
    public string? CancelledBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? CancelledAt { get; set; }
}

public class LiveStreamFrameDto
{
    public string EmergencyId { get; set; } = string.Empty;
    public string FrameBase64 { get; set; } = string.Empty;
    public int Decibels { get; set; }
    public string Status { get; set; } = "BROADCASTING";
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

