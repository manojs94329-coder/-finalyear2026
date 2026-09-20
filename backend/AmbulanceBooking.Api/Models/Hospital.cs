using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AmbulanceBooking.Api.Models;

[Table("hospitals")]
public class Hospital
{
    [Key]
    [Column("hospital_id")]
    public int HospitalId { get; set; }

    [Column("name")]
    public string Name { get; set; } = string.Empty;

    [Column("contact_phone")]
    public string ContactPhone { get; set; } = string.Empty;

    [Column("address")]
    public string Address { get; set; } = string.Empty;

    [Column("latitude")]
    public decimal Latitude { get; set; }

    [Column("longitude")]
    public decimal Longitude { get; set; }

    [Column("has_emergency_icu")]
    public bool HasEmergencyIcu { get; set; } = true;

    [Column("available_icu_beds")]
    public int AvailableIcuBeds { get; set; } = 10;

    [Column("total_beds")]
    public int TotalBeds { get; set; } = 50;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}
