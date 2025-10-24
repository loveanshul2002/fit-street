// lib/screens/booking/booking_screen.dart
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/glass_card.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String _activeTab = 'upcoming'; // upcoming / completed / rejected
  bool _loading = true;
  String? _error;
  List<dynamic> _bookings = [];
  String? _userId;
  String _baseUrl = 'https://api.fitstreet.in'; // default; FitstreetApi uses same

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sp = await SharedPreferences.getInstance();

      // ✅ pick correct user id from stored keys
      _userId = sp.getString('fitstreet_user_id') ??
          sp.getString('fitstreet_user_db_id') ??
          sp.getString('fitstreet_userId') ??
          sp.getString('user_id') ??
          sp.getString('id');

      final token = sp.getString('fitstreet_token') ?? '';

      if (_userId == null || _userId!.isEmpty) {
        setState(() {
          _error = 'User ID not found. Please login again.';
          _bookings = [];
          _loading = false;
        });
        return;
      }

      debugPrint('Fetching bookings for user: $_userId');
      await _fetchBookings(_activeTab, token);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _bookings = [];
        _loading = false;
      });
    }
  }

  Future<void> _fetchBookings(String tab, String token) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/session-bookings/user/${_userId!}/$tab');
      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      debugPrint('GET $uri');
      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode == 200) {
        dynamic body;
        try {
          body = jsonDecode(resp.body);
        } catch (_) {
          body = resp.body;
        }

        List items = [];
        if (body is Map && body['bookings'] is List) {
          items = body['bookings'];
        } else if (body is Map && body['data'] is List) {
          items = body['data'];
        } else if (body is List) {
          items = body;
        }

        // ✅ extra safety: filter by current userId
        final myId = _userId;
        if (myId != null && myId.isNotEmpty) {
          items = items.where((b) {
            try {
              final u = (b['userId'] ?? b['user'] ?? {});
              if (u is String) return u == myId;
              if (u is Map && u['_id'] != null) return u['_id'].toString() == myId;
              return false;
            } catch (_) {
              return false;
            }
          }).toList();
        }

        setState(() {
          _bookings = items;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Server ${resp.statusCode}: ${resp.body}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _bookings = [];
        _loading = false;
      });
    }
  }



  String _formatFullDate(dynamic dateRaw) {
    if (dateRaw == null) return '';
    try {
      final d = DateTime.parse(dateRaw.toString()).toLocal();
      return DateFormat('EEE, MMM d, yyyy').format(d);
    } catch (_) {
      return dateRaw.toString();
    }
  }

  Widget _tabButton(String key, String label) {
    final active = _activeTab == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () async {
          if (_activeTab == key) return;
          setState(() => _activeTab = key);
          final sp = await SharedPreferences.getInstance();
          final token = sp.getString('fitstreet_token') ?? '';
          _fetchBookings(key, token);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: active
                ? const LinearGradient(colors: [Color(0xFF50B0FF), Color(0xFF7C4DFF)])
                : null,
            color: active ? null : Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(active ? 1 : 0.9),
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookingCard(dynamic session) {
    // session is expected to have:
    // session.Trainer (object) with trainerImageURL, fullName, trainerUniqueId, trainerSpecializationProof (list), currentCity, currentState, email, mobileNumber
    // selectedSession, selectedTime, selectedDate, price, isAccepted, mode

    final trainer = session['Trainer'] ?? session['trainer'] ?? {};
    final trainerName = (trainer?['fullName'] ?? trainer?['name'] ?? '').toString();
    final trainerUnique = (trainer?['trainerUniqueId'] ?? trainer?['trainer_unique_id'] ?? '').toString();
    final trainerImage = (trainer?['trainerImageURL'] ?? trainer?['trainerImage'] ?? '').toString();
    final mode = (session['mode'] ?? '').toString();
    final isAccepted = (session['isAccepted'] == true) || (session['isAccepted']?.toString().toLowerCase() == 'true');
    final price = (session['price'] ?? session['amount'] ?? '').toString();
    final selectedSession = (session['selectedSession'] ?? '').toString();
    final selectedTime = (session['selectedTime'] ?? '').toString();
    final selectedDate = session['selectedDate'] ?? session['sessionDate'] ?? session['date'];

    // specialization list
    List<String> specs = [];
    final proofs = trainer?['trainerSpecializationProof'] ?? trainer?['trainerSpecialization'] ?? trainer?['specialization'] ?? [];
    if (proofs is List && proofs.isNotEmpty) {
      specs = proofs.map<String>((p) {
        if (p is Map) return (p['specialization'] ?? p['name'] ?? '').toString();
        return p.toString();
      }).where((s) => s.isNotEmpty).toList();
    } else if (proofs is String && proofs.isNotEmpty) {
      specs = proofs.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final location = [
      (trainer?['currentCity'] ?? trainer?['city'] ?? ''),
      (trainer?['currentState'] ?? trainer?['state'] ?? '')
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: Colors.white10,
                      child: trainerImage.isNotEmpty
                          ? Image.network(
                        trainerImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.cover),
                      )
                          : Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // main text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // name + badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trainerUnique.isNotEmpty ? '$trainerName ($trainerUnique)' : trainerName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ),
                            if (mode.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  mode.toLowerCase() == 'both'
                                      ? 'Online & Offline'
                                      : '${mode[0].toUpperCase()}${mode.substring(1)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              )
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${selectedSession[0].toUpperCase()}${selectedSession.substring(1)}'
                              '${selectedSession == 'monthly' ? ' (20 Sessions)' : ''} · ${_formatFullDate(selectedDate)}'
                              '${selectedSession == 'single' && selectedTime.isNotEmpty ? ' | $selectedTime' : ''}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        if (specs.isNotEmpty)
                          RichText(
                            text: TextSpan(
                              text: 'Specialization: ',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              children: [
                                TextSpan(text: specs.join(', '), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500))
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        if (location.isNotEmpty)
                          RichText(
                            text: TextSpan(
                              text: 'Location: ',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              children: [
                                TextSpan(text: location, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500))
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // price badge
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF3DD1FF), borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '₹${price}',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 12),
              // contact details or warning
              isAccepted
                  ? Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((trainer?['email'] ?? '').toString().isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.email, color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            (trainer?['email'] ?? '').toString(),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    if ((trainer?['mobileNumber'] ?? trainer?['mobile'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              (trainer?['mobileNumber'] ?? trainer?['mobile'] ?? '').toString(),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              )
                  : Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.18)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(
                          'Not accepted. Whenever trainer accept your session you can directly contact trainer.',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                        ))
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.white)));
    }
    if (_bookings.isEmpty) {
      return const Center(child: Text('No sessions found', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        return _bookingCard(_bookings[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Booked Sessions'),
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
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
              const SizedBox(width: 8),
              Image.asset('assets/image/fitstreet-bull-logo.png', width: 100, height: 40, fit: BoxFit.contain),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    _tabButton('upcoming', 'Upcoming'),
                    _tabButton('completed', 'Completed'),
                    _tabButton('rejected', 'Rejected'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final sp = await SharedPreferences.getInstance();
                      final token = sp.getString('fitstreet_token') ?? '';
                      await _fetchBookings(_activeTab, token);
                    },
                    child: _body(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
