using AmbulanceBooking.Api.Data;
using AmbulanceBooking.Api.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AmbulanceBooking.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AmbulancesController : ControllerBase
{
    private readonly AppDbContext _context;
    public AmbulancesController(AppDbContext context) { _context = context; }

    [HttpGet("available")]
    public async Task<IActionResult> GetAvailableAmbulances()
    {
        var ambulances = await _context.Ambulances
            .Where(x => x.IsApproved && x.Status == "Available")
            .Select(x => new { x.AmbulanceId, x.DriverName, x.DriverPhone, x.VehicleNumber, x.AmbulanceType, x.CurrentLatitude, x.CurrentLongitude, x.Status })
            .ToListAsync();
        return Ok(ambulances);
    }

    [HttpGet("{ambulanceId}")]
    public async Task<IActionResult> GetAmbulance(int ambulanceId)
    {
        var x = await _context.Ambulances.FindAsync(ambulanceId);
        if (x == null) return NotFound("Ambulance not found.");
        return Ok(new
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
            x.IsApproved
        });
    }

    [HttpPut("{ambulanceId}/location")]
    public async Task<IActionResult> UpdateLocation(int ambulanceId, UpdateLocationDto dto)
    {
        var ambulance = await _context.Ambulances.FindAsync(ambulanceId);
        if (ambulance == null) return NotFound("Ambulance not found.");
        ambulance.CurrentLatitude = dto.Latitude;
        ambulance.CurrentLongitude = dto.Longitude;
        await _context.SaveChangesAsync();
        return Ok("Location updated successfully.");
    }

    [HttpPut("{ambulanceId}/status")]
    public async Task<IActionResult> UpdateStatus(int ambulanceId, string status)
    {
        var ambulance = await _context.Ambulances.FindAsync(ambulanceId);
        if (ambulance == null) return NotFound("Ambulance not found.");
        ambulance.Status = status;
        await _context.SaveChangesAsync();
        return Ok("Status updated successfully.");
    }
}
