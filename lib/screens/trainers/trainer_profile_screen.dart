
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';
import '../../services/fitstreet_api.dart';

class TrainerProfileScreen extends StatefulWidget {
  final Map<String, String> trainer;
  const TrainerProfileScreen({super.key, required this.trainer});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  bool _loadingSlots = true;
  String? _error;
  final Map<String, List<String>> _slotsByDay = {
    'Mon': [], 'Tue': [], 'Wed': [], 'Thu': [], 'Fri': [], 'Sat': [], 'Sun': []
  };
  String _selectedDay = 'Thu';
  String _sessionTab = 'single'; // 'single' or 'monthly'

  final List<String> _days = const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() { _loadingSlots = true; _error = null; });
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      // id may be under '_id' or 'id'
      final trainerId = (widget.trainer['_id'] ?? widget.trainer['id'] ?? '').toString();
      if (trainerId.isEmpty) { setState(() { _loadingSlots = false; }); return; }
      final resp = await api.getTrainerSlots(trainerId);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final raw = (body is Map && body['slots'] is List) ? body['slots'] : (body is List ? body : []);
        // reset
        _slotsByDay.updateAll((key, value) => []);
        for (final e in (raw as List)) {
          try {
            String day = (e['day'] ?? e['dayOfWeek'] ?? '').toString();
            // Normalize full day names to short keys
            if (day.length > 3) {
              final lower = day.toLowerCase();
              if (lower.startsWith('mon')) day = 'Mon';
              else if (lower.startsWith('tue')) day = 'Tue';
              else if (lower.startsWith('wed')) day = 'Wed';
              else if (lower.startsWith('thu')) day = 'Thu';
              else if (lower.startsWith('fri')) day = 'Fri';
              else if (lower.startsWith('sat')) day = 'Sat';
              else if (lower.startsWith('sun')) day = 'Sun';
            }
            final list = (e['slots'] ?? e['slotList'] ?? []) as List;
            if (_slotsByDay.containsKey(day)) {
              _slotsByDay[day] = list.map((x) => x.toString()).toList();
            }
          } catch (_) {}
        }
        // pick a day with most slots
        String best = _days.first;
        int maxCount = -1;
        for (final d in _days) {
          final c = _slotsByDay[d]?.length ?? 0;
          if (c > maxCount) { best = d; maxCount = c; }
        }
        _selectedDay = best;
      } else {
        _error = 'Slots ${resp.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loadingSlots = false; });
    }
  }

  Widget _badge(String text, {Color? bg}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: (bg ?? Colors.white24), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
  );

  String _modeDisplay(String m) {
    final s = m.toLowerCase();
    if (s == 'both') return 'Online & Offline Session';
    if (s == 'online' || s == 'offline') {
      return '${s[0].toUpperCase()}${s.substring(1)} Session';
    }
    return '';
  }

  String _expDisplay(String v) {
    switch (v) {
      case '0-6': return '0-6 months';
      case '6m-1y': return '6 months - 1 year';
      case '1-3': return '1-3 years';
      case '3-5': return '3-5 years';
      case '5+': return '5+ years';
      default: return v.isEmpty ? '—' : v;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final stackColumns = w < 920; // stack on small screens

    final name = (widget.trainer['fullName'] ?? widget.trainer['name'] ?? 'Trainer');
    final code = (widget.trainer['trainerUniqueId'] ?? '').toString();
    final mode = _modeDisplay(widget.trainer['mode'] ?? '');
    final city = (widget.trainer['city'] ?? '').toString();
    final state = (widget.trainer['state'] ?? '').toString();
    final address = (widget.trainer['address'] ?? '').toString();
    final pincode = (widget.trainer['pincode'] ?? '').toString();
    final exp = _expDisplay((widget.trainer['experience'] ?? '').toString());
    final price1 = (widget.trainer['oneSessionPrice'] ?? '').toString();
    final priceM = (widget.trainer['monthlySessionPrice'] ?? '').toString();
    final gender = (widget.trainer['gender'] ?? '').toString();
    final langs = (widget.trainer['languages'] ?? '').toString();
    final specs = (widget.trainer['specialization'] ?? '').toString();
    final img = (widget.trainer['trainerImageURL'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(code.isNotEmpty ? '$name ($code)' : name),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: stackColumns
              ? SingleChildScrollView(
            child: Column(
              children: [
                _leftCard(name, code, mode, img, city, state, exp, price1, priceM, gender, address, pincode, specs, langs),
                const SizedBox(height: 12),
                _rightSlotsCard(price1),
              ],
            ),
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: _leftCard(name, code, mode, img, city, state, exp, price1, priceM, gender, address, pincode, specs, langs)),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: _rightSlotsCard(price1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leftCard(
      String name,
      String code,
      String mode,
      String img,
      String city,
      String state,
      String exp,
      String price1,
      String priceM,
      String gender,
      String address,
      String pincode,
      String specs,
      String langs,
      ) {
    final specTags = specs.isNotEmpty ? specs.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList() : <String>[];
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: Colors.white10,
                    child: img.isNotEmpty
                        ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.cover))
                        : Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              code.isNotEmpty ? '$name ($code)' : name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                            ),
                          ),
                          if (mode.isNotEmpty)
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: _badge(mode, bg: Colors.blueAccent.withOpacity(0.4)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.place, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text([city, state].where((e)=>e.trim().isNotEmpty).join(', '), style: const TextStyle(color: Colors.white70)))
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.access_time, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(exp == '—' ? 'Experience overall: —' : '$exp experience overall', style: const TextStyle(color: Colors.white70))
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.currency_rupee, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text('${price1.isNotEmpty ? '₹ $price1/ session' : ''}${price1.isNotEmpty && priceM.isNotEmpty ? '  &  ' : ''}${priceM.isNotEmpty ? '₹ $priceM monthly session' : ''}', style: const TextStyle(color: Colors.white)))
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.person, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(gender.isEmpty ? '—' : gender, style: const TextStyle(color: Colors.white70))
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Address
            if (address.isNotEmpty || pincode.isNotEmpty) ...[
              const Text('Address:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${[ city, state].where((e)=>e.trim().isNotEmpty).join(', ')}${pincode.isNotEmpty ? ' - $pincode' : ''}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
            ],
            // Specializations
            if (specTags.isNotEmpty) ...[
              const Text('Specializations:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: specTags.map((s)=>_badge(s, bg: Colors.tealAccent.withOpacity(0.25))).toList(),
              ),
              const SizedBox(height: 12),
            ],
            // Known Language
            if (langs.isNotEmpty) ...[
              const Text('Known Language:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(langs, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
            ],
            // Prices
            if (price1.isNotEmpty) ...[
              const Text('Session Price:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('₹ $price1', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
            ],
            if (priceM.isNotEmpty) ...[
              const Text('Monthly Price:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('₹ $priceM', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
            ],
            if (mode.isNotEmpty) ...[
              const Text('Availability:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(mode, style: const TextStyle(color: Colors.white70)),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking flow coming soon')));
                },
                child: const Text('Book Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rightSlotsCard(String price1) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // tabs single/monthly
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Single Session'),
                  selected: _sessionTab == 'single',
                  onSelected: (_) => setState(() => _sessionTab = 'single'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Monthly Session'),
                  selected: _sessionTab == 'monthly',
                  onSelected: (_) => setState(() => _sessionTab = 'monthly'),
                ),
                const Spacer(),
                if (price1.isNotEmpty)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text('₹ $price1 / session', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Pick a time slot', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            // days row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _days.map((d) {
                  final count = _slotsByDay[d]?.length ?? 0;
                  final sel = _selectedDay == d;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: sel ? Colors.lightBlueAccent.withOpacity(0.6) : Colors.white.withOpacity(0.12),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () => setState(() => _selectedDay = d),
                            child: Text('$count Slots Available', style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // slots list (fixed height to avoid unbounded height in scroll)
            SizedBox(
              height: 260,
              child: _loadingSlots
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
                  : (_slotsByDay[_selectedDay]?.isEmpty ?? true)
                  ? const Center(child: Text('No slots', style: TextStyle(color: Colors.white70)))
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Slots (${_slotsByDay[_selectedDay]!.length} slots)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _slotsByDay[_selectedDay]!
                        .map((s) => _badge(s))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}