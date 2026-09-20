import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/live_av_stream_service.dart';

class LiveVideoViewfinder extends StatefulWidget {
  final bool isBroadcasting;
  final int decibelLevel;
  final String locationText;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onToggleMute;

  const LiveVideoViewfinder({
    super.key,
    required this.isBroadcasting,
    this.decibelLevel = 0,
    this.locationText = "Anna Salai, Chennai (13.0827, 80.2707)",
    this.onSwitchCamera,
    this.onToggleMute,
  });

  @override
  State<LiveVideoViewfinder> createState() => _LiveVideoViewfinderState();
}

class _LiveVideoViewfinderState extends State<LiveVideoViewfinder> with SingleTickerProviderStateMixin {
  final LiveAvStreamService _streamService = LiveAvStreamService();
  late AnimationController _pulseController;
  StreamSubscription<String>? _frameSub;
  Uint8List? _localFrameBytes;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Subscribe to captured local frames
    _frameSub = _streamService.frameStream.listen((base64Str) {
      if (!mounted) return;
      try {
        var clean = base64Str;
        if (clean.contains(',')) {
          clean = clean.split(',').last;
        }
        final bytes = base64Decode(clean);
        setState(() {
          _localFrameBytes = bytes;
        });
      } catch (_) {}
    });

    // Check if initial frame already exists
    if (_streamService.latestLocalFrameBase64.isNotEmpty) {
      try {
        var clean = _streamService.latestLocalFrameBase64;
        if (clean.contains(',')) clean = clean.split(',').last;
        _localFrameBytes = base64Decode(clean);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _frameSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = _streamService.isAudioMuted;
    final db = widget.decibelLevel;

    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Feed from captured frame buffer
          if (_localFrameBytes != null)
            Image.memory(
              _localFrameBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          else
            Container(
              color: const Color(0xFF0B132B),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withOpacity(0.2),
                          border: Border.all(color: Colors.redAccent, width: 1.5),
                        ),
                        child: const Icon(Icons.videocam, color: Colors.redAccent, size: 32),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "STARTING CAMERA & AUDIO BROADCAST...",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Relaying live stream to ambulance driver & contacts",
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // 2. High-Tech HUD Scanline Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.black.withOpacity(0.65),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Top HUD: Broadcasting Status & Camera Switcher
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withOpacity(0.6), blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _pulseController,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "BROADCASTING TO 108 FLEET",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text(
                        "LIVE RELAY • HD",
                        style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontFamily: "monospace", fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: widget.onSwitchCamera,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Bottom HUD: Real-Time Audio Decibel Waveform & Stream Telemetry
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  // Microphone Icon & Mute Toggle
                  InkWell(
                    onTap: widget.onToggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isMuted ? Colors.red.withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isMuted ? Colors.redAccent : const Color(0xFF10B981)),
                      ),
                      child: Icon(
                        isMuted ? Icons.mic_off : Icons.mic,
                        color: isMuted ? Colors.redAccent : const Color(0xFF34D399),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Real-time Audio Waveform Equalizer Bars
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              isMuted ? "MIC MUTED" : "LIVE AUDIO: $db dB",
                              style: TextStyle(
                                color: isMuted ? Colors.redAccent : const Color(0xFF34D399),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.locationText,
                              style: const TextStyle(color: Colors.white60, fontSize: 9),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Waveform Bars
                        Row(
                          children: List.generate(24, (i) {
                            final factor = isMuted ? 2.0 : (2.0 + (db * 0.15) * ((i % 5 + 1) / 5.0)).clamp(2.0, 16.0);
                            return Expanded(
                              child: Container(
                                height: factor,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: isMuted
                                      ? Colors.grey.withOpacity(0.4)
                                      : (db > 70
                                          ? Colors.redAccent
                                          : (db > 40 ? const Color(0xFF34D399) : const Color(0xFF38BDF8))),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
