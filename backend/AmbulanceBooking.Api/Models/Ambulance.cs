using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AmbulanceBooking.Api.Models;

[Table("ambulances")]
public class Ambulance
{
    [Key]
    [Column("ambulance_id")]
    public int AmbulanceId { get; set; }

    [Column("driver_name")]
    public string DriverName { get; set; } = string.Empty;

    [Column("driver_phone")]
    public string DriverPhone { get; set; } = string.Empty;

    [Column("email")]
    public string? Email { get; set; }

    [Column("password_hash")]
    public string PasswordHash { get; set; } = string.Empty;

    [Column("vehicle_number")]
    public string VehicleNumber { get; set; } = string.Empty;

    [Column("ambulance_type")]
    public string? AmbulanceType { get; set; }

    [Column("current_latitude")]
    public decimal? CurrentLatitude { get; set; }

    [Column("current_longitude")]
    public decimal? CurrentLongitude { get; set; }

    [Column("status")]
    public string Status { get; set; } = "PendingApproval";

    [Column("is_approved")]
    public bool IsApproved { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }
}
