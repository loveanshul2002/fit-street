// lib/screens/wallet/user_wallet_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../state/auth_manager.dart';
import '../../widgets/glass_card.dart';

class UserWalletScreen extends StatefulWidget {
  const UserWalletScreen({super.key});

  @override
  State<UserWalletScreen> createState() => _UserWalletScreenState();
}

class _UserWalletScreenState extends State<UserWalletScreen> {
  bool _loading = false;
  List<dynamic> _payments = [];

  // pagination
  int _page = 1;
  final int _pageSize = 6;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    final auth = context.read<AuthManager>();
    final userId = auth.userId;
    final api = auth.api;
    if (userId == null || userId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await api.getUserSessionPayments(userId);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['paymentDetails'] ?? body['data'] ?? []) as List<dynamic>;
        setState(() => _payments = list);
      } else {
        _showSnack('Failed to load payments (${res.statusCode})');
      }
    } catch (e) {
      _showSnack('Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDate(dynamic raw) {
    try {
      if (raw == null) return '-';
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return raw.toString();
      final local = dt.toLocal();
      final date = DateFormat('dd/MM/yyyy').format(local);
      final time = DateFormat('hh:mm a').format(local).toLowerCase();
      return '$date · $time';
    } catch (_) {
      return raw.toString();
    }
  }

  List<dynamic> get _paged {
    final start = (_page - 1) * _pageSize;
    return _payments.skip(start).take(_pageSize).toList();
  }

  int get _pages => (_payments.isEmpty) ? 1 : ((_payments.length + _pageSize - 1) ~/ _pageSize);

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
        title: const Text('Wallet & Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                  const Text('Wallet & Transactions Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Overview of wallet balance, transaction history, and payment methods.', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: _loading
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Total: ${_payments.length}', style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                              const Divider(height: 20, thickness: 0.2),
                              if (_payments.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(child: Text('No payments found', style: TextStyle(color: Colors.white70))),
                                )
                              else ...[
                                ..._paged.map((p) {
                                  final map = p as Map<String, dynamic>;
                                  final trainerName = map['Trainer']?['fullName'] ?? 'Coach';
                                  final amount = map['amount'] ?? 0;
                                  final sessionType = map['sessionType'] ?? '';
                                  final updatedAt = map['updatedAt'];
                                  final isPaid = map['isPaid'] == true;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(children: [
                                      Expanded(flex: 3, child: Text(trainerName.toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
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
                                    Text('Showing ${_payments.isEmpty ? 0 : ((_page - 1) * _pageSize + 1)} - ${(_page * _pageSize).clamp(0, _payments.length)} of ${_payments.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    Row(children: [
                                      OutlinedButton(onPressed: _page > 1 ? () => setState(() => _page--) : null, child: const Text('Prev')),
                                      const SizedBox(width: 8),
                                      OutlinedButton(onPressed: _page < _pages ? () => setState(() => _page++) : null, child: const Text('Next')),
                                    ]),
                                  ],
                                )
                              ]
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
