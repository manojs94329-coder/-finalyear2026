using AmbulanceBooking.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace AmbulanceBooking.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<Ambulance> Ambulances => Set<Ambulance>();
    public DbSet<Booking> Bookings => Set<Booking>();
    public DbSet<Admin> Admins => Set<Admin>();
    public DbSet<Hospital> Hospitals => Set<Hospital>();
}
