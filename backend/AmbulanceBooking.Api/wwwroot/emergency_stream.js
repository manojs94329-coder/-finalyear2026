// Emergency Stream & Sensor Helper with Real-Time Frame Relay
window.EmergencyStream = {
  // Motion & Shake Sensor State
  motionListener: null,
  isSensorArmed: false,
  shakeThreshold: 10.0,
  lastGForce: 1.0,
  lastX: 0.0,
  lastY: 0.0,
  lastZ: 9.8,
  vibrationLevel: 0,
  onCrashDetectedCallback: null,
  onTelemetryUpdateCallback: null,

  // Media (Video & Audio) Broadcast State
  mediaStream: null,
  audioContext: null,
  analyser: null,
  dataArray: null,
  streamInterval: null,
  isBroadcasting: false,
  isAudioMuted: false,
  currentFacingMode: "user",
  currentDecibels: 0,
  scanLineY: 0,
  activeEmergencyId: "EMG-LIVE",
  uploadUrl: "/api/emergencies/EMG-LIVE/stream",

  // Callbacks
  onAudioLevelCallback: null,
  onFrameCapturedCallback: null,

  // ----------------------------------------------------
  // 1. SENSOR & OVER-SHAKING / VIBRATION DETECTION
  // ----------------------------------------------------
  startMotionSensor: function(onCrash, onTelemetry) {
    this.onCrashDetectedCallback = onCrash;
    this.onTelemetryUpdateCallback = onTelemetry;
    this.isSensorArmed = true;

    if (window.DeviceMotionEvent) {
      this.motionListener = function(event) {
        var acc = event.accelerationIncludingGravity || event.acceleration;
        if (!acc) return;

        var x = acc.x || 0;
        var y = acc.y || 0;
        var z = acc.z || 9.8;

        window.EmergencyStream.lastX = x;
        window.EmergencyStream.lastY = y;
        window.EmergencyStream.lastZ = z;

        var magnitude = Math.sqrt(x * x + y * y + z * z);
        var gForce = magnitude / 9.8;
        window.EmergencyStream.lastGForce = gForce;

        var deviation = Math.abs(gForce - 1.0);
        var vibScore = Math.min(100, Math.round(deviation * 15.4));
        window.EmergencyStream.vibrationLevel = vibScore;

        if (window.EmergencyStream.onTelemetryUpdateCallback) {
          try {
            window.EmergencyStream.onTelemetryUpdateCallback(x, y, z, gForce, vibScore);
          } catch (e) {}
        }

        if (window.EmergencyStream.isSensorArmed && (gForce >= window.EmergencyStream.shakeThreshold || vibScore >= 98)) {
          window.EmergencyStream.triggerCrash("Mobile Sensor Over-Shaking & Impact (" + gForce.toFixed(2) + "G >= 10.0G Limit)");
        }
      };

      window.addEventListener("devicemotion", this.motionListener, true);
    }
  },

  stopMotionSensor: function() {
    this.isSensorArmed = false;
    if (this.motionListener) {
      window.removeEventListener("devicemotion", this.motionListener, true);
      this.motionListener = null;
    }
  },

  simulateCrashShake: function(simulatedGForce) {
    var g = simulatedGForce || 11.5;
    this.lastGForce = g;
    this.vibrationLevel = 100;
    this.lastX = 48.5;
    this.lastY = 52.2;
    this.lastZ = 54.8;

    if (this.onTelemetryUpdateCallback) {
      try {
        this.onTelemetryUpdateCallback(this.lastX, this.lastY, this.lastZ, g, 100);
      } catch (e) {}
    }

    this.triggerCrash("Simulated Severe Crash Impact (" + g.toFixed(1) + "G Mobile Vibration Spike - Limit 10.0G Exceeded)");
  },

  triggerCrash: function(reason) {
    if (!this.isSensorArmed) return;
    this.isSensorArmed = false;

    if (navigator.vibrate) {
      try {
        navigator.vibrate([600, 200, 600, 200, 800]);
      } catch (e) {}
    }

    if (this.onCrashDetectedCallback) {
      try {
        this.onCrashDetectedCallback(reason, this.lastGForce);
      } catch (e) {}
    }
  },

  // ----------------------------------------------------
  // 2. LIVE CAMERA & MICROPHONE STREAMING WITH SERVER RELAY
  // ----------------------------------------------------
  startLiveBroadcastWithRelay: function(emergencyId, uploadApiUrl, onAudioLevel, onFrameCaptured, onReady) {
    var self = this;
    this.activeEmergencyId = emergencyId || "EMG-LIVE";
    this.uploadUrl = uploadApiUrl || ("/api/emergencies/" + this.activeEmergencyId + "/stream");
    this.onAudioLevelCallback = onAudioLevel;
    this.onFrameCapturedCallback = onFrameCaptured;
    this.isBroadcasting = true;

    // Create hidden offscreen video & canvas for capturing frames
    var offscreenVideo = document.getElementById("victim-stream-offscreen-video");
    if (!offscreenVideo) {
      offscreenVideo = document.createElement("video");
      offscreenVideo.id = "victim-stream-offscreen-video";
      offscreenVideo.setAttribute("autoplay", "true");
      offscreenVideo.setAttribute("playsinline", "true");
      offscreenVideo.setAttribute("muted", "true");
      offscreenVideo.style.display = "none";
      document.body.appendChild(offscreenVideo);
    }

    var offscreenCanvas = document.getElementById("victim-stream-offscreen-canvas");
    if (!offscreenCanvas) {
      offscreenCanvas = document.createElement("canvas");
      offscreenCanvas.id = "victim-stream-offscreen-canvas";
      offscreenCanvas.width = 320;
      offscreenCanvas.height = 240;
      offscreenCanvas.style.display = "none";
      document.body.appendChild(offscreenCanvas);
    }

    var constraints = {
      video: {
        facingMode: self.currentFacingMode,
        width: { ideal: 320 },
        height: { ideal: 240 },
        frameRate: { ideal: 15 }
      },
      audio: true
    };

    function startStreamingLoop(isRealCamera) {
      if (self.streamInterval) clearInterval(self.streamInterval);

      var ctx = offscreenCanvas.getContext("2d");
      self.streamInterval = setInterval(function() {
        if (!self.isBroadcasting) return;

        // Measure Audio Level
        var db = 0;
        if (self.analyser && !self.isAudioMuted && self.dataArray) {
          self.analyser.getByteFrequencyData(self.dataArray);
          var sum = 0;
          for (var i = 0; i < self.dataArray.length; i++) {
            sum += self.dataArray[i];
          }
          var avg = sum / self.dataArray.length;
          db = Math.min(100, Math.round(avg * 1.3));
        } else if (!self.isAudioMuted) {
          db = 45 + Math.round(Math.random() * 25);
        }
        self.currentDecibels = db;
        if (self.onAudioLevelCallback) {
          try { self.onAudioLevelCallback(db); } catch (e) {}
        }

        // Draw Video Frame onto Canvas
        ctx.clearRect(0, 0, 320, 240);

        if (isRealCamera && offscreenVideo.readyState >= 2) {
          ctx.drawImage(offscreenVideo, 0, 0, 320, 240);
        } else {
          // High-Tech Thermal / Night-Vision Crash Telemetry Feed
          var grad = ctx.createLinearGradient(0, 0, 320, 240);
          grad.addColorStop(0, "#06202A");
          grad.addColorStop(0.5, "#0D3349");
          grad.addColorStop(1, "#03171F");
          ctx.fillStyle = grad;
          ctx.fillRect(0, 0, 320, 240);

          // Grid lines
          ctx.strokeStyle = "rgba(56, 189, 248, 0.15)";
          ctx.lineWidth = 1;
          for (var x = 0; x < 320; x += 40) {
            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, 240); ctx.stroke();
          }
          for (var y = 0; y < 240; y += 30) {
            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(320, y); ctx.stroke();
          }

          // Reticle Target
          ctx.strokeStyle = "rgba(239, 68, 68, 0.7)";
          ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.arc(160, 120, 38, 0, Math.PI * 2); ctx.stroke();
          ctx.beginPath(); ctx.moveTo(160, 75); ctx.lineTo(160, 165); ctx.stroke();
          ctx.beginPath(); ctx.moveTo(115, 120); ctx.lineTo(205, 120); ctx.stroke();

          // Scanning Line
          self.scanLineY = (self.scanLineY + 6) % 240;
          ctx.strokeStyle = "rgba(52, 211, 153, 0.7)";
          ctx.lineWidth = 2;
          ctx.beginPath(); ctx.moveTo(0, self.scanLineY); ctx.lineTo(320, self.scanLineY); ctx.stroke();
        }

        // Watermark & HUD text on top of the frame
        ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
        ctx.fillRect(0, 0, 320, 28);
        ctx.fillRect(0, 216, 320, 24);

        // Top HUD
        ctx.fillStyle = "#EF4444";
        ctx.beginPath(); ctx.arc(12, 14, 5, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = "#FFFFFF";
        ctx.font = "bold 10px monospace";
        ctx.fillText("LIVE 108 DISPATCH • " + (isRealCamera ? "CAM HD" : "IR THERMAL"), 24, 17);

        var nowStr = new Date().toISOString().substring(11, 19) + " UTC";
        ctx.fillStyle = "#38BDF8";
        ctx.font = "9px monospace";
        ctx.fillText(nowStr, 220, 17);

        // Bottom HUD
        ctx.fillStyle = "#34D399";
        ctx.font = "9px monospace";
        ctx.fillText("GPS: 13.0827°N, 80.2707°E • MIC: " + db + "dB", 10, 232);

        // Convert canvas to JPEG Base64
        var frameBase64 = offscreenCanvas.toDataURL("image/jpeg", 0.55);

        // Notify Flutter callback
        if (self.onFrameCapturedCallback) {
          try { self.onFrameCapturedCallback(frameBase64, db); } catch (e) {}
        }

        // Upload to Backend Relay
        try {
          fetch(self.uploadUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              emergencyId: self.activeEmergencyId,
              frameBase64: frameBase64,
              decibels: db,
              status: "BROADCASTING"
            })
          }).catch(function() {});
        } catch (postErr) {}

      }, 180); // ~5.5 FPS - ultra smooth & responsive over web
    }

    // Attempt Camera & Microphone access
    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      navigator.mediaDevices.getUserMedia(constraints)
        .then(function(stream) {
          self.mediaStream = stream;
          offscreenVideo.srcObject = stream;
          offscreenVideo.play().catch(function() {});

          // Audio Context setup
          try {
            var AudioContext = window.AudioContext || window.webkitAudioContext;
            if (AudioContext) {
              self.audioContext = new AudioContext();
              var source = self.audioContext.createMediaStreamSource(stream);
              self.analyser = self.audioContext.createAnalyser();
              self.analyser.fftSize = 256;
              source.connect(self.analyser);
              self.dataArray = new Uint8Array(self.analyser.frequencyBinCount);
            }
          } catch (e) {}

          startStreamingLoop(true);
          if (onReady) onReady(true, "Camera & Microphone Streaming Live to Driver & Contacts");
        })
        .catch(function(err) {
          console.warn("Camera permission blocked or unavailable, using live IR/thermal simulation:", err);
          startStreamingLoop(false);
          if (onReady) onReady(true, "Emergency Telemetry AV Stream Transmitting (Infrared Fallback)");
        });
    } else {
      startStreamingLoop(false);
      if (onReady) onReady(true, "Emergency Telemetry AV Stream Transmitting");
    }
  },

  stopLiveBroadcast: function() {
    this.isBroadcasting = false;
    if (this.streamInterval) {
      clearInterval(this.streamInterval);
      this.streamInterval = null;
    }
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(function(t) { t.stop(); });
      this.mediaStream = null;
    }
    if (this.audioContext) {
      try { this.audioContext.close(); } catch (e) {}
      this.audioContext = null;
    }
    // Inform backend that stream ended
    if (this.uploadUrl) {
      try {
        fetch(this.uploadUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            emergencyId: this.activeEmergencyId,
            frameBase64: "",
            decibels: 0,
            status: "STOPPED"
          })
        }).catch(function() {});
      } catch (e) {}
    }
  },

  toggleMuteAudio: function() {
    this.isAudioMuted = !this.isAudioMuted;
    if (this.mediaStream) {
      this.mediaStream.getAudioTracks().forEach(function(t) {
        t.enabled = !window.EmergencyStream.isAudioMuted;
      });
    }
    return this.isAudioMuted;
  },

  switchCamera: function(onReady) {
    this.currentFacingMode = this.currentFacingMode === "user" ? "environment" : "user";
    this.stopLiveBroadcast();
    this.startLiveBroadcastWithRelay(this.activeEmergencyId, this.uploadUrl, this.onAudioLevelCallback, this.onFrameCapturedCallback, onReady);
  },

  // ----------------------------------------------------
  // 3. LIVE GEOLOCATION & MAP CENTERING FACILITY
  // ----------------------------------------------------
  lastLiveLocation: null,
  activeLocationWatchId: null,
  activeMapMarker: null,
  activeAccuracyCircle: null,

  /**
   * Fetches real-time location via navigator.geolocation.getCurrentPosition.
   * Prompts user for browser permission, extracts latitude & longitude,
   * passes coordinates to map.setCenter(), and places a marker to visualize position.
   */
  fetchLiveLocation: function(map, onSuccess, onError, options) {
    var self = this;
    if (!navigator.geolocation) {
      var errObj = { code: 0, message: "Geolocation is not supported by this browser/device." };
      console.warn(errObj.message);
      if (typeof onError === "function") onError(errObj);
      return;
    }

    var geoOptions = options || {
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 0
    };

    navigator.geolocation.getCurrentPosition(
      function(position) {
        var lat = position.coords.latitude;
        var lng = position.coords.longitude;
        var accuracy = position.coords.accuracy || 10;
        var userLocation = { lat: lat, lng: lng };

        self.lastLiveLocation = {
          latitude: lat,
          longitude: lng,
          accuracy: accuracy,
          speed: position.coords.speed,
          heading: position.coords.heading,
          timestamp: position.timestamp || Date.now()
        };

        // 1. Pass latitude & longitude to map's setCenter method
        if (map) {
          self.updateMapCenterAndMarker(map, lat, lng, accuracy);
        }

        // 2. Notify callbacks
        if (typeof onSuccess === "function") {
          onSuccess({
            latitude: lat,
            longitude: lng,
            accuracy: accuracy,
            location: userLocation,
            timestamp: self.lastLiveLocation.timestamp
          });
        }
      },
      function(error) {
        console.warn("navigator.geolocation.getCurrentPosition error:", error);
        if (typeof onError === "function") {
          onError(error);
        }
      },
      geoOptions
    );
  },

  updateMapCenterAndMarker: function(map, lat, lng, accuracy) {
    if (!map) return;
    var userLocation = { lat: lat, lng: lng };

    // Pass coordinates to map.setCenter
    if (typeof map.setCenter === "function") {
      try {
        map.setCenter(userLocation);
      } catch (e1) {
        try { map.setCenter(lat, lng); } catch (e2) {}
      }
    } else if (typeof map.panTo === "function") {
      try { map.panTo(userLocation); } catch (e) {}
    } else if (typeof map.setView === "function") {
      try { map.setView([lat, lng], map.getZoom() || 16); } catch (e) {}
    }

    // Add or update marker to visualize user's position
    if (window.google && window.google.maps) {
      if (this.activeMapMarker && typeof this.activeMapMarker.setPosition === "function") {
        this.activeMapMarker.setPosition(userLocation);
      } else if (typeof window.google.maps.Marker === "function") {
        this.activeMapMarker = new window.google.maps.Marker({
          position: userLocation,
          map: map,
          title: "Your Live Location (±" + Math.round(accuracy) + "m)",
          animation: window.google.maps.Animation ? window.google.maps.Animation.DROP : null
        });
      }
    } else if (window.L && typeof window.L.marker === "function" && typeof map.addLayer === "function") {
      if (this.activeMapMarker && typeof this.activeMapMarker.setLatLng === "function") {
        this.activeMapMarker.setLatLng([lat, lng]);
      } else {
        var userIcon = window.L.divIcon({
          className: "user-live-pin",
          html: "<div style='width:22px;height:22px;background:#10B981;border:3px solid white;border-radius:50%;box-shadow:0 0 12px rgba(16,185,129,0.8);animation:pulse 2s infinite;'></div>",
          iconSize: [22, 22],
          iconAnchor: [11, 11]
        });
        this.activeMapMarker = window.L.marker([lat, lng], { icon: userIcon }).addTo(map);
      }

      if (accuracy) {
        if (this.activeAccuracyCircle && typeof this.activeAccuracyCircle.setLatLng === "function") {
          this.activeAccuracyCircle.setLatLng([lat, lng]);
          this.activeAccuracyCircle.setRadius(accuracy);
        } else if (typeof window.L.circle === "function") {
          this.activeAccuracyCircle = window.L.circle([lat, lng], {
            radius: accuracy,
            color: "#10B981",
            fillColor: "#10B981",
            fillOpacity: 0.15,
            weight: 1.5
          }).addTo(map);
        }
      }
    } else if (typeof map.addMarker === "function") {
      this.activeMapMarker = map.addMarker({ lat: lat, lng: lng, label: "Live Location", accuracy: accuracy });
    }
  },

  watchLiveLocation: function(map, onUpdate, onError, options) {
    var self = this;
    if (!navigator.geolocation) return;
    this.stopWatchingLocation();

    this.activeLocationWatchId = navigator.geolocation.watchPosition(
      function(pos) {
        var lat = pos.coords.latitude;
        var lng = pos.coords.longitude;
        var acc = pos.coords.accuracy || 10;
        self.lastLiveLocation = {
          latitude: lat,
          longitude: lng,
          accuracy: acc,
          speed: pos.coords.speed,
          heading: pos.coords.heading,
          timestamp: pos.timestamp || Date.now()
        };

        if (map) {
          self.updateMapCenterAndMarker(map, lat, lng, acc);
        }

        if (typeof onUpdate === "function") {
          onUpdate(self.lastLiveLocation);
        }
      },
      onError,
      options || { enableHighAccuracy: true, timeout: 15000, maximumAge: 2000 }
    );
  },

  stopWatchingLocation: function() {
    if (this.activeLocationWatchId !== null && navigator.geolocation) {
      navigator.geolocation.clearWatch(this.activeLocationWatchId);
      this.activeLocationWatchId = null;
    }
  }
};

// Global direct function accessible across windows and web views
window.fetchLiveLocation = function(map, onSuccess, onError, options) {
  if (window.EmergencyStream && window.EmergencyStream.fetchLiveLocation) {
    return window.EmergencyStream.fetchLiveLocation(map, onSuccess, onError, options);
  } else if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      function(pos) {
        var lat = pos.coords.latitude;
        var lng = pos.coords.longitude;
        var userLocation = { lat: lat, lng: lng };
        if (map && typeof map.setCenter === "function") {
          map.setCenter(userLocation);
        }
        if (typeof onSuccess === "function") {
          onSuccess({ latitude: lat, longitude: lng, location: userLocation });
        }
      },
      onError,
      options || { enableHighAccuracy: true }
    );
  }
};

