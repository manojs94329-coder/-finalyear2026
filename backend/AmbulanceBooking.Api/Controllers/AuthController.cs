using AmbulanceBooking.Api.Data;
using AmbulanceBooking.Api.DTOs;
using AmbulanceBooking.Api.Models;
using AmbulanceBooking.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AmbulanceBooking.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IPasswordService _passwordService;
    private readonly IJwtService _jwtService;

    public AuthController(AppDbContext context, IPasswordService passwordService, IJwtService jwtService)
    {
        _context = context;
        _passwordService = passwordService;
        _jwtService = jwtService;
    }

    [HttpPost("register-user")]
    public async Task<IActionResult> RegisterUser(RegisterUserDto dto)
    {
        var phone = dto.PhoneNumber?.Trim() ?? string.Empty;
        var email = string.IsNullOrWhiteSpace(dto.Email) ? null : dto.Email.Trim();
        var name = dto.FullName?.Trim() ?? string.Empty;

        if (string.IsNullOrEmpty(name)) return BadRequest("Full Name is required.");
        if (string.IsNullOrEmpty(phone)) return BadRequest("Phone Number is required.");
        if (string.IsNullOrEmpty(dto.Password)) return BadRequest("Password is required.");

        var phoneExists = await _context.Users.AnyAsync(x => x.PhoneNumber == phone);
        if (phoneExists)
        {
            return BadRequest($"An account with phone number '{phone}' already exists. Please log in instead.");
        }

        if (email != null)
        {
            var emailExists = await _context.Users.AnyAsync(x => x.Email == email);
            if (emailExists)
            {
                return BadRequest($"An account with email '{email}' already exists. Please log in or use another email.");
            }
        }

        var user = new User
        {
            FullName = name,
            PhoneNumber = phone,
            Email = email,
            PasswordHash = _passwordService.HashPassword(dto.Password),
            BloodGroup = dto.BloodGroup,
            MedicalDetails = dto.MedicalDetails,
            EmergencyContact = dto.EmergencyContact,
            CreatedAt = DateTime.Now
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return Ok(new { message = "User registered successfully", userId = user.UserId });
    }

    [HttpPost("register-ambulance")]
    public async Task<IActionResult> RegisterAmbulance(RegisterAmbulanceDto dto)
    {
        var phone = dto.DriverPhone?.Trim() ?? string.Empty;
        var vehicle = dto.VehicleNumber?.Trim() ?? string.Empty;
        var email = string.IsNullOrWhiteSpace(dto.Email) ? null : dto.Email.Trim();

        if (string.IsNullOrEmpty(phone)) return BadRequest("Driver Phone is required.");
        if (string.IsNullOrEmpty(vehicle)) return BadRequest("Vehicle Number is required.");

        var phoneExists = await _context.Ambulances.AnyAsync(x => x.DriverPhone == phone);
        if (phoneExists) return BadRequest($"An ambulance driver with phone '{phone}' already exists. Please log in.");

        var vehicleExists = await _context.Ambulances.AnyAsync(x => x.VehicleNumber == vehicle);
        if (vehicleExists) return BadRequest($"Vehicle '{vehicle}' is already registered.");

        var ambulance = new Ambulance
        {
            DriverName = dto.DriverName?.Trim() ?? "Driver",
            DriverPhone = phone,
            Email = email,
            PasswordHash = _passwordService.HashPassword(dto.Password),
            VehicleNumber = vehicle,
            AmbulanceType = dto.AmbulanceType ?? "Basic Life Support",
            CurrentLatitude = dto.CurrentLatitude,
            CurrentLongitude = dto.CurrentLongitude,
            Status = "PendingApproval",
            IsApproved = false,
            CreatedAt = DateTime.Now
        };

        _context.Ambulances.Add(ambulance);
        await _context.SaveChangesAsync();
        return Ok(new { message = "Ambulance registered. Waiting for admin approval.", ambulanceId = ambulance.AmbulanceId });
    }

    [HttpPost("register-admin")]
    public async Task<IActionResult> RegisterAdmin(RegisterAdminDto dto)
    {
        var email = dto.Email?.Trim() ?? string.Empty;
        if (string.IsNullOrEmpty(email)) return BadRequest("Admin Email is required.");

        var exists = await _context.Admins.AnyAsync(x => x.Email == email);
        if (exists) return BadRequest($"Admin account '{email}' already exists. Please log in.");

        var admin = new Admin
        {
            FullName = dto.FullName?.Trim() ?? "Admin",
            Email = email,
            PasswordHash = _passwordService.HashPassword(dto.Password),
            CreatedAt = DateTime.Now
        };

        _context.Admins.Add(admin);
        await _context.SaveChangesAsync();
        return Ok(new { message = "Admin registered successfully", adminId = admin.AdminId });
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequestDto dto)
    {
        var identifier = dto.PhoneOrEmail?.Trim() ?? string.Empty;
        var password = dto.Password?.Trim() ?? string.Empty;

        if (dto.Role == "User")
        {
            var user = await _context.Users.FirstOrDefaultAsync(x => 
                x.PhoneNumber == identifier || 
                x.Email == identifier || 
                x.FullName == identifier);

            if (user == null) return Unauthorized("User account not found. Please check your phone, email, or name.");
            if (!_passwordService.VerifyPassword(password, user.PasswordHash)) return Unauthorized("Incorrect password for user account.");

            var token = _jwtService.GenerateToken(user.UserId, user.FullName, "User");
            return Ok(new { token, role = "User", id = user.UserId, name = user.FullName });
        }

        if (dto.Role == "Driver")
        {
            var ambulance = await _context.Ambulances.FirstOrDefaultAsync(x => 
                x.DriverPhone == identifier || 
                x.Email == identifier || 
                x.DriverName == identifier || 
                x.VehicleNumber == identifier);

            if (ambulance == null) return Unauthorized("Driver not found. You can sign in with Driver Name, Phone, Email, or Vehicle Number.");
            if (!_passwordService.VerifyPassword(password, ambulance.PasswordHash)) return Unauthorized("Incorrect password for driver account.");
            if (!ambulance.IsApproved) return Unauthorized("Ambulance is pending approval. An admin must approve it from the Admin Dashboard first.");

            var token = _jwtService.GenerateToken(ambulance.AmbulanceId, ambulance.DriverName, "Driver");
            return Ok(new { token, role = "Driver", id = ambulance.AmbulanceId, name = ambulance.DriverName });
        }

        if (dto.Role == "Admin")
        {
            var admin = await _context.Admins.FirstOrDefaultAsync(x => 
                x.Email == identifier || 
                x.FullName == identifier);

            if (admin == null) return Unauthorized("Admin not found. Use admin email or name.");
            if (!_passwordService.VerifyPassword(password, admin.PasswordHash)) return Unauthorized("Incorrect password for admin account.");

            var token = _jwtService.GenerateToken(admin.AdminId, admin.FullName, "Admin");
            return Ok(new { token, role = "Admin", id = admin.AdminId, name = admin.FullName });
        }

        return BadRequest("Invalid role.");
    }
}
