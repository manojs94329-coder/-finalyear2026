using System.Collections.Concurrent;
using AmbulanceBooking.Api.DTOs;
using AmbulanceBooking.Api.Models;
using Microsoft.AspNetCore.Mvc;

namespace AmbulanceBooking.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EmergenciesController : ControllerBase
{
    private static readonly ConcurrentDictionary<string, EmergencySession> _sessions = new();
    private static readonly ConcurrentDictionary<string, LiveStreamFrameDto> _liveFrames = new();
    private static LiveStreamFrameDto? _latestGlobalFrame = null;

    [HttpPost]
    public IActionResult CreateEmergency([FromBody] CreateEmergencyDto dto)
    {
        var emergencyId = $"EMG-{DateTime.UtcNow:yyyyMMdd}-{Random.Shared.Next(1000, 9999)}";
        var baseUrl = !string.IsNullOrWhiteSpace(dto.BaseUrl) 
            ? dto.BaseUrl.TrimEnd('/') 
            : $"{Request.Scheme}://{Request.Host}";

        var mapsUrl = $"https://maps.google.com/?q={dto.Latitude:F6},{dto.Longitude:F6}";
        var agoraChannel = $"emergency_room_{emergencyId.ToLowerInvariant().Replace("-", "_")}";
        var agoraUrl = $"https://emergency-agora.stream/room/{agoraChannel}";
        var unbookUrl = $"{baseUrl}/#/emergency-unbook?id={emergencyId}";

        var session = new EmergencySession
        {
            EmergencyId = emergencyId,
            UserId = dto.UserId,
            VictimName = string.IsNullOrWhiteSpace(dto.VictimName) ? "Emergency Victim" : dto.VictimName,
            PhoneNumber = dto.PhoneNumber,
            SecondaryContactName = dto.SecondaryContactName,
            SecondaryContactPhone = dto.SecondaryContactPhone,
            Latitude = dto.Latitude,
            Longitude = dto.Longitude,
            BatteryLevel = dto.BatteryLevel,
            IsCriticalBattery = dto.BatteryLevel <= 15,
            TransmissionPath = dto.TransmissionPath,
            Status = "ACTIVE_EMERGENCY",
            AgoraChannel = agoraChannel,
            AgoraStreamUrl = agoraUrl,
            GoogleMapsUrl = mapsUrl,
            UnbookUrl = unbookUrl,
            CreatedAt = DateTime.UtcNow
        };

        _sessions[emergencyId] = session;

        return Ok(MapToDto(session));
    }

    public static EmergencySession RegisterSosFromBooking(int userId, string victimName, string phone, double lat, double lng, string baseUrl)
    {
        var emergencyId = $"SOS-{DateTime.UtcNow:yyyyMMdd}-{Random.Shared.Next(1000, 9999)}";
        var mapsUrl = $"https://maps.google.com/?q={lat:F6},{lng:F6}";
        var agoraChannel = $"emergency_room_{emergencyId.ToLowerInvariant().Replace("-", "_")}";
        var agoraUrl = $"https://emergency-agora.stream/room/{agoraChannel}";
        var unbookUrl = $"{baseUrl.TrimEnd('/')}/#/emergency-unbook?id={emergencyId}";

        var session = new EmergencySession
        {
            EmergencyId = emergencyId,
            UserId = userId,
            VictimName = string.IsNullOrWhiteSpace(victimName) ? "Emergency SOS Citizen" : victimName,
            PhoneNumber = string.IsNullOrWhiteSpace(phone) ? "9840112233" : phone,
            SecondaryContactName = "Emergency Family Contact",
            SecondaryContactPhone = "9444011223",
            Latitude = lat,
            Longitude = lng,
            BatteryLevel = 85,
            IsCriticalBattery = false,
            TransmissionPath = "1_Tap_Instant_SOS",
            Status = "ACTIVE_EMERGENCY",
            AgoraChannel = agoraChannel,
            AgoraStreamUrl = agoraUrl,
            GoogleMapsUrl = mapsUrl,
            UnbookUrl = unbookUrl,
            CreatedAt = DateTime.UtcNow
        };

        _sessions[emergencyId] = session;
        return session;
    }

    [HttpGet("{id}")]
    public IActionResult GetEmergency(string id)
    {
        if (!_sessions.TryGetValue(id, out var session))
        {
            return NotFound(new { message = $"Emergency session '{id}' not found." });
        }
        return Ok(MapToDto(session));
    }

