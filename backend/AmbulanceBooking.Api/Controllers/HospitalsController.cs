using AmbulanceBooking.Api.Data;
using AmbulanceBooking.Api.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AmbulanceBooking.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HospitalsController : ControllerBase
{
    private readonly AppDbContext _context;

    public HospitalsController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetHospitals([FromQuery] decimal? lat, [FromQuery] decimal? lng)
    {
        var hospitals = await _context.Hospitals.ToListAsync();

        var dtos = hospitals.Select(h =>
        {
            double? distance = null;
            if (lat.HasValue && lng.HasValue)
            {
                // Simple approximate distance calculation in km
                var dLat = (double)(h.Latitude - lat.Value) * 111.0;
                var dLng = (double)(h.Longitude - lng.Value) * 111.0 * Math.Cos((double)lat.Value * Math.PI / 180.0);
                distance = Math.Round(Math.Sqrt(dLat * dLat + dLng * dLng), 1);
            }

            return new HospitalDto
            {
                HospitalId = h.HospitalId,
                Name = h.Name,
                ContactPhone = h.ContactPhone,
                Address = h.Address,
                Latitude = h.Latitude,
                Longitude = h.Longitude,
                HasEmergencyIcu = h.HasEmergencyIcu,
                AvailableIcuBeds = h.AvailableIcuBeds,
                TotalBeds = h.TotalBeds,
                DistanceKm = distance
            };
        }).OrderBy(x => x.DistanceKm ?? 0).ToList();

        return Ok(dtos);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetHospital(int id)
    {
        var hospital = await _context.Hospitals.FindAsync(id);
        if (hospital == null) return NotFound("Hospital not found.");
        return Ok(hospital);
    }

    [HttpPut("{id}/beds")]
    public async Task<IActionResult> UpdateBeds(int id, [FromBody] UpdateBedCapacityDto dto)
    {
        var hospital = await _context.Hospitals.FindAsync(id);
        if (hospital == null) return NotFound("Hospital not found.");

        hospital.AvailableIcuBeds = dto.AvailableIcuBeds;
        await _context.SaveChangesAsync();

        return Ok(new { message = "Hospital ICU bed count updated.", availableIcuBeds = hospital.AvailableIcuBeds });
    }
}
