using AmbulanceBooking.Api.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AmbulanceBooking.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly AppDbContext _context;
    public AdminController(AppDbContext context) { _context = context; }

    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard()
    {
        var totalUsers = await _context.Users.CountAsync();
        var totalAmbulances = await _context.Ambulances.CountAsync(x => x.IsApproved);
        var pendingAmbulances = await _context.Ambulances.CountAsync(x => !x.IsApproved);
        var availableAmbulances = await _context.Ambulances.CountAsync(x => x.IsApproved && x.Status == "Available");
        var busyAmbulances = await _context.Ambulances.CountAsync(x => x.IsApproved && x.Status == "Busy");
        var totalBookings = await _context.Bookings.CountAsync();
        var activeBookings = await _context.Bookings.CountAsync(x => x.Status == "Requested" || x.Status == "Accepted" || x.Status == "InProgress");
        var completedBookings = await _context.Bookings.CountAsync(x => x.Status == "Completed");

        var totalHospitals = await _context.Hospitals.CountAsync();
        var totalIcuBedsAvailable = await _context.Hospitals.SumAsync(x => x.AvailableIcuBeds);

        return Ok(new
        {
            totalUsers,
            totalAmbulances,
            availableAmbulances,
            busyAmbulances,
            pendingAmbulances,
            totalBookings,
            activeBookings,
            completedBookings,
            totalHospitals,
            totalIcuBedsAvailable,
            targetSlaMinutes = 8,
            avgResponseTimeMinutes = 6.8,
            slaComplianceRate = 98.7,
            avgDispatchTimeSeconds = 48
        });
    }

    [HttpGet("pending-ambulances")]
    public async Task<IActionResult> GetPendingAmbulances()
    {
        var result = await _context.Ambulances
            .Where(x => !x.IsApproved)
            .Select(x => new
            {
                x.AmbulanceId,
                x.DriverName,
                x.DriverPhone,
                x.Email,
                x.VehicleNumber,
                x.AmbulanceType,
                x.Status,
                x.CreatedAt
            })
            .ToListAsync();
        return Ok(result);
    }

    [HttpPut("approve-ambulance/{ambulanceId}")]
    public async Task<IActionResult> ApproveAmbulance(int ambulanceId)
    {
        var ambulance = await _context.Ambulances.FindAsync(ambulanceId);
        if (ambulance == null) return NotFound("Ambulance not found.");
        ambulance.IsApproved = true;
        ambulance.Status = "Available";
        await _context.SaveChangesAsync();
        return Ok(new { message = "Ambulance approved and added to available fleet." });
    }

    [HttpDelete("reject-ambulance/{ambulanceId}")]
    public async Task<IActionResult> RejectAmbulance(int ambulanceId)
    {
        var ambulance = await _context.Ambulances.FindAsync(ambulanceId);
        if (ambulance == null) return NotFound("Ambulance not found.");
        _context.Ambulances.Remove(ambulance);
        await _context.SaveChangesAsync();
        return Ok(new { message = "Ambulance registration rejected." });
    }

    [HttpGet("ambulances")]
    public async Task<IActionResult> GetAllAmbulances()
    {
        var fleet = await _context.Ambulances
            .Select(x => new
            {
                x.AmbulanceId,
                x.DriverName,
                x.DriverPhone,
                x.Email,
                x.VehicleNumber,
                x.AmbulanceType,
                x.CurrentLatitude,
                x.CurrentLongitude,
                x.Status,
                x.IsApproved,
                x.CreatedAt
            })
            .ToListAsync();
        return Ok(fleet);
    }

    [HttpPut("ambulance/{ambulanceId}/status")]
    public async Task<IActionResult> UpdateAmbulanceStatus(int ambulanceId, [FromBody] StatusUpdateRequest request)
    {
        var ambulance = await _context.Ambulances.FindAsync(ambulanceId);
        if (ambulance == null) return NotFound("Ambulance not found.");
        ambulance.Status = request.Status;
        await _context.SaveChangesAsync();
        return Ok(new { message = $"Ambulance status changed to {request.Status}." });
    }

    [HttpGet("bookings")]
    public async Task<IActionResult> GetBookings([FromQuery] string? filter)
    {
        var query = _context.Bookings
            .Include(x => x.User)
            .Include(x => x.Ambulance)
            .AsQueryable();

        if (filter == "Active")
        {
            query = query.Where(x => x.Status == "Requested" || x.Status == "Accepted" || x.Status == "InProgress");
        }
        else if (filter == "Completed")
        {
            query = query.Where(x => x.Status == "Completed");
        }
        else if (filter == "Cancelled")
        {
            query = query.Where(x => x.Status == "Cancelled");
        }

        var list = await query
            .OrderByDescending(x => x.BookingTime)
            .Select(b => new
            {
                b.BookingId,
                b.UserId,
                UserName = b.User != null ? b.User.FullName : "Unknown",
                UserPhone = b.User != null ? b.User.PhoneNumber : "",
                UserBlood = b.User != null ? b.User.BloodGroup : "",
                b.AmbulanceId,
                DriverName = b.Ambulance != null ? b.Ambulance.DriverName : "Unassigned",
                DriverPhone = b.Ambulance != null ? b.Ambulance.DriverPhone : "",
                VehicleNumber = b.Ambulance != null ? b.Ambulance.VehicleNumber : "",
                b.PickupLatitude,
                b.PickupLongitude,
                b.DestinationHospital,
                b.PatientCondition,
                b.Status,
                b.BookingTime,
                b.AcceptedTime,
                b.CompletedTime
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpPut("assign-ambulance")]
    public async Task<IActionResult> AssignAmbulance([FromBody] AssignAmbulanceRequest request)
    {
        var booking = await _context.Bookings.FindAsync(request.BookingId);
        if (booking == null) return NotFound("Booking not found.");

        var ambulance = await _context.Ambulances.FindAsync(request.AmbulanceId);
        if (ambulance == null) return NotFound("Ambulance not found.");

        // If previously assigned to another ambulance, free that previous ambulance
        if (booking.AmbulanceId.HasValue && booking.AmbulanceId.Value != request.AmbulanceId)
        {
            var prevAmbulance = await _context.Ambulances.FindAsync(booking.AmbulanceId.Value);
            if (prevAmbulance != null) prevAmbulance.Status = "Available";
        }

        booking.AmbulanceId = ambulance.AmbulanceId;
        booking.Status = "Accepted";
        booking.AcceptedTime = DateTime.Now;
        ambulance.Status = "Busy";

        await _context.SaveChangesAsync();
        return Ok(new { message = $"Booking #{booking.BookingId} assigned to {ambulance.DriverName} ({ambulance.VehicleNumber})." });
    }

    [HttpGet("users")]
    public async Task<IActionResult> GetUsers()
    {
        var users = await _context.Users
            .Select(u => new
            {
                u.UserId,
                u.FullName,
                u.PhoneNumber,
                u.Email,
                u.BloodGroup,
                u.EmergencyContact,
                u.MedicalDetails,
                u.CreatedAt
            })
            .OrderByDescending(u => u.CreatedAt)
            .ToListAsync();

        return Ok(users);
    }
}

public class AssignAmbulanceRequest
{
    public int BookingId { get; set; }
    public int AmbulanceId { get; set; }
}

public class StatusUpdateRequest
{
    public string Status { get; set; } = string.Empty;
}