    [HttpPost("{id}/cancel")]
    public IActionResult CancelEmergency(string id, [FromBody] CancelEmergencyDto dto)
    {
        if (!_sessions.TryGetValue(id, out var session))
        {
            return NotFound(new { message = $"Emergency session '{id}' not found." });
        }

        var isSecondary = string.Equals(dto.CancelledBy, "SecondaryUser", StringComparison.OrdinalIgnoreCase);
        session.Status = isSecondary ? "CANCELLED_BY_SECONDARY_USER" : "CANCELLED_BY_USER";
        session.CancelledBy = dto.CancelledBy;
        session.CancellationReason = string.IsNullOrWhiteSpace(dto.Reason) ? "False alarm confirmed" : dto.Reason;
        session.CancelledAt = DateTime.UtcNow;

        return Ok(new
        {
            message = isSecondary ? "Emergency cancelled remotely by secondary contact." : "Emergency cancelled by user.",
            status = session.Status,
            session = MapToDto(session)
        });
    }

    [HttpPost("{id}/battery-warning")]
    public IActionResult ReportBatteryWarning(string id, [FromBody] BatteryWarningDto dto)
    {
        if (!_sessions.TryGetValue(id, out var session))
        {
            return NotFound(new { message = $"Emergency session '{id}' not found." });
        }

        session.BatteryLevel = dto.BatteryLevel;
        session.IsCriticalBattery = dto.BatteryLevel <= 15;

        // Rate-limit notifications to at most once every 10 minutes
        var now = DateTime.UtcNow;
        var rateLimited = session.LastBatteryAlertAt.HasValue && (now - session.LastBatteryAlertAt.Value).TotalMinutes < 10;

        if (!rateLimited && session.IsCriticalBattery)
        {
            session.LastBatteryAlertAt = now;
            return Ok(new
            {
                alertTriggered = true,
                batteryLevel = session.BatteryLevel,
                message = $"Critical battery warning ({session.BatteryLevel}%) registered. Emergency contact alerted."
            });
        }

        return Ok(new
        {
            alertTriggered = false,
            batteryLevel = session.BatteryLevel,
            message = rateLimited ? "Battery update received (alert suppressed by rate-limiting cooldown)." : "Battery level within normal range."
        });
    }

    [HttpGet("active")]
    public IActionResult GetActiveEmergencies()
    {
        var active = _sessions.Values
            .Where(x => x.Status == "ACTIVE_EMERGENCY")
            .OrderByDescending(x => x.CreatedAt)
            .Select(MapToDto)
            .ToList();
        return Ok(active);
    }

    [HttpPost("{id}/stream")]
    public IActionResult UploadStreamFrame(string id, [FromBody] LiveStreamFrameDto dto)
    {
        dto.EmergencyId = id;
        dto.Timestamp = DateTime.UtcNow;
        _liveFrames[id] = dto;
        _latestGlobalFrame = dto;
        return Ok(new { success = true, timestamp = dto.Timestamp });
    }

    [HttpGet("{id}/stream")]
    public IActionResult GetStreamFrame(string id)
    {
        if (_liveFrames.TryGetValue(id, out var frame))
        {
            return Ok(frame);
        }
        if (_latestGlobalFrame != null)
        {
            return Ok(_latestGlobalFrame);
        }
        return Ok(new LiveStreamFrameDto { EmergencyId = id, Status = "WAITING_FOR_BROADCAST", Decibels = 0 });
    }

    [HttpGet("stream/latest")]
    public IActionResult GetLatestStreamFrame()
    {
        if (_latestGlobalFrame != null)
        {
            return Ok(_latestGlobalFrame);
        }
        return Ok(new LiveStreamFrameDto { Status = "IDLE", Decibels = 0 });
    }

    private static EmergencyResponseDto MapToDto(EmergencySession s)
    {
        return new EmergencyResponseDto
        {
            EmergencyId = s.EmergencyId,
            Status = s.Status,
            VictimName = s.VictimName,
            SecondaryContactPhone = s.SecondaryContactPhone,
            Latitude = s.Latitude,
            Longitude = s.Longitude,
            BatteryLevel = s.BatteryLevel,
            IsCriticalBattery = s.IsCriticalBattery,
            TransmissionPath = s.TransmissionPath,
            GoogleMapsUrl = s.GoogleMapsUrl,
            AgoraStreamUrl = s.AgoraStreamUrl,
            UnbookUrl = s.UnbookUrl,
            CancellationReason = s.CancellationReason,
            CancelledBy = s.CancelledBy,
            CreatedAt = s.CreatedAt,
            CancelledAt = s.CancelledAt
        };
    }
}
