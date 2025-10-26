// lib/screens/trainers/trainer_profile_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/glass_card.dart';
import '../../services/fitstreet_api.dart';
import '../booking/book_session_screen.dart';
import 'package:provider/provider.dart';
import '../../state/auth_manager.dart';
import '../login/login_screen_styled.dart';
import '../user/profile_completion_wizard.dart';
import '../../utils/role_storage.dart' show getProfileComplete;

class TrainerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> trainer;
  const TrainerProfileScreen({super.key, required this.trainer});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  bool _loadingSlots = true;
  String? _error;

  final Map<String, List<Map<String, dynamic>>> _slotsByDay = {
    'Mon': [], 'Tue': [], 'Wed': [], 'Thu': [], 'Fri': [], 'Sat': [], 'Sun': []
  };

  String selectedSessionType = 'single'; // 'single' or 'monthly'
  String selectedMode = ''; // 'online'|'offline' or ''
  String selectedDayValue = ''; // ISO yyyy-MM-dd
  String selectedDayName = ''; // 'Mon','Tue',...
  String selectedSlotId = ''; // id of selected slot

  late String minMonthlyStartDate;
  late String maxMonthlyStartDate;
  late String selectedMonthlyStartDate;

  Timer? _ticker;
  // Cache for fetched specializations (by trainer id)
  final Map<String, List<String>> _specCache = {};

  @override
  void initState() {
    super.initState();

    final trainerMode = (widget.trainer['mode'] ?? '').toString().toLowerCase();
    if (trainerMode == 'both') selectedMode = 'online';
    else if (trainerMode == 'online' || trainerMode == 'offline') selectedMode = trainerMode;

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final max = tomorrow.add(const Duration(days: 14));
    final fmt = DateFormat('yyyy-MM-dd');
    minMonthlyStartDate = fmt.format(tomorrow);
    maxMonthlyStartDate = fmt.format(max);
    selectedMonthlyStartDate = minMonthlyStartDate;

    selectedDayValue = DateFormat('yyyy-MM-dd').format(now);
    selectedDayName = DateFormat('EEE').format(now);

    _loadSlots();

    // small ticker to update countdown displays
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _error = null;
    });
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final trainerId = (widget.trainer['_id'] ?? widget.trainer['id'] ?? '').toString();
      if (trainerId.isEmpty) {
        setState(() {
          _error = 'Trainer id missing';
          _loadingSlots = false;
        });
        return;
      }
      final resp = await api.getTrainerSlots(trainerId);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final raw = (body is Map && body['slots'] is List) ? body['slots'] : (body is List ? body : []);
        _slotsByDay.updateAll((k, v) => []);
        for (final e in (raw as List)) {
          try {
            String day = (e['day'] ?? e['dayOfWeek'] ?? '').toString();
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
            final list = (e['slots'] ?? e['slotList'] ?? []) as dynamic;
            final rawList = (list is List) ? list : [list];
            if (_slotsByDay.containsKey(day)) {
              _slotsByDay[day] = rawList.map((rs) => _normalizeSlot(rs, day)).toList();
            }
          } catch (_) {}
        }
        // set selectedDayName if no slots present for current default
        if ((_slotsByDay[selectedDayName] ?? []).isEmpty) {
          // pick first day that has slots
          for (final d in ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']) {
            if ((_slotsByDay[d] ?? []).isNotEmpty) {
              selectedDayName = d;
              // compute selectedDayValue as next date matching that weekday
              final target = _nextDateForWeekday(_weekdayIndex(d));
              selectedDayValue = DateFormat('yyyy-MM-dd').format(target);
              break;
            }
          }
        }
      } else {
        setState(() {
          _error = 'Slots ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() {
        _loadingSlots = false;
      });
    }
  }

  Map<String, dynamic> _normalizeSlot(dynamic raw, String dayKey) {
    try {
      if (raw is Map) {
        final id = (raw['id'] ?? raw['_id'] ?? raw['label'] ?? raw.toString()).toString();
        final label = (raw['label'] ?? raw['time'] ?? raw['range'] ?? id).toString();
        DateTime? start;
        DateTime? end;
        if (raw['start'] != null) start = DateTime.tryParse(raw['start'].toString());
        if (raw['end'] != null) end = DateTime.tryParse(raw['end'].toString());
        if ((start == null || end == null) && (raw['range'] is String)) {
          final parsed = _parseRangeString(raw['range'].toString(), dayKey);
          start = parsed['start'];
          end = parsed['end'];
        }
        if ((start == null || end == null) && label.contains('-')) {
          final parsed = _parseRangeString(label, dayKey);
          start = parsed['start'] ?? start;
          end = parsed['end'] ?? end;
        }
        return {'id': id, 'label': label, 'start': start, 'end': end};
      } else {
        final label = raw.toString();
        final parsed = _parseRangeString(label, dayKey);
        return {'id': label, 'label': label, 'start': parsed['start'], 'end': parsed['end']};
      }
    } catch (_) {
      return {'id': raw.toString(), 'label': raw.toString(), 'start': null, 'end': null};
    }
  }

  Map<String, DateTime?> _parseRangeString(String s, String dayKey) {
    try {
      final parts = s.split(RegExp(r'[-–—]'));
      if (parts.length < 2) return {'start': null, 'end': null};
      final left = parts[0].trim();
      final right = parts[1].trim();
      final start = _parseTimeWithDay(left, dayKey);
      var end = _parseTimeWithDay(right, dayKey);
      if (start != null && end != null && end.isBefore(start)) end = end.add(const Duration(days: 1));
      return {'start': start, 'end': end};
    } catch (_) {
      return {'start': null, 'end': null};
    }
  }

  int _weekdayIndex(String shortDay) {
    switch (shortDay) {
      case 'Mon': return DateTime.monday;
      case 'Tue': return DateTime.tuesday;
      case 'Wed': return DateTime.wednesday;
      case 'Thu': return DateTime.thursday;
      case 'Fri': return DateTime.friday;
      case 'Sat': return DateTime.saturday;
      case 'Sun': return DateTime.sunday;
      default: return DateTime.monday;
    }
  }

  DateTime _nextDateForWeekday(int weekday) {
    final now = DateTime.now();
    int daysToAdd = (weekday - now.weekday) % 7;
    if (daysToAdd < 0) daysToAdd += 7;
    return DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
  }

  DateTime? _parseTimeWithDay(String timeStr, String dayKey) {
    final iso = DateTime.tryParse(timeStr);
    if (iso != null) return iso;
    final t = timeStr.replaceAll('.', '').toUpperCase();
    final ampm = t.contains('AM') || t.contains('PM');
    final digits = t.replaceAll(RegExp(r'[^0-9:]'), '');
    int hour = 0;
    int minute = 0;
    if (digits.contains(':')) {
      final p = digits.split(':');
      hour = int.tryParse(p[0]) ?? 0;
      minute = int.tryParse(p[1]) ?? 0;
    } else {
      hour = int.tryParse(digits) ?? 0;
    }
    if (ampm) {
      if (t.contains('PM') && hour < 12) hour += 12;
      if (t.contains('AM') && hour == 12) hour = 0;
    }
    final targetWeekday = _weekdayIndex(dayKey);
    final base = _nextDateForWeekday(targetWeekday);
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  bool isSlotExpired(Map<String, dynamic> slotObj, String dayValueIso) {
    final end = slotObj['end'] as DateTime?;
    if (end != null) return DateTime.now().isAfter(end);
    final todayISO = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dayValueIso != todayISO) return false;
    final label = (slotObj['label'] ?? slotObj['id'] ?? '').toString();
    final parts = label.split(RegExp(r'[-–—]'));
    if (parts.length < 2) return false;
    final endStr = parts[1].trim();
    final match = RegExp(r'(\d+)(?::(\d+))?\s*(AM|PM)?', caseSensitive: false).firstMatch(endStr);
    if (match == null) return false;
    int endHour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutePart = int.tryParse(match.group(2) ?? '') ?? 0;
    final ampm = (match.group(3) ?? '').toUpperCase();
    if (ampm == 'PM' && endHour != 12) endHour += 12;
    if (ampm == 'AM' && endHour == 12) endHour = 0;
    final now = DateTime.now();
    final endDt = DateTime(now.year, now.month, now.day, endHour, minutePart);
    return now.isAfter(endDt) || now.isAtSameMomentAs(endDt);
  }

  // --- Specialization helpers (match Trainer List behavior) ---
  List<String> _parseSpecs(dynamic v) {
    if (v == null) return const [];
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return const [];
      return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && e.toLowerCase() != 'null').toList();
    }
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty && e.toLowerCase() != 'null').toList();
    }
    return const [];
  }

  List<String> _extractSpecs(Map<String, dynamic> t) {
    // Common fields at list/profile level
    final List<String> fromFields = <String>[]
      ..addAll(_parseSpecs(t['specialization']))
      ..addAll(_parseSpecs(t['speciality']))
      ..addAll(_parseSpecs(t['specializations']))
      ..addAll(_parseSpecs(t['specializationList']));
    if (fromFields.isNotEmpty) {
      final seen = <String>{};
      return fromFields.where((e) => seen.add(e.toLowerCase())).toList();
    }
    // Nested under proofs sometimes
    final proofs = t['trainerSpecializationProof'] ?? t['trainerSpecializationProofs'] ?? t['specializationProofs'];
    final list = proofs is List ? proofs : [];
    final fromProofs = list
        .map((e) => (e is Map ? (e['specialization'] ?? e['name'] ?? '').toString() : e.toString()))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    if (fromProofs.isNotEmpty) {
      final seen = <String>{};
      return fromProofs.where((e) => seen.add(e.toLowerCase())).toList();
    }
    return const [];
  }

  Future<List<String>> _fetchSpecsFor(String trainerId) async {
    if (trainerId.isEmpty) return const [];
    if (_specCache.containsKey(trainerId)) return _specCache[trainerId]!;
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final resp = await api.getSpecializationProofs(trainerId);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        List items;
        if (body is List) {
          items = body;
        } else if (body is Map) {
          items = (body['data'] ?? body['proofs'] ?? body['specializations'] ?? body['items'] ?? []) as List? ?? [];
        } else {
          items = const [];
        }
        final specs = items
            .map((e) => (e is Map ? (e['specialization'] ?? e['name'] ?? '').toString() : e.toString()))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final seen = <String>{};
        final out = specs.where((e) => seen.add(e.toLowerCase())).toList();
        _specCache[trainerId] = out;
        return out;
      }
    } catch (_) {}
    return const [];
  }

  List<Map<String, String>> getDisplayDays() {
    final now = DateTime.now();
    final fmtLabel = DateFormat('EEE, d MMM'); // e.g. Mon, 13 Oct
    final fmtShort = DateFormat('EEE');
    final out = <Map<String, String>>[];
    for (int i = 0; i < 7; i++) {
      final d = now.add(Duration(days: i));
      final label = i == 0 ? 'Today' : (i == 1 ? 'Tomorrow' : fmtLabel.format(d));
      final value = DateFormat('yyyy-MM-dd').format(d);
      final dayName = fmtShort.format(d);
      out.add({'label': label, 'value': value, 'dayName': dayName});
    }
    return out;
  }

  List<Map<String, dynamic>> getSlotsForDayName(String dayName) {
    final key = dayName;
    if (!_slotsByDay.containsKey(key)) return [];
    return _slotsByDay[key]!;
  }

  void selectDay(Map<String, String> day) {
    setState(() {
      selectedDayValue = day['value']!;
      selectedDayName = day['dayName']!;
      selectedSlotId = '';
    });
  }

  void selectSlot(Map<String, dynamic> slotObj) {
    final id = slotObj['id'].toString();
    setState(() {
      selectedSlotId = (selectedSlotId == id) ? '' : id;
    });
  }

  Future<void> _saveBookingAndNavigate(Map<String, dynamic> payload, String trainerId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('bookingInfo', jsonEncode(payload));
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => BookSessionScreen(trainerId: trainerId)));
  }

  Future<void> confirmSingleBooking() async {
    final loggedIn = context.read<AuthManager?>()?.isLoggedIn ?? false;
    if (!loggedIn) {
      _promptLoginToBook();
      return;
    }
    final profileDone = await getProfileComplete();
    if (profileDone != true) {
      _promptCompleteProfile();
      return;
    }
    if (selectedSlotId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a slot')));
      return;
    }
    final trainerId = (widget.trainer['_id'] ?? widget.trainer['id'] ?? '').toString();
    final slotObj = getSlotsForDayName(selectedDayName).firstWhere((s) => s['id'].toString() == selectedSlotId, orElse: () => {});
    if (slotObj.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected slot not found')));
      return;
    }
    if (isSlotExpired(slotObj, selectedDayValue)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected slot has expired')));
      return;
    }
    final payload = {
      'trainerId': trainerId,
      'trainerName': widget.trainer['fullName'] ?? widget.trainer['name'] ?? '',
      'sessionDate': selectedDayValue,
      'sessionTime': slotObj['label'] ?? selectedSlotId,
      'sessionPrice': widget.trainer['oneSessionPrice'] ?? '',
      'sessionType': 'single',
      'mode': selectedMode.isNotEmpty ? selectedMode : (widget.trainer['mode'] ?? '')
    };
    _saveBookingAndNavigate(payload, trainerId);
  }

  Future<void> confirmMonthlyBooking() async {
    final loggedIn = context.read<AuthManager?>()?.isLoggedIn ?? false;
    if (!loggedIn) {
      _promptLoginToBook();
      return;
    }
    final profileDone = await getProfileComplete();
    if (profileDone != true) {
      _promptCompleteProfile();
      return;
    }
    final trainerId = (widget.trainer['_id'] ?? widget.trainer['id'] ?? '').toString();
    final payload = {
      'trainerId': trainerId,
      'trainerName': widget.trainer['fullName'] ?? widget.trainer['name'] ?? '',
      'sessionDate': selectedMonthlyStartDate,
      'sessionTime': '',
      'sessionPrice': widget.trainer['monthlySessionPrice'] ?? '',
      'sessionType': 'monthly',
      'mode': selectedMode.isNotEmpty ? selectedMode : (widget.trainer['mode'] ?? '')
    };
    _saveBookingAndNavigate(payload, trainerId);
  }

  void _promptCompleteProfile() {
    showDialog(
      context: context,
      builder: (dCtx) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.3), width: 0.75),
            ),
            title: const Text('Complete your profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text('Please complete your profile before booking a trainer.', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dCtx);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileCompletionWizard()));
                },
                child: const Text('Complete Profile', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptLoginToBook() {
    showDialog(
      context: context,
      builder: (dCtx) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.3), width: 0.75),
            ),
            title: const Text('Login required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text('Please register or login to book a trainer.', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dCtx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreenStyled()));
                },
                child: const Text('Register / Login', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> pickMonthlyStartDate() async {
    final min = DateTime.parse(minMonthlyStartDate);
    final max = DateTime.parse(maxMonthlyStartDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(selectedMonthlyStartDate),
      firstDate: min,
      lastDate: max,
    );
    if (picked != null) {
      setState(() {
        selectedMonthlyStartDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  String slotCountdown(Map<String, dynamic> slotObj, String dayValueIso) {
    final end = slotObj['end'] as DateTime?;
    if (end != null) {
      final now = DateTime.now();
      if (now.isAfter(end)) return 'Expired';
      final diff = end.difference(now);
      if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m left';
      return '${diff.inSeconds}s left';
    }
    final label = (slotObj['label'] ?? slotObj['id']).toString();
    final parts = label.split(RegExp(r'[-–—]'));
    if (parts.length < 2) return '';
    final endStr = parts[1].trim();
    final match = RegExp(r'(\d+)(?::(\d+))?\s*(AM|PM)?', caseSensitive: false).firstMatch(endStr);
    if (match == null) return '';
    int hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final ampm = (match.group(3) ?? '').toUpperCase();
    if (ampm == 'PM' && hour != 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dayValueIso != todayIso) return '';
    final endDt = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, minute);
    if (DateTime.now().isAfter(endDt)) return 'Expired';
    final diff = endDt.difference(DateTime.now());
    if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m left';
    return '${diff.inSeconds}s left';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final stacked = width < 920;
    final name = (widget.trainer['fullName'] ?? widget.trainer['name'] ?? 'Trainer').toString();
    final code = (widget.trainer['trainerUniqueId'] ?? '').toString();
    final city = (widget.trainer['currentCity'] ?? widget.trainer['city'] ?? '').toString();
    final state = (widget.trainer['currentState'] ?? widget.trainer['state'] ?? '').toString();
    final exp = (widget.trainer['experience'] ?? '').toString();
    final price1 = (widget.trainer['oneSessionPrice'] ?? '').toString();
    final priceM = (widget.trainer['monthlySessionPrice'] ?? '').toString();
    final img = (widget.trainer['trainerImageURL'] ?? '').toString();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(code.isNotEmpty ? '$name ($code)' : name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 50,
        leadingWidth: 177,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 125,
                height: 77,
                child: Opacity(
                  opacity: 1,
                  child: Image.asset(
                    'assets/image/fitstreet-bull-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: Stack(
          children: [
           
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: stacked
              ? SingleChildScrollView(
            child: Column(
              children: [
                _leftCard(name, code, img, city, state, exp, price1, priceM),
                const SizedBox(height: 12),
                _rightBookingCard(price1, priceM),
              ],
            ),
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: _leftCard(name, code, img, city, state, exp, price1, priceM)),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: _rightBookingCard(price1, priceM)),
            ],
          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftCard(String name, String code, String img, String city, String state, String exp, String price1, String priceM) {
    final mode = _modeDisplay((widget.trainer['mode'] ?? '').toString());
    final langs = (widget.trainer['languages'] ?? '').toString();
  final trainerId = (widget.trainer['_id'] ?? widget.trainer['id'] ?? '').toString();
  final initialSpecs = _extractSpecs(widget.trainer);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(code.isNotEmpty ? '$name ($code)' : name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
                  if (mode.isNotEmpty)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.4), borderRadius: BorderRadius.circular(8)),
                          child: Text(mode, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.place, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text([city, state].where((e) => e.trim().isNotEmpty).join(', '), style: const TextStyle(color: Colors.white70)))
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.access_time, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(exp.isEmpty ? 'Experience not specified' : 'Experience: $exp', style: const TextStyle(color: Colors.white70))
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.currency_rupee, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${price1.isNotEmpty ? '₹ $price1/ session' : ''}${price1.isNotEmpty && priceM.isNotEmpty ? '  &  ' : ''}${priceM.isNotEmpty ? '₹ $priceM monthly session' : ''}', style: const TextStyle(color: Colors.white)))
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          // Specializations (chips) – mirror Trainer List behavior
          Builder(builder: (_) {
            if (initialSpecs.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Specializations:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: initialSpecs.map((s) => _specChip(s)).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }
            if (trainerId.isEmpty) return const SizedBox.shrink();
            return FutureBuilder<List<String>>(
              future: _fetchSpecsFor(trainerId),
              builder: (ctx, snap) {
                final list = snap.data ?? const [];
                if (list.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Specializations:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: list.map((s) => _specChip(s)).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            );
          }),
          if (langs.isNotEmpty) ...[
            const Text('Known Language:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(langs, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
          ],
        ]),
      ),
    );
  }

  Widget _specChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5).withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _rightBookingCard(String price1, String priceM) {
    final days = getDisplayDays();
    final slotsForSelected = getSlotsForDayName(selectedDayName);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top controls row (chips + price), responsive via Wrap to prevent overflow
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 12,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Builder(builder: (_) {
                    final sel = selectedSessionType == 'single';
                    return ChoiceChip(
                      label: const Text('Single Session'),
                      selected: sel,
                      onSelected: (_) {
                        setState(() {
                          selectedSessionType = 'single';
                          selectedSlotId = '';
                        });
                      },
                      backgroundColor: Colors.white12,
                      selectedColor: Colors.white24,
                      showCheckmark: false,
                      labelStyle: const TextStyle(color: Colors.white),
                      shape: StadiumBorder(side: BorderSide(color: sel ? Colors.white : Colors.white24)),
                    );
                  }),
                  Builder(builder: (_) {
                    final sel = selectedSessionType == 'monthly';
                    return ChoiceChip(
                      label: const Text('Monthly Session'),
                      selected: sel,
                      onSelected: (_) {
                        setState(() {
                          selectedSessionType = 'monthly';
                          selectedSlotId = '';
                        });
                      },
                      backgroundColor: Colors.white12,
                      selectedColor: Colors.white24,
                      showCheckmark: false,
                      labelStyle: const TextStyle(color: Colors.white),
                      shape: StadiumBorder(side: BorderSide(color: sel ? Colors.white : Colors.white24)),
                    );
                  }),
                ],
              ),
              if (selectedSessionType == 'single' && price1.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('₹ $price1 / session', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              if (selectedSessionType == 'monthly' && priceM.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('₹ $priceM / month', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (selectedSessionType == 'single') ...[
            const SizedBox(height: 12),
            const Text('Pick a time slot', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
          ],

          if ((widget.trainer['mode'] ?? '').toString().toLowerCase() == 'both') ...[
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text('Choose Session Mode:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                Container(
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(4),
                  child: Row(children: [_modeButton('online'), const SizedBox(width: 8), _modeButton('offline')]),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          if (selectedSessionType == 'single')
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: days.map((d) {
                  final isSelected = selectedDayValue == d['value'];
                  final count = getSlotsForDayName(d['dayName']!).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['label']!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => selectDay(d),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: isSelected ? const LinearGradient(colors: [Color(0xFF6A82FB), Color(0xFF56CCF2)]) : null,
                            color: isSelected ? null : Colors.white24.withOpacity(0.08),
                            border: Border.all(color: isSelected ? Colors.white : Colors.white.withOpacity(0.35)),
                          ),
                          child: Center(child: Text('$count Slots Available', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 12),

          if (selectedSessionType == 'monthly') ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Select Start Date', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              if (priceM.isNotEmpty) Text('₹ $priceM / month', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              ElevatedButton(
                onPressed: pickMonthlyStartDate,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                child: Text(selectedMonthlyStartDate, style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Text('to ${_computeMonthlyEndDate(selectedMonthlyStartDate)}', style: const TextStyle(color: Colors.white70)),
            ]),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => confirmMonthlyBooking(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: const StadiumBorder(),
                side: const BorderSide(color: Colors.white24),
              ),
              child: const Text('Confirm Monthly Booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
          ],

          if (selectedSessionType == 'single') ...[
            Text('Slots (${slotsForSelected.length} slots)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: _loadingSlots
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
                  : (slotsForSelected.isEmpty
                  ? const Center(child: Text('No slots', style: TextStyle(color: Colors.white70)))
                  : SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: slotsForSelected.map((slotObj) {
                    final label = (slotObj['label'] ?? slotObj['id']).toString();
                    final id = slotObj['id'].toString();
                    final expired = isSlotExpired(slotObj, selectedDayValue);
                    final selected = selectedSlotId == id;
                    return GestureDetector(
                      onTap: expired ? null : () => selectSlot(slotObj),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: selected && !expired ? const LinearGradient(colors: [Color(0xFF6A82FB), Color(0xFF56CCF2)]) : null,
                          color: (!selected && expired) ? Colors.white12 : (selected ? null : Colors.white24.withOpacity(0.08)),
                          border: Border.all(color: selected && !expired ? Colors.white : Colors.white.withOpacity(0.55), width: selected && !expired ? 2.0 : 1.0),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(slotCountdown(slotObj, selectedDayValue), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              )),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: selectedSlotId.isNotEmpty ? () => confirmSingleBooking() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedSlotId.isNotEmpty ? Colors.white24 : Colors.white12,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: const StadiumBorder(),
                side: BorderSide(color: selectedSlotId.isNotEmpty ? Colors.white : Colors.white24),
              ),
              child: Center(
                child: Text(selectedSlotId.isNotEmpty ? 'Confirm Booking' : 'Select a slot to confirm', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _modeButton(String modeKey) {
    final active = selectedMode == modeKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMode = modeKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: active ? const LinearGradient(colors: [Color(0xFF6A82FB), Color(0xFF56CCF2)]) : null,
          color: active ? null : Colors.white12,
          border: Border.all(color: active ? Colors.transparent : Colors.white24),
        ),
        child: Text(modeKey[0].toUpperCase() + modeKey.substring(1), style: TextStyle(color: active ? Colors.white : Colors.white70, fontWeight: FontWeight.w700)),
      ),
    );
  }

  String _modeDisplay(String m) {
    final s = m.toLowerCase();
    if (s == 'both') return 'Online & Offline Session';
    if (s == 'online' || s == 'offline') return '${s[0].toUpperCase()}${s.substring(1)} Session';
    return '';
  }

  String _computeMonthlyEndDate(String startIso) {
    try {
      final start = DateTime.parse(startIso);
      final end = DateTime(start.year, start.month + 1, start.day).subtract(const Duration(days: 1));
      return DateFormat('yyyy-MM-dd').format(end);
    } catch (_) {
      return '';
    }
  }
}
