import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/live_av_stream_service.dart';

class LiveStreamReceiver extends StatefulWidget {
  final String emergencyId;
  final String callerRole;
  final String locationText;

  const LiveStreamReceiver({
    super.key,
    required this.emergencyId,
    this.callerRole = "Emergency Receiver",
    this.locationText = "Anna Salai, Chennai (13.0827, 80.2707)",
  });

  @override
  State<LiveStreamReceiver> createState() => _LiveStreamReceiverState();
}

class _LiveStreamReceiverState extends State<LiveStreamReceiver> with SingleTickerProviderStateMixin {
  final LiveAvStreamService _streamService = LiveAvStreamService();
  Timer? _pollingTimer;
  Uint8List? _frameBytes;
  int _decibels = 0;
  String _streamStatus = "CONNECTING...";
  bool _isMuted = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _startFramePolling();
  }

  void _startFramePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final frame = await _streamService.fetchLatestStreamFrame(widget.emergencyId);
      if (!mounted) return;

      if (frame != null && frame.frameBase64.isNotEmpty) {
        try {
          var clean = frame.frameBase64;
          if (clean.contains(',')) {
            clean = clean.split(',').last;
          }
          final bytes = base64Decode(clean);
          setState(() {
            _frameBytes = bytes;
            _decibels = frame.decibels;
            _streamStatus = frame.status == "BROADCASTING" ? "LIVE" : frame.status;
          });
        } catch (_) {}
      } else if (frame != null && frame.status == "STOPPED") {
        setState(() {
          _streamStatus = "BROADCAST ENDED";
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = _isMuted ? 0 : _decibels;

    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _streamStatus == "LIVE" ? Colors.redAccent : const Color(0xFF0284C7),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_streamStatus == "LIVE" ? Colors.redAccent : const Color(0xFF0284C7)).withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Decoded Video Frame or Animated Connection Screen
          if (_frameBytes != null && _streamStatus != "BROADCAST ENDED")
            Image.memory(
              _frameBytes!,
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF38BDF8).withOpacity(0.15),
                          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                        ),
                        child: const Icon(Icons.videocam, color: Color(0xFF38BDF8), size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _streamStatus == "BROADCAST ENDED" ? "STREAM TERMINATED BY VICTIM" : "AWAITING VICTIM AV TRANSMISSION...",
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _streamStatus == "BROADCAST ENDED" ? "False alarm stood down" : "Synchronizing WebRTC relay via 108 Command Center",
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Scanline overlay
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

          // 3. Top HUD: Stream Status & Role Banner
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
                    color: _streamStatus == "LIVE" ? Colors.red.withOpacity(0.9) : const Color(0xFF0284C7).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6),
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
                      Text(
                        _streamStatus == "LIVE" ? "🔴 LIVE VICTIM FEED" : "SYNCHRONIZING...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    widget.callerRole,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom HUD: Audio Waveform Equalizer & Telemetry
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
                  // Mute Audio Toggle
                  InkWell(
                    onTap: () {
                      setState(() => _isMuted = !_isMuted);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_isMuted ? "Cabin Audio Monitor Muted" : "Cabin Audio Monitor Active")),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _isMuted ? Colors.red.withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _isMuted ? Colors.redAccent : const Color(0xFF10B981)),
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: _isMuted ? Colors.redAccent : const Color(0xFF34D399),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Real-time Waveform Equalizer
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isMuted ? "MONITOR MUTED" : "VICTIM MIC: $db dB",
                              style: TextStyle(
                                color: _isMuted ? Colors.redAccent : const Color(0xFF34D399),
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
                        Row(
                          children: List.generate(24, (i) {
                            final factor = _isMuted ? 2.0 : (2.0 + (db * 0.15) * ((i % 5 + 1) / 5.0)).clamp(2.0, 16.0);
                            return Expanded(
                              child: Container(
                                height: factor,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: _isMuted
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
