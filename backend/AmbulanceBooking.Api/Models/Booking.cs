using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AmbulanceBooking.Api.Models;

[Table("bookings")]
public class Booking
{
    [Key]
    [Column("booking_id")]
    public int BookingId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Column("ambulance_id")]
    public int? AmbulanceId { get; set; }

    [Column("hospital_id")]
    public int? HospitalId { get; set; }

    [Column("pickup_latitude")]
    public decimal PickupLatitude { get; set; }

    [Column("pickup_longitude")]
    public decimal PickupLongitude { get; set; }

    [Column("destination_hospital")]
    public string? DestinationHospital { get; set; }

    [Column("patient_condition")]
    public string? PatientCondition { get; set; }

    [Column("estimated_price")]
    public decimal? EstimatedPrice { get; set; } = 650.00m;

    [Column("equipment_addons")]
    public string? EquipmentAddons { get; set; }

    [Column("estimated_eta_minutes")]
    public int? EstimatedEtaMinutes { get; set; } = 8;

    [Column("status")]
    public string Status { get; set; } = "Requested";

    [Column("booking_time")]
    public DateTime BookingTime { get; set; }

    [Column("accepted_time")]
    public DateTime? AcceptedTime { get; set; }

    [Column("completed_time")]
    public DateTime? CompletedTime { get; set; }

    public User? User { get; set; }
    public Ambulance? Ambulance { get; set; }
    public Hospital? Hospital { get; set; }
}
