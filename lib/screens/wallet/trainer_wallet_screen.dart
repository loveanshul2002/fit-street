// lib/screens/wallet/trainer_wallet_screen.dart
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/auth_manager.dart';
import '../../widgets/glass_card.dart';

class TrainerWalletScreen extends StatefulWidget {
  const TrainerWalletScreen({super.key});

  @override
  State<TrainerWalletScreen> createState() => _TrainerWalletScreenState();
}

class _TrainerWalletScreenState extends State<TrainerWalletScreen> {
  bool _loadingSummary = false;
  bool _loadingPayments = false;
  bool _loadingWithdrawals = false;

  Map<String, dynamic>? _profileData;
  List<dynamic> _payments = [];
  List<dynamic> _withdrawals = [];

  int _clientPage = 1;
  final int _clientPageSize = 6;

  int _withdrawalPage = 1;
  final int _withdrawalPageSize = 6;

  bool _kycDone = false;

  // Helpers to coerce API values which may arrive as string/number/bool
  bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'approved';
    }
    return false;
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim()) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _fetchSummary(),
      _fetchPayments(),
      _fetchWithdrawals(),
    ]);
  }

  Future<void> _fetchSummary() async {
    final auth = context.read<AuthManager>();
    final trainerId = auth.trainerId;
    if (trainerId == null || trainerId.isEmpty) return;
    setState(() => _loadingSummary = true);
    try {
      // Fetch trainer profile for totals and KYC
      final resp = await auth.api.getTrainer(trainerId);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final parsed = jsonDecode(resp.body);
        final data = (parsed is Map) ? (parsed['data'] ?? parsed) : null;
        if (data is Map<String, dynamic>) {
          setState(() {
            _profileData = data;
            final status = data['status']?.toString().toLowerCase();
            _kycDone = _toBool(data['isKyc']) || _toBool(data['kycCompleted']) || status == 'approved';
          });
        }
      }
      // Fetch withdrawal amount to refresh _profileData.withdrawalAmount
      final wa = await auth.api.getWithdrawalAmount(trainerId);
      if (wa.statusCode == 200) {
        final body = jsonDecode(wa.body);
        final amount = (body['withdrawalAmount'] ?? body['data']?['withdrawalAmount']);
        setState(() {
          _profileData ??= {};
          _profileData!['withdrawalAmount'] = _toNum(amount);
        });
      }
    } catch (e) {
      _snack('Failed to load profile: $e');
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _fetchPayments() async {
    final auth = context.read<AuthManager>();
    final id = auth.trainerId;
    if (id == null || id.isEmpty) return;
    setState(() => _loadingPayments = true);
    try {
      final res = await auth.api.getTrainerSessionPayments(id);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['paymentDetails'] ?? body['data'] ?? []) as List<dynamic>;
        setState(() => _payments = list);
      } else {
        _snack('Failed to load client payments (${res.statusCode})');
      }
    } catch (e) {
      _snack('Network error: $e');
    } finally {
      if (mounted) setState(() => _loadingPayments = false);
    }
  }

  Future<void> _fetchWithdrawals() async {
    final auth = context.read<AuthManager>();
    final id = auth.trainerId;
    if (id == null || id.isEmpty) return;
    setState(() => _loadingWithdrawals = true);
    try {
      final res = await auth.api.getWithdrawals(id);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['withdrawals'] ?? body['data'] ?? []) as List<dynamic>;
        setState(() => _withdrawals = list);
      } else {
        _snack('Failed to load withdrawals (${res.statusCode})');
      }
    } catch (e) {
      _snack('Network error: $e');
    } finally {
      if (mounted) setState(() => _loadingWithdrawals = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDate(dynamic raw, {String pattern = 'dd/MM/yyyy · hh:mm a'}) {
    try {
      if (raw == null) return '-';
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return raw.toString();
      final local = dt.toLocal();
      final out = DateFormat(pattern).format(local).toLowerCase();
      return out;
    } catch (_) {
      return raw.toString();
    }
  }

  List<dynamic> get _clientPageItems {
    final start = (_clientPage - 1) * _clientPageSize;
    return _payments.skip(start).take(_clientPageSize).toList();
  }

  int get _clientPages => (_payments.isEmpty) ? 1 : ((_payments.length + _clientPageSize - 1) ~/ _clientPageSize);

  int get _clientEnd => ((_clientPage * _clientPageSize).clamp(0, _payments.length));

  List<dynamic> get _withdrawalPageItems {
    final start = (_withdrawalPage - 1) * _withdrawalPageSize;
    return _withdrawals.skip(start).take(_withdrawalPageSize).toList();
  }

  int get _withdrawalPages => (_withdrawals.isEmpty) ? 1 : ((_withdrawals.length + _withdrawalPageSize - 1) ~/ _withdrawalPageSize);

  int get _withdrawalEnd => ((_withdrawalPage * _withdrawalPageSize).clamp(0, _withdrawals.length));
  
  bool get _canWithdraw {
    final avail = _toNum(_profileData?['withdrawalAmount']);
    final active = _toBool(_profileData?['isWithdrawalActive']);
    // Mirror Angular: require KYC done to show button enabled, and also require active flag + positive amount
    return avail > 0 && active && _kycDone;
  }

  void _openWithdrawDialog() {
    if (!_canWithdraw) return;
    final avail = (_profileData?['withdrawalAmount'] ?? 0).toString();
    final controller = TextEditingController(text: avail);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Request Withdrawal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available for withdrawal: ₹${_profileData?['withdrawalAmount'] ?? 0}'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final raw = controller.text.trim();
                final parsed = num.tryParse(raw) ?? 0;
                Navigator.of(ctx).pop();
                await _confirmWithdraw(parsed);
              },
              child: const Text('Request'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmWithdraw(num amt) async {
    final avail = (_profileData?['withdrawalAmount'] ?? 0) as num;
    if (amt <= 0 || amt > avail) {
      _snack('Please enter a valid amount');
      return;
    }
    final id = context.read<AuthManager>().trainerId;
    if (id == null || id.isEmpty) return;
    try {
      final res = await context.read<AuthManager>().api.requestWithdrawal(id, amt);
      if (res.statusCode == 200 || res.statusCode == 201) {
        _snack('Withdrawal request submitted');
        await _fetchSummary();
        await _fetchWithdrawals();
      } else {
        _snack('Failed (${res.statusCode})');
      }
    } catch (e) {
      _snack('Network error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: const Text('Earnings & Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/image/bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Overview of earnings, client payments and withdrawal history', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),

                  // Earnings card
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: _loadingSummary
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Total', style: TextStyle(color: Colors.white70)),
                                      Text('₹${_profileData?['totalAmount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Net shown after ${_profileData?['commission'] ?? 0}% app fee', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const Divider(height: 20, thickness: 0.2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Text('Withdrawal Amount', style: TextStyle(color: Colors.white70)),
                                    Text('₹${_profileData?['withdrawalAmount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ]),
                                  ElevatedButton(
                                    onPressed: _canWithdraw ? _openWithdrawDialog : null,
                                    child: const Text('Withdraw'),
                                  )
                                ],
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Client payments
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: _loadingPayments
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Client Payments', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Total: ${_payments.length}', style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                              const Divider(height: 20, thickness: 0.2),
                              if (_payments.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(child: Text('No client payments', style: TextStyle(color: Colors.white70))),
                                )
                              else
                                ...[
                                  ..._clientPageItems.map((p) {
                                    final map = p as Map<String, dynamic>;
                                    final userName = map['User']?['fullName'] ?? 'User';
                                    final amount = map['amount'] ?? 0;
                                    final sessionType = map['sessionType'] ?? '';
                                    final updatedAt = map['updatedAt'];
                                    final isPaid = map['isPaid'] == true;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(children: [
                                        Expanded(flex: 3, child: Text(userName.toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                        Expanded(flex: 3, child: Text(_fmtDate(updatedAt), style: const TextStyle(color: Colors.white70))),
                                        Expanded(flex: 2, child: Text(sessionType.toString(), style: const TextStyle(color: Colors.white70))),
                                        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold)))),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isPaid ? Colors.green : Colors.amber,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(isPaid ? 'Paid' : 'Pending', style: TextStyle(color: isPaid ? Colors.white : Colors.black)),
                                        )
                                      ]),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Showing ${_payments.isEmpty ? 0 : ((_clientPage - 1) * _clientPageSize + 1)} - ${_clientEnd} of ${_payments.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      Row(children: [
                                        OutlinedButton(onPressed: _clientPage > 1 ? () => setState(() => _clientPage--) : null, child: const Text('Prev')),
                                        const SizedBox(width: 8),
                                        OutlinedButton(onPressed: _clientPage < _clientPages ? () => setState(() => _clientPage++) : null, child: const Text('Next')),
                                      ])
                                    ],
                                  )
                                ]
                            ],
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Withdrawals
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: _loadingWithdrawals
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Withdrawal / Payout History', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Total: ${_withdrawals.length}', style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                              const Divider(height: 20, thickness: 0.2),
                              if (_withdrawals.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(child: Text('No withdrawals found', style: TextStyle(color: Colors.white70))),
                                )
                              else ...[
                                ..._withdrawalPageItems.map((w) {
                                  final map = w as Map<String, dynamic>;
                                  final amount = map['amount'] ?? 0;
                                  final requestedAt = map['requestedAt'];
                                  final paidAt = map['paidAt'];
                                  final status = (map['status'] ?? '').toString();
                                  final isPaid = status.toLowerCase() == 'paid';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(children: [
                                      Expanded(flex: 3, child: Text(_fmtDate(requestedAt, pattern: 'dd/MM/yyyy hh:mm a'), style: const TextStyle(color: Colors.white70))),
                                      Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold)))),
                                      Expanded(flex: 3, child: Text(paidAt != null ? _fmtDate(paidAt, pattern: 'dd/MM/yyyy hh:mm a') : '-', style: const TextStyle(color: Colors.white70))),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPaid ? Colors.green : Colors.amber,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(isPaid ? 'Paid' : 'Pending', style: TextStyle(color: isPaid ? Colors.white : Colors.black)),
                                      )
                                    ]),
                                  );
                                }),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Showing ${_withdrawals.isEmpty ? 0 : ((_withdrawalPage - 1) * _withdrawalPageSize + 1)} - ${_withdrawalEnd} of ${_withdrawals.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    Row(children: [
                                      OutlinedButton(onPressed: _withdrawalPage > 1 ? () => setState(() => _withdrawalPage--) : null, child: const Text('Prev')),
                                      const SizedBox(width: 8),
                                      OutlinedButton(onPressed: _withdrawalPage < _withdrawalPages ? () => setState(() => _withdrawalPage++) : null, child: const Text('Next')),
                                    ])
                                  ],
                                )
                              ]
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
