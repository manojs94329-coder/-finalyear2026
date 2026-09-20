using AmbulanceBooking.Api.Data;
using AmbulanceBooking.Api.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AmbulanceBooking.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _context;
    public UsersController(AppDbContext context) { _context = context; }

    [HttpGet("{userId}")]
    public async Task<IActionResult> GetProfile(int userId)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound("User not found.");

        return Ok(new
        {
            user.UserId,
            user.FullName,
            user.PhoneNumber,
            user.Email,
            user.BloodGroup,
            user.MedicalDetails,
            user.EmergencyContact,
            user.Latitude,
            user.Longitude,
            user.CreatedAt
        });
    }

    [HttpPut("{userId}")]
    public async Task<IActionResult> UpdateProfile(int userId, UpdateUserProfileDto dto)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound("User not found.");

        user.FullName = dto.FullName;
        user.PhoneNumber = dto.PhoneNumber;
        user.Email = dto.Email;
        user.BloodGroup = dto.BloodGroup;
        user.MedicalDetails = dto.MedicalDetails;
        user.EmergencyContact = dto.EmergencyContact;

        await _context.SaveChangesAsync();
        return Ok(new { message = "Profile updated successfully.", user });
    }
}
