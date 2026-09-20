import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FirstAidGuideScreen extends StatefulWidget {
  const FirstAidGuideScreen({super.key});

  @override
  State<FirstAidGuideScreen> createState() => _FirstAidGuideScreenState();
}

class _FirstAidGuideScreenState extends State<FirstAidGuideScreen> {
  bool _isCprMetronomeActive = false;
  Timer? _cprTimer;
  bool _cprBeat = false;

  @override
  void dispose() {
    _cprTimer?.cancel();
    super.dispose();
  }

  void _toggleCprMetronome() {
    setState(() {
      _isCprMetronomeActive = !_isCprMetronomeActive;
    });

    if (_isCprMetronomeActive) {
      // 110 beats per minute = ~545ms interval
      _cprTimer = Timer.periodic(const Duration(milliseconds: 545), (timer) {
        setState(() => _cprBeat = !_cprBeat);
        try {
          SystemSound.play(SystemSoundType.click);
        } catch (_) {}
      });
    } else {
      _cprTimer?.cancel();
      _cprTimer = null;
      setState(() => _cprBeat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Emergency First Aid Guides", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            Text("Life-saving actions while ambulance is en route", style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // CPR Metronome Interactive Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedScale(
                        scale: _cprBeat ? 1.3 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("CPR Metronome (110 BPM)", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          Text("Pace your chest compressions accurately", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  "Push hard & fast in center of chest (5-6 cm deep). Let chest fully recoil between beats.",
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _toggleCprMetronome,
                    icon: Icon(_isCprMetronomeActive ? Icons.stop : Icons.play_arrow, color: Colors.red[800]),
                    label: Text(
                      _isCprMetronomeActive ? "STOP CPR METRONOME" : "START CPR METRONOME BEAT",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[900]),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _buildGuideCard(
            title: "Choking (Adult & Child > 1 yr)",
            badge: "Heimlich Maneuver",
            color: const Color(0xFFF59E0B),
            icon: Icons.personal_injury,
            steps: [
              "Stand behind the person and wrap arms around their waist.",
              "Make a fist with one hand and place the thumb side just above their navel.",
              "Grasp your fist with your other hand.",
              "Perform 5 quick, upward abdominal thrusts.",
              "Repeat until the blockage is dislodged or person becomes unconscious (if unconscious, begin CPR).",
            ],
          ),

          _buildGuideCard(
            title: "Stroke Recognition (F.A.S.T.)",
            badge: "Brain Emergency",
            color: const Color(0xFF8B5CF6),
            icon: Icons.psychology,
            steps: [
              "F - Face Drooping: Ask the person to smile. Does one side of the face droop?",
              "A - Arm Weakness: Ask the person to raise both arms. Does one arm drift downward?",
              "S - Speech Difficulty: Ask them to repeat a simple phrase. Is speech slurred or strange?",
              "T - Time: If you observe any of these signs, emergency ambulance is critical. Note the exact time symptoms started.",
            ],
          ),

          _buildGuideCard(
            title: "Severe Bleeding & Trauma",
            badge: "Hemorrhage Control",
            color: const Color(0xFFEF4444),
            icon: Icons.bloodtype,
            steps: [
              "Apply firm, continuous direct pressure with a clean cloth or sterile gauze.",
              "Do NOT remove blood-soaked cloths; place new cloths directly on top.",
              "If bleeding is from an arm or leg and won't stop, apply a commercial tourniquet 2-3 inches above the wound.",
              "Keep the patient lying down and covered to prevent hypothermia.",
            ],
          ),

          _buildGuideCard(
            title: "Burns & Scalds",
            badge: "Thermal Trauma",
            color: const Color(0xFFF97316),
            icon: Icons.local_fire_department,
            steps: [
              "Immediately cool the burn under gentle, cold running water for 20 minutes.",
              "Do NOT apply ice, iced water, butter, toothpaste, or oil.",
              "Carefully remove constricting jewelry/clothing before swelling begins.",
              "Loosely cover the burn with clean, non-stick plastic wrap or a sterile cloth.",
            ],
          ),

          _buildGuideCard(
            title: "Seizures & Convulsions",
            badge: "Neurological Protocol",
            color: const Color(0xFF0C831F),
            icon: Icons.health_and_safety,
            steps: [
              "Gently guide the person to the floor and clear hard or sharp objects away.",
              "Cushion their head with something soft (folded jacket or pillow).",
              "Do NOT hold the person down or try to stop their movements.",
              "Do NOT place anything inside their mouth.",
              "Once shaking stops, gently roll them onto their side (recovery position) to keep airway clear.",
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required String title,
    required String badge,
    required Color color,
    required IconData icon,
    required List<String> steps,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  ...steps.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                            child: Text("${entry.key + 1}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(entry.value, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF374151))),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
