# 🌐 24/7 Standalone Cloud Deployment Guide

## Overview
This guide provides complete instructions to deploy the **Ambulance Booking System** (MySQL 8.0 Database + ASP.NET Core 8 Web API + Flutter Web Frontend + Android APK Download) to a standalone cloud server so that it stays online **24 hours a day, 7 days a week, 365 days a year** without depending on your local computer.

---

## 🏗️ Cloud Architecture

```
                    Internet Users (Mobile & Web)
                                │
                                ▼
                   ┌──────────────────────────┐
                   │ Cloud Server (Linux VPS) │
                   │  Port 80 (HTTP / HTTPS)  │
                   └────────────┬─────────────┘
                                │
          ┌─────────────────────┴─────────────────────┐
          ▼                                           ▼
┌─────────────────────────────────┐       ┌───────────────────────┐
│ Container: ambulance_api        │       │ Container:            │
│  - ASP.NET Core 8 REST API      │       │ ambulance_mysql       │
│  - Flutter Web Application      │◄─────►│  - MySQL 8.0 Server   │
│  - /download-apk (55MB Android) │       │  - Auto-seeded DB     │
│  - Listening on Port 5000 / 80  │       │  - Persistent Volume  │
└─────────────────────────────────┘       └───────────────────────┘
```

---

## 📁 Prepared Deployment Files in Your Repository

| File | Purpose |
| :--- | :--- |
| [`Dockerfile`](file:///c:/Users/WIN%2010/Downloads/AmbulanceBookingSystem_SourceCode%20(1)/AmbulanceBookingSystem/backend/AmbulanceBooking.Api/Dockerfile) | Multi-stage production container for ASP.NET Core 8 API & Flutter Web app |
| [`docker-compose.yml`](file:///c:/Users/WIN%2010/Downloads/AmbulanceBookingSystem_SourceCode%20(1)/AmbulanceBookingSystem/docker-compose.yml) | Orchestrates MySQL 8.0 + API with persistent storage and healthchecks |
| [`full_cloud_init.sql`](file:///c:/Users/WIN%2010/Downloads/AmbulanceBookingSystem_SourceCode%20(1)/AmbulanceBookingSystem/database/full_cloud_init.sql) | Full database schema + Tamil Nadu emergency hospital & 108 ambulance fleet |
| [`deploy_cloud.sh`](file:///c:/Users/WIN%2010/Downloads/AmbulanceBookingSystem_SourceCode%20(1)/AmbulanceBookingSystem/deploy_cloud.sh) | 1-Click bash script to install Docker, build images, and launch services |
| [`.env.example`](file:///c:/Users/WIN%2010/Downloads/AmbulanceBookingSystem_SourceCode%20(1)/AmbulanceBookingSystem/.env.example) | Environment variable template (database passwords, JWT secret) |

---

## 🚀 Deployment Options

### Option 1: Any Linux Cloud VPS (DigitalOcean / Hetzner / Linode) — *Recommended & Easiest*
*Estimated cost: \$4 to \$6 / month (no unexpected bills)*

1. Create a Linux VPS running **Ubuntu 22.04 LTS** or **Ubuntu 24.04 LTS** (minimum 1GB RAM / 1 vCPU; 2GB RAM recommended).
2. SSH into your cloud server:
   ```bash
   ssh root@<YOUR_SERVER_IP>
   ```
3. Clone your GitHub repository and run the 1-click deployment script:
   ```bash
   git clone https://github.com/manojs94329-coder/-finalyear2026.git ambulance-system
   cd ambulance-system
   chmod +x deploy_cloud.sh
   ./deploy_cloud.sh
   ```
4. **Done!** The script automatically:
   - Installs Docker & Docker Compose
   - Seeds the MySQL database with hospitals and ambulances
   - Builds and boots the ASP.NET Core web container
   - Configures automatic restart on server reboot (`restart: always`)
   - Prints your live access URLs (`http://<YOUR_SERVER_IP>`)

---

### Option 2: AWS EC2 (Eligible for 12 Months Free Tier)
*Estimated cost: Free for the first year with AWS Free Tier*

1. Log in to the [AWS Management Console](https://aws.amazon.com/console/).
2. Navigate to **EC2** > **Launch Instance**:
   - **Name**: `Ambulance-Booking-Server`
   - **OS**: Ubuntu Server 24.04 LTS (x86_64)
   - **Instance type**: `t2.micro` or `t3.micro` (Free tier eligible)
   - **Key pair**: Select or create a key pair (`.pem`)
3. Under **Network settings**:
   - Check **Allow SSH traffic from Anywhere** (Port 22)
   - Check **Allow HTTP traffic from the internet** (Port 80)
   - Add Custom TCP Rule: **Port 5000** (Anywhere `0.0.0.0/0`)
4. Click **Launch Instance**.
5. Connect via SSH:
   ```bash
   ssh -i your-key.pem ubuntu@<EC2_PUBLIC_DNS_OR_IP>
   ```
6. Run the 1-click installer:
   ```bash
   git clone https://github.com/manojs94329-coder/-finalyear2026.git ambulance-system
   cd ambulance-system
   chmod +x deploy_cloud.sh
   ./deploy_cloud.sh
   ```

---

### Option 3: Microsoft Azure (Azure Linux VM)
1. In the [Azure Portal](https://portal.azure.com/), create a **Virtual Machine**:
   - **Image**: Ubuntu Server 24.04 LTS
   - **Size**: `Standard_B1s` or `Standard_B2s`
2. Under **Networking**:
   - Open Inbound Ports: `22` (SSH), `80` (HTTP), `5000` (API)
3. SSH into the VM and execute:
   ```bash
   git clone https://github.com/manojs94329-coder/-finalyear2026.git ambulance-system
   cd ambulance-system
   chmod +x deploy_cloud.sh
   ./deploy_cloud.sh
   ```

---

## 🔒 Free Permanent HTTPS Domain (Zero Trust Cloudflare Tunnel)

To secure your cloud server with a free HTTPS domain (e.g. `https://emergency-ambulance.yourdomain.com`) with zero open inbound ports:

1. Create a free account at [Cloudflare Zero Trust](https://one.dash.cloudflare.com/).
2. Go to **Networks** > **Tunnels** > **Create a Tunnel**.
3. Name your tunnel `ambulance-cloud`.
4. Copy the provided Docker run command or token (`eyJhIjoi...`).
5. In your cloud server's `.env` file, uncomment:
   ```env
   CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoi...
   ```
6. Under **Public Hostname** in Cloudflare, map your domain to service:
   `http://api:5000`
7. Your cloud server is now protected with 24/7 enterprise-grade SSL and DDoS defense!

---

## 🛠️ Server Management Commands

| Action | Command |
| :--- | :--- |
| **Check Live Service Status** | `sudo docker compose ps` |
| **Stream Live API Logs** | `sudo docker compose logs -f api` |
| **Stream Live MySQL Logs** | `sudo docker compose logs -f mysql` |
| **Restart All Services** | `sudo docker compose restart` |
| **Update to Latest Code** | `git pull && sudo docker compose up -d --build` |
| **Backup MySQL Database** | `sudo docker compose exec mysql mysqldump -u root -p'Emergency@Secure2026!' ambulance_booking_db > backup.sql` |
