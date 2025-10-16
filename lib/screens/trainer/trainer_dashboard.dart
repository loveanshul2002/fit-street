// lib/screens/trainer/trainer_dashboard.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/earnings_card.dart'; // PaymentDetail included
import '../trainer/kyc/widgets/header.dart';
import '../trainer/kyc/widgets/bookings_list.dart';
import '../trainer/kyc/trainer_kyc_wizard.dart';
import '../../state/auth_manager.dart';
import '../../utils/role_storage.dart';
import '../home/home_screen.dart';
import '../../services/fitstreet_api.dart';
import '../../utils/profile_storage.dart';
import 'profile_edit_restricted_screen.dart';
import '../trainer/bank_details_edit_screen.dart';

enum KycStatus { pending, done }
enum KycState { notStarted, submitted, approved, rejected }

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({Key? key}) : super(key: key);

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _dbTrainerId;
  String? _uniqueTrainerCode;
  String _trainerCode = '';

  String trainerName = "";
  String cityCountry = "Mumbai, India";
  String addressLine = "Andheri West, Mumbai";
  String motivation = "Small daily wins add up — keep going!";

  KycStatus kycStatus = KycStatus.pending;
  bool isAvailable = true;

  // Bookings state
  String _bookingsTab = 'upcoming';
  List<dynamic> _upcomingBookings = [];
  List<dynamic> _completedBookings = [];
  List<dynamic> _rejectedBookings = [];
  bool _loadingBookings = false;

  // Selected user (passed into dialog when viewing profile)
  Map<String, dynamic>? _selectedBookingUser;

  // KYC
  KycState _kycState = KycState.notStarted;
  String? _kycStatusRaw;

  // Availability / slots
  String _selectedDay = "Mon";
  String targetAudience = "Both";
  String workingMode = "Offline";

  final List<String> slotLabels = [
    "12AM-3AM",
    "3AM-6AM",
    "6AM-9AM",
    "9AM-12PM",
    "12PM-3PM",
    "3PM-6PM",
    "6PM-9PM",
    "9PM-12PM",
  ];

  final Map<String, Set<String>> availability = {
    "Mon": <String>{},
    "Tue": <String>{},
    "Wed": <String>{},
    "Thu": <String>{},
    "Fri": <String>{},
    "Sat": <String>{},
    "Sun": <String>{},
  };

  final Set<String> selectedDays = <String>{};

  // Simple demo lists (kept for local demo)
  List<Map<String, dynamic>> live = [
    {
      "id": "b1",
      "client": "Rohan Patel",
      "time": DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      "location": "Andheri Gym",
      "amount": 800.0,
      "accepted": false,
      "contact": "9999911111",
      "status": "pending",
    }
  ];

  List<Map<String, dynamic>> completed = [
    {
      "id": "c1",
      "client": "Rita M",
      "time": DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      "location": "Home",
      "amount": 500.0,
      "status": "paid",
    }
  ];

  List<Map<String, dynamic>> upcoming = [
    {
      "id": "u1",
      "client": "Sneha K",
      "time": DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      "location": "Bandra",
      "amount": 700.0,
      "status": "pending",
    }
  ];

  late final TabController _tabs;
  static const _kycKey = 'trainer_kyc_done';
  bool _loadingSlots = false;
  double _feePercent = 10.0;

  // Notification state
  int notificationCount = 0;
  List<dynamic> notifications = [];
  bool showNotificationList = false;
  bool loadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    availability["Mon"]!.add(slotLabels.first);
    selectedDays.add("Mon");
    _initLocalState();
    _loadUserName();
    _loadTrainerInfo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getBookedSessions('upcoming');
      _loadSlotsFromServer();
      // Fetch notifications on init
      getNotifications();
    });
  }

  Future<void> _initLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool done = prefs.getBool(_kycKey) ?? false;
      if (mounted) setState(() => kycStatus = done ? KycStatus.done : KycStatus.pending);
      if (done && mounted) setState(() => _kycState = KycState.submitted);

      final aud = prefs.getString('fitstreet_trainer_audience');
      final mode = prefs.getString('fitstreet_trainer_mode');
      if (aud != null && mounted) setState(() => targetAudience = aud);
      if (mode != null && mounted) setState(() => workingMode = mode);
    } catch (_) {
      if (mounted) setState(() => kycStatus = KycStatus.pending);
    }
  }

  Future<void> _loadUserName() async {
    try {
      final name = await getUserName();
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => trainerName = name);
        return;
      }
      final mobile = await getMobile();
      final sp = await SharedPreferences.getInstance();
      final unique = sp.getString('fitstreet_trainer_unique_id');
      final fallback = (mobile != null && mobile.isNotEmpty)
          ? mobile
          : (unique != null && unique.isNotEmpty)
          ? unique
          : 'Trainer';
      if (mounted) setState(() => trainerName = fallback);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  double _calculateNet(double gross) => gross * (1 - _feePercent / 100);

  List<Map<String, dynamic>> get allBookingMaps {
    Map<String, dynamic> safeMap(Map<String, dynamic> b) {
      final amt = (b['amount'] ?? 0);
      final gross = (amt is num) ? amt.toDouble() : 0.0;
      DateTime? parsed;
      try {
        if (b['time'] != null) parsed = DateTime.tryParse(b['time']);
      } catch (_) {}
      return {
        "id": b['id'] ?? 'id_${DateTime.now().millisecondsSinceEpoch}',
        "client": b['client'] ?? 'Client',
        "netAmount": _calculateNet(gross),
        "isPaid": (b['status'] ?? '') == 'paid' || b['status'] == true,
        "raw": b,
        "date": parsed,
      };
    }

    return [
      ...live.map(safeMap),
      ...completed.map(safeMap),
      ...upcoming.map(safeMap)
    ];
  }

  double get grossTotal {
    double s = 0;
    for (var e in [...live, ...completed, ...upcoming]) {
      final amt = (e['amount'] ?? 0);
      if (amt is num) s += amt.toDouble();
    }
    return s;
  }

  double get netTotal => _calculateNet(grossTotal);

  Future<void> _setAvailability(bool val) async {
    setState(() => isAvailable = val);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(val ? "Updating availability..." : "Updating availability...")),
    );

    try {
      final sp = await SharedPreferences.getInstance();
      final savedToken = sp.getString('fitstreet_token') ?? '';
      String? trainerId;
      try {
        trainerId = await context.read<AuthManager>().getApiTrainerId();
      } catch (_) {
        trainerId = null;
      }
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');

      if (trainerId == null || trainerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trainer id not found. Please login again.")));
        if (mounted) setState(() => isAvailable = !val);
        return;
      }

      final fitApi = FitstreetApi('https://api.fitstreet.in', token: savedToken);
      final streamed = await fitApi.updateTrainerProfileMultipart(trainerId, fields: {'isAvailable': val ? 'true' : 'false'});
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? "You're visible to customers." : "Hidden from search.")));
      } else {
        if (mounted) setState(() => isAvailable = !val);
        String msg = 'Failed to update availability (${resp.statusCode})';
        try {
          final b = jsonDecode(resp.body);
          if (b is Map && (b['message'] != null || b['error'] != null)) msg = (b['message'] ?? b['error']).toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) setState(() => isAvailable = !val);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Network error: ${e.toString()}")));
    }
  }

  void _openAvailabilityEditor() {
    final slot = slotLabels.isNotEmpty ? slotLabels.first : null;
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No slots configured.")));
      return;
    }
    setState(() {
      for (var d in selectedDays) {
        if (availability[d]!.contains(slot)) availability[d]!.remove(slot);
        else availability[d]!.add(slot);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Availability updated (local). Press 'Update Slots' to save.")));
  }

  Future<void> _openKycWizard() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const TrainerKycWizard()));
    if (result == true) {
      setState(() => _kycState = KycState.submitted);
      await _saveKycStatusLocally(true);
      await _loadTrainerInfo();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("KYC submitted. Awaiting approval.")));
    }
  }

  String _formatTrainerCode(int numericId) => 'FIT-${numericId.toString().padLeft(4, '0')}';

  Future<int?> getTrainerNumericId() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.containsKey('trainer_numeric_id')) return sp.getInt('trainer_numeric_id');
    } catch (_) {}
    return null;
  }

  KycState _kycStateFromData(Map<dynamic, dynamic> data) {
    final rawStatus = (data['status'] ?? data['kycStatus'] ?? '').toString().toLowerCase();
    _kycStatusRaw = rawStatus;
    final bool isKycFlag = (data['isKyc'] == true) || (data['kycCompleted'] == true) || (data['isKycCompleted'] == true);
    if (rawStatus == 'approved' || (data['kycApproved'] == true)) return KycState.approved;
    if (rawStatus == 'submitted' || rawStatus == 'inprogress' || isKycFlag) return KycState.submitted;
    if (rawStatus == 'rejected') return KycState.rejected;
    if (rawStatus == 'pending') return KycState.notStarted;
    return KycState.notStarted;
  }

  Future<void> _loadTrainerInfo() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final dbId = sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');
      final unique = sp.getString('fitstreet_trainer_unique_id');
      final numId = await getTrainerNumericId();
      final storedName = await getUserName();

      String formatted = '';
      if (numId != null) formatted = _formatTrainerCode(numId);

      KycState resolvedState = _kycState;

      try {
        final token = sp.getString('fitstreet_token') ?? '';
        final bool localSubmitted = (sp.getBool(_kycKey) ?? false);

        if (dbId != null && dbId.isNotEmpty) {
          final api = FitstreetApi('https://api.fitstreet.in', token: token);
          final resp = await api.getTrainer(dbId);
          if (resp.statusCode == 200) {
            final parsed = jsonDecode(resp.body);
            final data = (parsed is Map) ? (parsed['data'] ?? parsed) : null;
            if (data is Map) {
              final serverState = _kycStateFromData(data as Map<dynamic, dynamic>);
              if (serverState == KycState.approved) resolvedState = KycState.approved;
              else if (serverState == KycState.submitted) resolvedState = KycState.submitted;
              else if (localSubmitted) resolvedState = KycState.submitted;
              else resolvedState = KycState.notStarted;
            }
          } else {
            if (sp.getBool(_kycKey) ?? false) resolvedState = KycState.submitted;
          }
        } else {
          if (localSubmitted) resolvedState = KycState.submitted;
          else resolvedState = KycState.notStarted;
        }
      } catch (_) {
        final bool localSubmitted = (await SharedPreferences.getInstance()).getBool(_kycKey) ?? false;
        if (localSubmitted) resolvedState = KycState.submitted;
      }

      if (!mounted) return;
      setState(() {
        _dbTrainerId = dbId;
        _uniqueTrainerCode = unique;
        _trainerCode = formatted;
        if (storedName != null && storedName.isNotEmpty) trainerName = storedName;
        _kycState = resolvedState;
      });

      if ((storedName == null || storedName.isEmpty) && dbId != null && dbId.isNotEmpty) {
        await _refreshNameFromServer(dbId);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _refreshNameFromServer(String trainerDbId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final resp = await api.getTrainer(trainerDbId);
      if (resp.statusCode == 200) {
        final parsed = jsonDecode(resp.body);
        final data = (parsed is Map) ? (parsed['data'] ?? parsed) : null;
        if (data is Map) {
          final name = (data['fullName'] ?? data['name'])?.toString();
          if (name != null && name.isNotEmpty) {
            await saveUserName(name);
            if (mounted) setState(() => trainerName = name);
          }
        }
      }
    } catch (_) {}
  }

  Future<String?> _getTrainerDbIdFromPrefs() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');
  }

  Future<String> _getTokenFromPrefs() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('fitstreet_token') ?? '';
  }

  Future<void> _getBookedSessions([String tab = 'upcoming']) async {
    setState(() {
      _loadingBookings = true;
      _bookingsTab = tab;
    });

    try {
      final trainerId = await _getTrainerDbIdFromPrefs();
      final token = await _getTokenFromPrefs();
      if (trainerId == null || trainerId.isEmpty) {
        setState(() {
          _loadingBookings = false;
        });
        return;
      }

      final uri = Uri.parse('https://api.fitstreet.in/api/session-bookings/trainer/$trainerId/$tab');
      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        dynamic body;
        try {
          body = jsonDecode(resp.body);
        } catch (_) {
          body = resp.body;
        }
        final List items = (body is Map && body['bookings'] is List)
            ? body['bookings'] as List
            : (body is Map && body['data'] is List) ? body['data'] as List
            : (body is List) ? body : [];

        setState(() {
          if (tab == 'upcoming') _upcomingBookings = items;
          if (tab == 'completed') _completedBookings = items;
          if (tab == 'rejected') _rejectedBookings = items;
        });
      } else {
        debugPrint('Failed load bookings: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  // Accept booking (PATCH)
  String? _extractBookingId(dynamic bookingOrId) {
    if (bookingOrId == null) return null;
    if (bookingOrId is String && bookingOrId.trim().isNotEmpty) return bookingOrId;
    if (bookingOrId is Map) {
      return bookingOrId['_id']?.toString()
          ?? bookingOrId['id']?.toString()
          ?? bookingOrId['bookingId']?.toString()
          ?? bookingOrId['booking_id']?.toString();
    }
    return null;
  }

  Future<void> _acceptBookingApi(dynamic bookingOrId) async {
    final bookingId = _extractBookingId(bookingOrId);
    if (bookingId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking id not found')));
      return;
    }

    final token = await _getTokenFromPrefs();
    final encodedId = Uri.encodeComponent(bookingId);
    final uri = Uri.parse('https://api.fitstreet.in/api/session-bookings/accept/$encodedId');

    try {
      final resp = await http.patch(uri, headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _markBookingAcceptedLocally(bookingId);
        // refresh in background
        _getBookedSessions('upcoming');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking accepted')));
        return;
      }

      String msg = 'Accept failed (${resp.statusCode})';
      try {
        final parsed = jsonDecode(resp.body);
        if (parsed is Map) {
          msg = (parsed['message'] ?? parsed['error'] ?? parsed).toString();
        } else if (parsed is String) {
          msg = parsed;
        }
      } catch (_) {}

      if (resp.statusCode == 404) msg = 'Booking not found (may already be modified). Please refresh.';

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Accept failed: $msg')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  void _markBookingAcceptedLocally(String bookingId) {
    bool changed = false;

    void updateList(List<dynamic> list) {
      for (var i = 0; i < list.length; i++) {
        final el = list[i];
        final id1 = el?['_id']?.toString();
        final id2 = el?['id']?.toString();
        if (bookingId == id1 || bookingId == id2) {
          list[i] = {...el, 'isAccepted': true, 'accepted': true};
          changed = true;
        }
      }
    }

    updateList(_upcomingBookings);
    updateList(_completedBookings);
    updateList(_rejectedBookings);

    for (var i = 0; i < live.length; i++) {
      if ((live[i]['id']?.toString() == bookingId) || (live[i]['_id']?.toString() == bookingId)) {
        live[i]['accepted'] = true;
        changed = true;
      }
    }
    for (var i = 0; i < upcoming.length; i++) {
      if ((upcoming[i]['id']?.toString() == bookingId) || (upcoming[i]['_id']?.toString() == bookingId)) {
        upcoming[i]['accepted'] = true;
        changed = true;
      }
    }

    if (changed && mounted) setState(() {});
  }

  Future<void> _completeBookingApi(dynamic bookingOrId) async {
    final bookingId = _extractBookingId(bookingOrId);
    if (bookingId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking id not found')));
      return;
    }
    final token = await _getTokenFromPrefs();
    final encodedId = Uri.encodeComponent(bookingId);
    final uri = Uri.parse('https://api.fitstreet.in/api/session-bookings/complete/$encodedId');

    try {
      final resp = await http.patch(uri, headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking marked complete')));
        await _getBookedSessions('upcoming');
        await _getBookedSessions('completed');
      } else {
        String message = 'Complete failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          message = (parsed['message'] ?? parsed['error'] ?? parsed).toString();
        } catch (_) {
          if (resp.body.isNotEmpty) message = resp.body;
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _saveKycStatusLocally(bool done) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kycKey, done);
    } catch (_) {}
  }

  void _openSupport() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Support"),
        content: const Text("Need help? Call support or request a callback."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _triggerSOS() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Emergency (SOS)"),
        content: const Text("This will alert support. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS triggered.")));
            },
            child: Text("Confirm", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _acceptBooking(Map<String, dynamic> b) {
    setState(() => b['accepted'] = true);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking accepted — contact visible.")));
  }

  void _completeBooking(Map<String, dynamic> b) {
    setState(() {
      live.removeWhere((e) => e['id'] == b['id']);
      completed.insert(0, {...b, 'id': 'cmp_${DateTime.now().millisecondsSinceEpoch}'});
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked complete.")));
  }

  void _showContact(Map<String, dynamic> b) {
    if (b['accepted'] == true || b['isAccepted'] == true) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(b['client'] ?? "Client"),
          content: Text("Phone: ${b['contact'] ?? "N/A"}\nLocation: ${b['location'] ?? "N/A"}"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
        ),
      );
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Accept booking to view contact.")));
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Logout", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final auth = context.read<AuthManager>();
      await auth.logout();
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitstreet_trainer_db_id');
        await prefs.remove('fitstreet_trainer_unique_id');
        await prefs.remove('fitstreet_trainer_name');
        await prefs.remove('fitstreet_trainer_mobile');
        await prefs.remove('fitstreet_token');
        await clearUserRole();
        await clearUserName();
        await clearUserEmail();
        await clearProfileComplete();
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
  }

  Future<void> _saveAudienceAndMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fitstreet_trainer_audience', targetAudience);
      await prefs.setString('fitstreet_trainer_mode', workingMode);

      final sp = await SharedPreferences.getInstance();
      final savedToken = sp.getString('fitstreet_token') ?? '';
      String? trainerId;
      try {
        trainerId = await context.read<AuthManager>().getApiTrainerId();
      } catch (_) {
        trainerId = null;
      }
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');

      if (trainerId != null && trainerId.isNotEmpty) {
        final fitApi = FitstreetApi('https://api.fitstreet.in', token: savedToken);
        final preferencesData = {
          'mode': workingMode.toLowerCase(),
          'targetAudience': targetAudience,
          'availableFor': targetAudience.toLowerCase(),
        };

        final response = await fitApi.updateTrainerPreferences(trainerId, preferencesData);
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preferences saved to database successfully!")));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Database save failed: ${response.statusCode}")));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preferences saved locally only - no trainer ID")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving preferences: $e")));
    }
  }

  Future<void> _loadSlotsFromServer() async {
    if (_loadingSlots) return;
    setState(() => _loadingSlots = true);

    try {
      final sp = await SharedPreferences.getInstance();
      final savedToken = sp.getString('fitstreet_token') ?? '';
      String? trainerId;
      try {
        trainerId = await context.read<AuthManager>().getApiTrainerId();
      } catch (_) {
        trainerId = null;
      }
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');

      if (trainerId == null || trainerId.isEmpty) {
        setState(() => _loadingSlots = false);
        return;
      }

      final fitApi = FitstreetApi('https://api.fitstreet.in', token: savedToken);
      final resp = await fitApi.getSlotAvailabilityDetails(trainerId);
      if (resp.statusCode == 200) {
        final parsed = jsonDecode(resp.body);
        final slots = (parsed is Map && parsed['slots'] is List) ? parsed['slots'] as List : parsed is List ? parsed : null;
        if (slots is List) {
          availability.forEach((k, v) => v.clear());
          for (final e in slots) {
            try {
              final day = (e['day'] ?? e['dayOfWeek'] ?? '').toString();
              final List<dynamic> sList = e['slots'] ?? e['slotList'] ?? [];
              if (day.isEmpty) continue;
              final key = day;
              if (!availability.containsKey(key)) continue;
              for (final s in sList) {
                availability[key]!.add(s.toString());
              }
            } catch (_) {}
          }
          selectedDays.clear();
          final firstWith = availability.entries.firstWhere((e) => e.value.isNotEmpty, orElse: () => MapEntry("Mon", availability["Mon"]!));
          selectedDays.add(firstWith.key);
          if (mounted) setState(() {});
        }
      } else {
        debugPrint('loadSlotsFromServer failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint("_loadSlotsFromServer error: $e");
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _saveSlotsToServer() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final savedToken = sp.getString('fitstreet_token') ?? '';
      String? trainerId;
      try {
        trainerId = await context.read<AuthManager>().getApiTrainerId();
      } catch (_) {
        trainerId = null;
      }
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');

      if (trainerId == null || trainerId.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trainer id not found. Please login again.")));
        return;
      }

      final fitApi = FitstreetApi('https://api.fitstreet.in', token: savedToken);
      final payloadSlots = availability.entries.map((e) => {"day": e.key, "slots": e.value.toList()}).toList();

      final resp1 = await fitApi.saveSlotAvailabilityDetails(trainerId, payloadSlots);
      if (resp1.statusCode == 200 || resp1.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slots updated successfully (slotAvailabilityDetails).")));
        await _loadSlotsFromServer();
        return;
      }

      final resp2 = await fitApi.updateTrainerSlots(trainerId, payloadSlots);
      if (resp2.statusCode == 200 || resp2.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slots updated successfully (trainers/slots).")));
        await _loadSlotsFromServer();
        return;
      }

      String msg = 'Failed to save slots (${resp1.statusCode})';
      try {
        final b1 = jsonDecode(resp1.body);
        if (b1 is Map && (b1['message'] != null || b1['error'] != null)) msg = (b1['message'] ?? b1['error']).toString();
      } catch (_) {}
      if (resp1.statusCode == 404 && resp2.body.isNotEmpty) {
        try {
          final b2 = jsonDecode(resp2.body);
          if (b2 is Map && (b2['message'] != null || b2['error'] != null)) msg = (b2['message'] ?? b2['error']).toString();
        } catch (_) {}
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      debugPrint('_saveSlotsToServer error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Network error: $e")));
    }
  }

  // Notification API methods
  Future<void> getNotifications() async {
    setState(() { loadingNotifications = true; });
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final userType = 'trainer';
      final userId = sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final resp = await api.getNotifications(userType, userId);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() {
          notifications = body['notifications'] ?? [];
          notificationCount = body['notificationsCount'] ?? 0;
        });
      }
    } catch (e) {
      // Optionally show error
    } finally {
      setState(() { loadingNotifications = false; });
    }
  }

  Future<void> markNotificationsAsRead() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final userType = 'trainer';
      final userId = sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      await api.markNotificationsAsRead(userId, userType);
      setState(() { notificationCount = 0; });
    } catch (e) {}
  }

  // Date helpers
  String _formatFullDate(String? iso) {
    if (iso == null) return '';
    final s = iso.toString().trim();
    if (s.isEmpty) return '';
    final dt = DateTime.tryParse(s);
    if (dt == null) {
      try {
        final ms = int.parse(s);
        final dt2 = DateTime.fromMillisecondsSinceEpoch(ms);
        return '${dt2.day} ${_monthShort(dt2.month)} ${dt2.year}';
      } catch (_) {
        return s;
      }
    }
    final local = dt.toLocal();
    return '${local.day} ${_monthShort(local.month)} ${local.year}';
  }

  String _monthShort(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (m < 1 || m > 12) return '';
    return months[m - 1];
  }

  // Confirm dialogs
  Future<void> _confirmAccept(dynamic booking) async {
    final bookingId = _extractBookingId(booking);
    final clientName = (booking is Map) ? (booking['client'] ?? booking['userName'] ?? booking['user']) : 'Client';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept booking'),
        content: Text('Accept session for ${clientName.toString()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
        ],
      ),
    );
    if (ok == true) {
      await _acceptBookingApi(bookingId ?? booking);
    }
  }

  Future<void> _confirmComplete(dynamic booking) async {
    final bookingId = _extractBookingId(booking);
    final clientName = (booking is Map) ? (booking['client'] ?? booking['userName'] ?? booking['user']) : 'Client';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark complete'),
        content: Text('Mark session as complete for ${clientName.toString()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
        ],
      ),
    );
    if (ok == true) {
      await _completeBookingApi(bookingId ?? booking);
    }
  }

  // Small helpers used by refresh (to avoid missing symbol errors)
  Future<void> _loadInitialData() async {
    // central initial load used by pull-to-refresh; keep light and safe
    try {
      await Future.wait([
        _loadTrainerInfo(),
        _loadSlotsFromServer(),
        getNotifications(),
      ]);
    } catch (_) {}
  }

  Future<void> _loadBookings() async {
    await _getBookedSessions(_bookingsTab);
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final narrow = width < 720;

    final paymentDetails = allBookingMaps.map((m) {
      return PaymentDetail(
        client: m['client'] ?? 'Client',
        netAmount: (m['netAmount'] ?? 0.0).toDouble(),
        isPaid: m['isPaid'] ?? false,
        date: m['date'],
      );
    }).toList();

    final weeklyList = paymentDetails;
    final monthlyList = paymentDetails;

    String uiIdDisplay = '';
    if (_uniqueTrainerCode != null && _uniqueTrainerCode!.isNotEmpty) uiIdDisplay = _uniqueTrainerCode!;
    else if (_trainerCode.isNotEmpty) uiIdDisplay = _trainerCode;
    else if (_dbTrainerId != null && _dbTrainerId!.isNotEmpty) uiIdDisplay = _dbTrainerId!.substring(0, 6);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Trainer Dashboard"),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: "Wallet",
            onPressed: () {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wallet tapped (demo).")));
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: "Menu",
            onPressed: _openOverflowPanel,
          ),
          // Notification bell with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                tooltip: "Notifications",
                onPressed: () {
                  setState(() {
                    showNotificationList = !showNotificationList;
                  });
                  if (notificationCount > 0 && showNotificationList) {
                    markNotificationsAsRead();
                  }
                  if (showNotificationList) {
                    getNotifications();
                  }
                },
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '$notificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      endDrawer: _buildEndDrawer(context),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        // Use a Stack so we can place the notification dropdown and FABs using Positioned.
        child: Stack(
          children: [
            SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  try {
                    await Future.wait([
                      _loadInitialData(),
                      _loadBookings(),
                      _loadSlotsFromServer(),
                      getNotifications(),
                    ]);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dashboard refreshed successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error refreshing: ${e.toString()}')),
                      );
                    }
                  }
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Header(
                        trainerName: trainerName,
                        cityCountry: cityCountry,
                        isAvailable: isAvailable,
                        onToggleAvailability: _setAvailability,
                        onOpenAvailabilityEditor: _openAvailabilityEditor,
                        onNotifications: () {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications clicked")));
                        },
                      ),
                      const SizedBox(height: 12),

                      // KYC banners
                      if (_kycState == KycState.notStarted)
                        GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_user, color: Colors.orangeAccent, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text("Complete your KYC", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 4),
                                      Text("Complete KYC to enable payouts & bookings.", style: TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _openKycWizard,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                                  child: const Text("Complete KYC", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_kycState == KycState.submitted)
                        GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text("Your KYC is submitted.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 4),
                                      Text("Once your KYC is approved, we will notify you.", style: TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text("Pending", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      EarningsCard(
                        weeklyPaymentsTableData: weeklyList,
                        monthlyPaymentsTableData: monthlyList,
                        grossTotal: grossTotal,
                        netTotal: netTotal,
                        grossWeekly: live.fold(0.0, (s, e) => s + ((e['amount'] ?? 0) is num ? (e['amount'] ?? 0).toDouble() : 0.0)),
                        netWeekly: _calculateNet(live.fold(0.0, (s, e) => s + ((e['amount'] ?? 0) is num ? (e['amount'] ?? 0).toDouble() : 0.0))),
                        weeklySubtitle: '',
                        grossMonthly: upcoming.fold(0.0, (s, e) => s + ((e['amount'] ?? 0) is num ? (e['amount'] ?? 0).toDouble() : 0.0)),
                        netMonthly: _calculateNet(upcoming.fold(0.0, (s, e) => s + ((e['amount'] ?? 0) is num ? (e['amount'] ?? 0).toDouble() : 0.0))),
                        monthlySubtitle: '',
                        platformFeePercent: _feePercent,
                      ),

                      const SizedBox(height: 20),

                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Preferences", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Text("Target Audience", style: TextStyle(color: Colors.white70)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _smallChoice("Both", targetAudience == "Both", () => setState(() => targetAudience = "Both")),
                                          _smallChoice("female", targetAudience == "female", () => setState(() => targetAudience = "female")),
                                          _smallChoice("male", targetAudience == "male", () => setState(() => targetAudience = "male")),
                                        ],
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Text("Mode", style: TextStyle(color: Colors.white70)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _smallChoice("Offline", workingMode == "Offline", () => setState(() => workingMode = "Offline")),
                                          _smallChoice("Online", workingMode == "Online", () => setState(() => workingMode = "Online")),
                                          _smallChoice("Both", workingMode == "Both", () => setState(() => workingMode = "Both")),
                                        ],
                                      ),
                                    ]),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(onPressed: _saveAudienceAndMode, child: const Text("Save preferences")),
                                )
                              ]),
                        ),
                      ),

                      const SizedBox(height: 14),
                      GlassCard(child: Padding(padding: const EdgeInsets.all(12), child: Text(motivation, style: const TextStyle(color: Colors.white)))),
                      const SizedBox(height: 14),

                      narrow ? Column(children: [
                        const SizedBox(height: 6),
                        _profileCard(width, uiIdDisplay),
                        const SizedBox(height: 10),
                        _availabilityCard()
                      ]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 2, child: _profileCard(width, uiIdDisplay)),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: _availabilityCard())
                      ]),

                      const SizedBox(height: 20),

                      // Bookings UI
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Session Bookings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Row(children: [
                                GestureDetector(
                                  onTap: () => _getBookedSessions('upcoming'),
                                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: _bookingsTab == 'upcoming' ? Colors.white12 : Colors.white10, borderRadius: BorderRadius.circular(8)), child: const Text('Upcoming', style: TextStyle(color: Colors.white))),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _getBookedSessions('completed'),
                                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: _bookingsTab == 'completed' ? Colors.white12 : Colors.white10, borderRadius: BorderRadius.circular(8)), child: const Text('Completed', style: TextStyle(color: Colors.white))),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _getBookedSessions('rejected'),
                                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: _bookingsTab == 'rejected' ? Colors.white12 : Colors.white10, borderRadius: BorderRadius.circular(8)), child: const Text('Rejected', style: TextStyle(color: Colors.white))),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              if (_loadingBookings) const Center(child: CircularProgressIndicator()) else Column(children: [
                                if (_bookingsTab == 'upcoming' && _upcomingBookings.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No upcoming sessions.', style: TextStyle(color: Colors.white70))),
                                if (_bookingsTab == 'completed' && _completedBookings.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No completed sessions.', style: TextStyle(color: Colors.white70))),
                                if (_bookingsTab == 'rejected' && _rejectedBookings.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No rejected sessions.', style: TextStyle(color: Colors.white70))),
                                if (_bookingsTab == 'upcoming') ..._upcomingBookings.map((b) => _trainerBookingTile(b)).toList(),
                                if (_bookingsTab == 'completed') ..._completedBookings.map((b) => _trainerBookingTile(b)).toList(),
                                if (_bookingsTab == 'rejected') ..._rejectedBookings.map((b) => _trainerBookingTile(b)).toList(),
                              ])
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 80),
                      Center(child: Column(children: [
                        Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.sports_martial_arts, color: Colors.white)),
                        const SizedBox(height: 10),
                        const Text("© Ball Street Pvt. Ltd.", style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 20),
                      ])),
                    ],
                  ),
                ),
              ),
            ),

            // Notification dropdown (positioned)
            if (showNotificationList)
              Positioned(
                right: 16,
                top: kToolbarHeight + 8,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: loadingNotifications
                      ? const Center(child: CircularProgressIndicator())
                      : notifications.isEmpty
                        ? const Text('No notifications', style: TextStyle(color: Colors.white70))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: notifications.map<Widget>((n) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n['message'] ?? '', style: const TextStyle(color: Colors.white)),
                                  Text(n['createdAt'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                            )).toList(),
                          ),
                  ),
                ),
              ),

            // Floating actions (positioned)
            Positioned(left: 18, bottom: 18, child: FloatingActionButton(heroTag: 'support_fab', onPressed: _openSupport, backgroundColor: AppColors.secondary, child: const Icon(Icons.headset_mic, color: Colors.white))),
            Positioned(right: 18, bottom: 18, child: FloatingActionButton(heroTag: 'sos_fab', onPressed: _triggerSOS, backgroundColor: AppColors.primary, child: const Icon(Icons.sos, color: Colors.white))),
            Positioned(right: 18, bottom: 90, child: FloatingActionButton.small(heroTag: 'wallet_fab', onPressed: () { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wallet opened (demo)"))); }, backgroundColor: Colors.white24, child: const Icon(Icons.account_balance_wallet, color: Colors.white))),
          ],
        ),
      ),
    );
  }

  void _openOverflowPanel() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Widget _trainerBookingTile(dynamic b) {
    final user = (b['User'] ?? b['userId'] ?? b['UserId'] ?? b['user'] ?? {});
    final userName = (user is Map ? (user['fullName'] ?? user['name']) : user)?.toString() ?? (b['userName'] ?? 'Client');
    final userCity = (user is Map ? (user['currentCity'] ?? user['city']) : '')?.toString() ?? '';
    final userState = (user is Map ? (user['currentState'] ?? user['state']) : '')?.toString() ?? '';

    final selectedSession = (b['selectedSession'] ?? '').toString();
    final selectedDate = b['selectedDate']?.toString() ?? b['sessionDate']?.toString() ?? '';
    final selectedTime = (b['selectedTime'] ?? '').toString();
    final price = (b['price'] ?? b['amount'] ?? '').toString();
    final isAccepted = (b['isAccepted'] == true || b['isAccepted']?.toString() == 'true' || b['accepted'] == true || b['accepted']?.toString() == 'true');

    final sessionLabel = selectedSession.isNotEmpty ? '${selectedSession[0].toUpperCase()}${selectedSession.substring(1)}' : 'Session';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  '$sessionLabel${selectedSession == 'monthly' ? ' (20 Sessions)' : ''} · ${_formatFullDate(selectedDate)}${selectedSession == 'single' && selectedTime.isNotEmpty ? ' | $selectedTime' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text('$userCity${userCity.isNotEmpty ? ", " : ""}$userState', style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),

            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 96, maxWidth: 150),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF3DD1FF), borderRadius: BorderRadius.circular(8)), child: Text('₹$price', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
                  if (!isAccepted)
                    TextButton(onPressed: () => _confirmAccept(b), style: TextButton.styleFrom(backgroundColor: Colors.white12), child: const Text('Accept', style: TextStyle(color: Colors.white))),
                  if (isAccepted)
                    TextButton(onPressed: () => _confirmComplete(b), style: TextButton.styleFrom(backgroundColor: Colors.white12), child: const Text('Complete', style: TextStyle(color: Colors.white))),
                  if (isAccepted)
                    TextButton(onPressed: () {
                      final userCopy = (user is Map) ? Map<String, dynamic>.from(user) : {'fullName': userName};
                      _showUserProfileModalDialog(userCopy);
                    }, style: TextButton.styleFrom(backgroundColor: Colors.white12), child: const Text('View Profile', style: TextStyle(color: Colors.white)))
                  else
                    TextButton(onPressed: () {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accept the booking to view contact details.')));
                    }, style: TextButton.styleFrom(backgroundColor: Colors.white12), child: const Text('View Profile', style: TextStyle(color: Colors.white70))),
                ])
              ]),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _showUserProfileModalDialog(Map<String, dynamic> selectedUser) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text((selectedUser['fullName'] ?? 'User'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white70))
                ]),
                const SizedBox(height: 8),
                if ((selectedUser['email'] ?? '').toString().isNotEmpty) Text('Email: ${selectedUser['email']}', style: const TextStyle(color: Colors.white70)),
                if ((selectedUser['mobileNumber'] ?? selectedUser['mobile'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Mobile: ${selectedUser['mobileNumber'] ?? selectedUser['mobile']}', style: const TextStyle(color: Colors.white70))),
                if ((selectedUser['currentAddress'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Address: ${selectedUser['currentAddress']}', style: const TextStyle(color: Colors.white70))),
                const SizedBox(height: 8),
                Text('Goal: ${selectedUser['goal'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndDrawer(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final drawerWidth = width * 0.8;
    return Drawer(
      backgroundColor: Colors.white,
      width: drawerWidth,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(children: [
              const CircleAvatar(radius: 26, backgroundColor: Colors.black12, child: Icon(Icons.person, color: Colors.black54)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trainerName.isNotEmpty ? trainerName : 'Trainer', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('View and edit profile', style: TextStyle(color: Colors.blue.shade600, fontSize: 13)),
              ])),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainerProfileEditRestrictedScreen()));
              }),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
              ListTile(leading: const Icon(Icons.person_outline), title: const Text('Profile'), trailing: const Icon(Icons.chevron_right), onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainerProfileEditRestrictedScreen()));
              }),
              ListTile(leading: const Icon(Icons.account_balance), title: const Text('Bank Details'), trailing: const Icon(Icons.chevron_right), onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BankDetailsEditScreen()));
              }),
              ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Settings'), trailing: const Icon(Icons.chevron_right), onTap: () {
                Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
              }),
              ListTile(leading: const Icon(Icons.info_outline), title: const Text('About Us'), trailing: const Icon(Icons.chevron_right), onTap: () {
                Navigator.pop(context);
                showAboutDialog(context: context, applicationName: 'FitStreet', applicationVersion: '1.0.0');
              }),
              ListTile(leading: const Icon(Icons.support_agent), title: const Text('Support'), trailing: const Icon(Icons.chevron_right), onTap: () {
                Navigator.pop(context);
                _openSupport();
              }),
              ListTile(leading: const Icon(Icons.more_horiz), title: const Text('Other'), trailing: const Icon(Icons.chevron_right), onTap: () {
                Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('More options coming soon')));
              }),
              const Divider(height: 16),
              ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout', style: TextStyle(color: Colors.red)), onTap: () async {
                Navigator.pop(context);
                await _logout();
              }),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _smallChoice(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      selected: selected,
      selectedColor: Colors.white24,
      backgroundColor: Colors.white12,
      onSelected: (_) => onTap(),
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.25))),
    );
  }

  Widget _profileCard(double width, String uiIdDisplay) {
    final displayId = uiIdDisplay.isNotEmpty ? uiIdDisplay : '';
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(radius: width < 360 ? 28 : 36, backgroundColor: Colors.white12, child: Text(trainerName.isNotEmpty ? trainerName[0].toUpperCase() : "T", style: const TextStyle(color: Colors.white, fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Text(trainerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              if (displayId.isNotEmpty)
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 72, minWidth: 48), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)), alignment: Alignment.center, child: Text(displayId, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center))),
            ]),
            const SizedBox(height: 6),
            Text("$cityCountry · $addressLine", style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]))
        ]),
      ),
    );
  }

  Widget _availabilityCard() {
    final bool disabled = !isAvailable;
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final currentSlots = availability[_selectedDay] ?? <String>{};

    return GlassCard(
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text("Availability", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              Tooltip(message: isAvailable ? "You're visible" : "Hidden from customer search", child: Switch(value: isAvailable, onChanged: (v) => _setAvailability(v))),
              IconButton(onPressed: _loadSlotsFromServer, icon: const Icon(Icons.refresh, color: Colors.white70)),
            ]),
            const SizedBox(height: 8),
            SizedBox(height: 42, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: days.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (ctx, idx) {
              final d = days[idx];
              final sel = _selectedDay == d;
              return ChoiceChip(label: Text(d, style: const TextStyle(color: Colors.white)), selected: sel, selectedColor: Colors.white24, backgroundColor: Colors.white12, onSelected: (v) {
                if (disabled) return;
                setState(() => _selectedDay = d);
              }, shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.3))));
            })),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: slotLabels.map((s) {
              final selected = currentSlots.contains(s);
              return FilterChip(label: Text(s, style: const TextStyle(color: Colors.white)), selected: selected, selectedColor: Colors.white24, backgroundColor: Colors.white12, onSelected: disabled ? null : (v) {
                setState(() {
                  if (v) availability[_selectedDay]!.add(s);
                  else availability[_selectedDay]!.remove(s);
                });
              }, shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.3))));
            }).toList()),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton.icon(onPressed: disabled ? null : _saveSlotsToServer, icon: const Icon(Icons.upload, size: 18), label: const Text("Update Slots"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white12)),
              const SizedBox(width: 12),
              TextButton(onPressed: disabled ? null : () => setState(() => availability[_selectedDay]!.clear()), child: const Text("Clear day")),
            ]),
          ]),
        ),
      ),
    );
  }
}
