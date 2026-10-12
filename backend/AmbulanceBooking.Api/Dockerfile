# ========================================================
# Dockerfile: Ambulance Booking System (ASP.NET Core + Web)
# ========================================================

# Stage 1: Build & Publish
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file and restore dependencies
COPY AmbulanceBooking.Api.csproj ./
RUN dotnet restore AmbulanceBooking.Api.csproj

# Copy remaining source code (including wwwroot web frontend & APK)
COPY . ./
RUN dotnet publish AmbulanceBooking.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

# Stage 2: Production Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Install curl for container health probes
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# Copy published binaries & static assets from build stage
COPY --from=build /app/publish ./

# Default ASP.NET Core environment settings
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production

EXPOSE 5000

# Health check probe
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:5000/api/ambulances/available || exit 1

ENTRYPOINT ["dotnet", "AmbulanceBooking.Api.dll"]
