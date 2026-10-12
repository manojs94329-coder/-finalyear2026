#!/usr/bin/env bash
# ==============================================================================
# Ambulance Booking System - 1-Click Automated Cloud Deployment Script
# Supports: Ubuntu 22.04 / 24.04 LTS (AWS EC2, DigitalOcean, Azure VM, etc.)
# ==============================================================================

set -e

echo "=========================================================="
echo "🚑 Deploying Ambulance Booking System to Cloud (24/7)"
echo "=========================================================="

# 1. Check Root / Sudo
if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

# 2. Install Docker & Docker Compose if missing
if ! command -v docker &> /dev/null; then
  echo "📦 Installing Docker engine..."
  $SUDO apt-get update -y
  $SUDO apt-get install -y ca-certificates curl gnupg lsb-release
  
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
  
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
  $SUDO systemctl enable --now docker
  echo "✅ Docker installed successfully."
fi

# 3. Create .env if not exists
if [ ! -f .env ]; then
  echo "⚙️ Creating default .env configuration..."
  cp .env.example .env
fi

# 4. Build and Start Services
echo "🚀 Building and launching Docker containers..."
$SUDO docker compose down --remove-orphans || true
$SUDO docker compose up -d --build

# 5. Wait for MySQL & API Health
echo "⏳ Waiting for MySQL database and API health check..."
for i in {1..30}; do
  if $SUDO docker compose ps | grep -q "ambulance_mysql.*healthy"; then
    echo "✅ MySQL Database is healthy."
    break
  fi
  sleep 2
done

sleep 5

# 6. Verify API HTTP 200
echo "🔍 Verifying API endpoint..."
if curl -sf http://127.0.0.1:5000/api/ambulances/available > /dev/null; then
  echo "✅ API successfully responding on port 5000."
else
  echo "⚠️ API is still warming up, check logs with: sudo docker compose logs -f api"
fi

# 7. Print Public Access Information
PUBLIC_IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org || echo "YOUR-SERVER-IP")

echo ""
echo "=========================================================="
echo "🎉 DEPLOYMENT COMPLETE! Services are running 24/7 in cloud."
echo "=========================================================="
echo "🌍 Web App & API: http://$PUBLIC_IP"
echo "📱 Download APK:  http://$PUBLIC_IP/download-apk"
echo "📊 Direct API:    http://$PUBLIC_IP:5000/api/ambulances/available"
echo "🗄️ MySQL Server:  $PUBLIC_IP:3306"
echo ""
echo "Useful Commands:"
echo "  • View Live Logs:  sudo docker compose logs -f"
echo "  • Restart Stack:   sudo docker compose restart"
echo "  • Stop Services:   sudo docker compose down"
echo "=========================================================="
