# 🚑 Smart Ambulance Booking & Emergency Response System

A full-stack, real-time emergency healthcare and ambulance booking platform featuring **Live GPS Tracking on Google Maps**, **Tamil Nadu Hospital ICU Bed & Ventilator Availability**, **Automatic Crash & Accident Detection via Mobile Sensors (7.5G Limit)**, **40-Second SOS Alarm Countdown**, and **Cross-Device Live Video & Audio Transmission** directly from the crash scene to responding paramedics and family contacts.

---

## 🌟 Key Highlights & Core Capabilities

### 1. 🗺️ Live GPS Tracking on Google Maps
- Real-time GPS location tracking for **Users (Patients)**, **Ambulance Drivers**, and **Admins**.
- Embedded Google Maps with smooth moving ambulance markers, polyline routing, distance calculations, and dynamic ETA estimation.
- One-tap navigation links opening native Google Maps turn-by-turn driving directions.

### 2. 🏥 Tamil Nadu Hospital Network & Live ICU Bed Tracker
- Real-time availability directory covering major government and private tertiary trauma centers across Tamil Nadu (Chennai, Coimbatore, Madurai, Salem, etc.).
- Tracks:
  - Total Beds vs. Available Beds
  - Available **ICU Beds**
  - **Ventilators** and **Liquid Medical Oxygen (LMO)** capacities
  - Respective attached 108 ALS / BLS ambulance units

### 3. 💥 Automatic Crash & Over-Shaking Detection (7.5G Limit)
- Real-time mobile sensor integration (`devicemotion`, Accelerometer & Gyroscope).
- Computes resultant 3-axis G-Force ($G = \sqrt{x^2 + y^2 + z^2} / 9.8$) and vibration intensity ($0-100\%$).
- Detects violent collisions and high-impact spikes reaching or exceeding the configured **7.5 G** limit.
- Real-time telemetry HUD displaying X, Y, Z acceleration readouts and dynamic alert indicators.

### 4. ⏱️ 40-Second SOS Alarm Countdown & Automatic 108 Dispatch
- 40-second high-priority countdown ring with loud emergency siren audio.
- Cancel window: `"I AM OK - CANCEL DISPATCH"` prevents false dispatches within the 40s window.
- Immediate dispatch option: `"DISPATCH IMMEDIATELY (NO WAIT)"`.
- Auto-dispatches nearest 108 Advanced Life Support (ALS) Ambulance (`TN-01-EM-1080` / M. Murugan) upon countdown completion.

### 5. 📹 Cross-Device Live Video & Audio Transmission Relay
- Real-time camera and microphone streaming from the crash scene directly to the responding ambulance driver and secondary contact.
- In-memory ASP.NET Core streaming relay (`/api/emergencies/{id}/stream`) with rapid JPEG base64 frame encoding (~5-6 FPS) and Web Audio API decibel metering.
- Dynamic 24-band animated waveform equalizer responding to audio at the crash site.
- Infrared / Night-Vision thermal HUD fail-safe fallback if camera hardware is restricted.

### 6. 📲 Android APK & Instant PWA Installation
- Direct Android APK distribution (`/ambulance-app.apk`) for immediate mobile sideloading.
- Progressive Web App (PWA) manifest support for one-tap "Add to Home Screen" on Android and iOS.

---

## 🛠️ Architecture & Tech Stack

```text
AmbulanceBookingSystem/
├── backend/AmbulanceBooking.Api/      # ASP.NET Core 8 Web API & In-Memory Video Relay
├── database/                          # MySQL 8.0 Schema & Tamil Nadu Seed Data
└── mobile/ambulance_booking_app/      # Flutter 3.44 Cross-Platform Web & Mobile App
```

- **Frontend**: Flutter 3.44 (Dart 3.12) with Material Design 3, Google Maps SDK, Web Audio API, HTML5 MediaStream.
- **Backend**: ASP.NET Core 8.0, Entity Framework Core, JWT Authentication, In-Memory Stream Buffer.
- **Database**: MySQL 8.0 with InnoDB relational tables.
- **Networking**: Cloudflare Tunnel for secure HTTPS edge routing.

---

## 🚀 Getting Started

### 1. Database Setup
```bash
mysql -u root -p < database/ambulance_booking_schema.sql
mysql -u root -p < database/seed_data.sql
```

### 2. Backend API
```bash
cd backend/AmbulanceBooking.Api
dotnet restore
dotnet build
dotnet run --launch-profile http
```
API runs on `http://localhost:5000` (Swagger UI at `/swagger`).

### 3. Flutter Web / Mobile App
```bash
cd mobile/ambulance_booking_app
flutter pub get
flutter run -d chrome
```

Or build for production web release:
```bash
flutter build web --release --no-wasm-dry-run
```

---

## 🔑 Demo Accounts

| Role | Username / Mobile | Password |
| :--- | :--- | :--- |
| **Citizen (Patient)** | `9876543210` | `password123` |
| **Ambulance Driver** | `9876543210` | `password123` |
| **Admin** | `9999999999` | `admin123` |

---

## 📜 License
MIT License. Built for emergency response and smart healthcare dispatch.
