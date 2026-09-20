using AmbulanceBooking.Api.Data;
using AmbulanceBooking.Api.DTOs;
using AmbulanceBooking.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AmbulanceBooking.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BookingsController : ControllerBase
{
    private readonly AppDbContext _context;
    public BookingsController(AppDbContext context) { _context = context; }

    [HttpPost("request")]
    public async Task<IActionResult> RequestAmbulance(BookingRequestDto dto)
    {
        var nearestAmbulance = await _context.Ambulances
            .Where(x => x.IsApproved && x.Status == "Available" && x.CurrentLatitude != null && x.CurrentLongitude != null)
            .OrderBy(x => Math.Pow((double)(x.CurrentLatitude!.Value - dto.PickupLatitude), 2) + Math.Pow((double)(x.CurrentLongitude!.Value - dto.PickupLongitude), 2))
            .FirstOrDefaultAsync();

        string destHospital = dto.DestinationHospital ?? string.Empty;
        if (dto.HospitalId.HasValue && string.IsNullOrEmpty(destHospital))
        {
            var h = await _context.Hospitals.FindAsync(dto.HospitalId.Value);
            if (h != null) destHospital = h.Name;
        }

        var booking = new Booking
        {
            UserId = dto.UserId,
            AmbulanceId = nearestAmbulance?.AmbulanceId,
            HospitalId = dto.HospitalId,
            PickupLatitude = dto.PickupLatitude,
            PickupLongitude = dto.PickupLongitude,
            DestinationHospital = string.IsNullOrEmpty(destHospital) ? "Nearest Emergency Trauma Center" : destHospital,
            PatientCondition = dto.PatientCondition,
            EstimatedPrice = dto.EstimatedPrice ?? 650.00m,
            EquipmentAddons = dto.EquipmentAddons ?? "Oxygen, Stretcher",
            EstimatedEtaMinutes = dto.EstimatedEtaMinutes ?? 8,
            Status = "Requested",
            BookingTime = DateTime.Now
        };

        _context.Bookings.Add(booking);
        if (nearestAmbulance != null) nearestAmbulance.Status = "Busy";
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = nearestAmbulance == null
                ? "Emergency request broadcasted. Waiting for dispatch assignment."
                : "Ambulance dispatched successfully.",
            bookingId = booking.BookingId,
            ambulanceId = nearestAmbulance?.AmbulanceId,
            estimatedPrice = booking.EstimatedPrice,
            equipmentAddons = booking.EquipmentAddons,
            estimatedEtaMinutes = booking.EstimatedEtaMinutes,
            hospitalId = booking.HospitalId
        });
    }

    [HttpGet("{bookingId}")]
    public async Task<IActionResult> GetBooking(int bookingId)
    {
        var booking = await _context.Bookings
            .Include(x => x.User)
            .Include(x => x.Ambulance)
            .Include(x => x.Hospital)
            .FirstOrDefaultAsync(x => x.BookingId == bookingId);

        if (booking == null) return NotFound("Booking not found.");

        return Ok(new
        {
            booking.BookingId,
            booking.UserId,
            booking.Status,
            booking.PickupLatitude,
            booking.PickupLongitude,
            booking.DestinationHospital,
            booking.PatientCondition,
            booking.EstimatedPrice,
            booking.EquipmentAddons,
            booking.EstimatedEtaMinutes,
            booking.HospitalId,
            booking.BookingTime,
            booking.AcceptedTime,
            booking.CompletedTime,
            User = booking.User == null ? null : new
            {
                booking.User.UserId,
                booking.User.FullName,
                booking.User.PhoneNumber,
                booking.User.Email,
                booking.User.BloodGroup,
                booking.User.MedicalDetails,
                booking.User.EmergencyContact
            },
            Ambulance = booking.Ambulance == null ? null : new
            {
                booking.Ambulance.AmbulanceId,
                booking.Ambulance.DriverName,
                booking.Ambulance.DriverPhone,
                booking.Ambulance.VehicleNumber,
                booking.Ambulance.AmbulanceType,
                booking.Ambulance.CurrentLatitude,
                booking.Ambulance.CurrentLongitude,
                booking.Ambulance.Status
            },
            Hospital = booking.Hospital == null ? null : new
            {
                booking.Hospital.HospitalId,
                booking.Hospital.Name,
                booking.Hospital.Address,
                booking.Hospital.ContactPhone,
                booking.Hospital.AvailableIcuBeds,
                booking.Hospital.HasEmergencyIcu
            }
        });
    }

    [HttpGet("user/{userId}")]
    public async Task<IActionResult> GetUserBookings(int userId)
    {
        var bookings = await _context.Bookings
            .Include(x => x.Ambulance)
            .Include(x => x.Hospital)
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.BookingTime)
            .Select(b => new
            {
                b.BookingId,
                b.Status,
                b.PickupLatitude,
                b.PickupLongitude,
                b.DestinationHospital,
                b.PatientCondition,
                b.EstimatedPrice,
                b.EquipmentAddons,
                b.EstimatedEtaMinutes,
                b.BookingTime,
                b.AcceptedTime,
                b.CompletedTime,
                Ambulance = b.Ambulance == null ? null : new
                {
                    b.Ambulance.AmbulanceId,
                    b.Ambulance.DriverName,
                    b.Ambulance.DriverPhone,
                    b.Ambulance.VehicleNumber,
                    b.Ambulance.AmbulanceType,
                    b.Ambulance.CurrentLatitude,
                    b.Ambulance.CurrentLongitude
                },
                Hospital = b.Hospital == null ? null : new
                {
                    b.Hospital.HospitalId,
                    b.Hospital.Name,
                    b.Hospital.Address,
                    b.Hospital.ContactPhone,
                    b.Hospital.AvailableIcuBeds
                }
            })
            .ToListAsync();

        return Ok(bookings);
    }

    [HttpGet("driver/{ambulanceId}/active")]
    public async Task<IActionResult> GetDriverActiveBooking(int ambulanceId)
    {
        var booking = await _context.Bookings
            .Include(x => x.User)
            .Include(x => x.Hospital)
            .Where(x => x.AmbulanceId == ambulanceId && (x.Status == "Requested" || x.Status == "Accepted" || x.Status == "InProgress"))
            .OrderByDescending(x => x.BookingTime)
            .FirstOrDefaultAsync();

        if (booking == null) return Ok(null);

        return Ok(new
        {
            booking.BookingId,
            booking.UserId,
            booking.Status,
            booking.PickupLatitude,
            booking.PickupLongitude,
            booking.DestinationHospital,
            booking.PatientCondition,
            booking.EstimatedPrice,
            booking.EquipmentAddons,
            booking.EstimatedEtaMinutes,
            booking.HospitalId,
            booking.BookingTime,
            booking.AcceptedTime,
            User = booking.User == null ? null : new
            {
                booking.User.UserId,
                booking.User.FullName,
                booking.User.PhoneNumber,
                booking.User.Email,
                booking.User.BloodGroup,
                booking.User.MedicalDetails,
                booking.User.EmergencyContact
            },
            Hospital = booking.Hospital == null ? null : new
            {
                booking.Hospital.HospitalId,
                booking.Hospital.Name,
                booking.Hospital.Address,
                booking.Hospital.ContactPhone,
                booking.Hospital.AvailableIcuBeds
            }
        });
    }

    [HttpGet("driver/{ambulanceId}/history")]
    public async Task<IActionResult> GetDriverHistory(int ambulanceId)
    {
        var history = await _context.Bookings
            .Include(x => x.User)
            .Where(x => x.AmbulanceId == ambulanceId)
            .OrderByDescending(x => x.BookingTime)
            .Select(b => new
            {
                b.BookingId,
                b.Status,
                b.DestinationHospital,
                b.PatientCondition,
                b.EstimatedPrice,
                b.EquipmentAddons,
                b.BookingTime,
                b.AcceptedTime,
                b.CompletedTime,
                UserName = b.User != null ? b.User.FullName : "Unknown",
                UserPhone = b.User != null ? b.User.PhoneNumber : ""
            })
            .ToListAsync();

        return Ok(history);
    }

    [HttpPut("{bookingId}/accept")]
    public async Task<IActionResult> AcceptBooking(int bookingId)
    {
        var booking = await _context.Bookings.FindAsync(bookingId);
        if (booking == null) return NotFound("Booking not found.");
        booking.Status = "Accepted";
        booking.AcceptedTime = DateTime.Now;
        await _context.SaveChangesAsync();
        return Ok(new { message = "Mission accepted. En route to patient.", status = booking.Status });
    }

    [HttpPut("{bookingId}/status")]
    public async Task<IActionResult> UpdateBookingStatus(int bookingId, [FromBody] UpdateStatusRequest req)
    {
        var booking = await _context.Bookings.FindAsync(bookingId);
        if (booking == null) return NotFound("Booking not found.");

        booking.Status = req.Status;
        if (req.Status == "Accepted" && booking.AcceptedTime == null)
        {
            booking.AcceptedTime = DateTime.Now;
        }
        else if (req.Status == "Completed")
        {
            booking.CompletedTime = DateTime.Now;
            if (booking.AmbulanceId.HasValue)
            {
                var ambulance = await _context.Ambulances.FindAsync(booking.AmbulanceId.Value);
                if (ambulance != null) ambulance.Status = "Available";
            }
        }
        else if (req.Status == "Cancelled" && booking.AmbulanceId.HasValue)
        {
            var ambulance = await _context.Ambulances.FindAsync(booking.AmbulanceId.Value);
            if (ambulance != null) ambulance.Status = "Available";
        }

        await _context.SaveChangesAsync();
        return Ok(new { message = $"Status updated to {booking.Status}", status = booking.Status });
    }

    [HttpPut("{bookingId}/complete")]
    public async Task<IActionResult> CompleteBooking(int bookingId)
    {
        var booking = await _context.Bookings.FindAsync(bookingId);
        if (booking == null) return NotFound("Booking not found.");

        booking.Status = "Completed";
        booking.CompletedTime = DateTime.Now;

        if (booking.AmbulanceId.HasValue)
        {
            var ambulance = await _context.Ambulances.FindAsync(booking.AmbulanceId.Value);
            if (ambulance != null) ambulance.Status = "Available";
        }

        await _context.SaveChangesAsync();
        return Ok(new { message = "Mission completed successfully. Ambulance is now Available.", status = booking.Status });
    }

    [HttpPut("{bookingId}/cancel")]
    public async Task<IActionResult> CancelBooking(int bookingId)
    {
        var booking = await _context.Bookings.FindAsync(bookingId);
        if (booking == null) return NotFound("Booking not found.");

        booking.Status = "Cancelled";
        if (booking.AmbulanceId.HasValue)
        {
            var ambulance = await _context.Ambulances.FindAsync(booking.AmbulanceId.Value);
            if (ambulance != null) ambulance.Status = "Available";
        }

        await _context.SaveChangesAsync();
        return Ok(new { message = "Emergency booking cancelled.", status = booking.Status });
    }

    [HttpPut("{bookingId}/reject")]
    public async Task<IActionResult> RejectBooking(int bookingId)
    {
        var booking = await _context.Bookings.FindAsync(bookingId);
        if (booking == null) return NotFound("Booking not found.");

        if (booking.AmbulanceId.HasValue)
        {
            var ambulance = await _context.Ambulances.FindAsync(booking.AmbulanceId.Value);
            if (ambulance != null) ambulance.Status = "Available";
        }

        var nextAmbulance = await _context.Ambulances
            .Where(x => x.IsApproved && x.Status == "Available" && x.AmbulanceId != booking.AmbulanceId)
            .FirstOrDefaultAsync();

        if (nextAmbulance != null)
        {
            booking.AmbulanceId = nextAmbulance.AmbulanceId;
            booking.Status = "Requested";
            nextAmbulance.Status = "Busy";
        }
        else
        {
            booking.AmbulanceId = null;
            booking.Status = "Requested";
        }

        await _context.SaveChangesAsync();
        return Ok(new { message = "Booking declined and returned to dispatch pool.", reallocatedAmbulanceId = nextAmbulance?.AmbulanceId });
    }
}

public class UpdateStatusRequest
{
    public string Status { get; set; } = string.Empty;
}
