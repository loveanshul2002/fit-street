// lib/screens/home/home_screen.dart
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/glass_card.dart';

// utils
import '../../utils/role_storage.dart';
import '../../utils/profile_storage.dart';
import '../../utils/user_role.dart';

// services
import '../../services/fitstreet_api.dart';

// screens referenced from the home screen
import '../trainers/trainer_list_screen.dart';
import '../bookings/booking_screen.dart';
import '../counsellors/counsellor_screen.dart';
import '../nutrition/nutrition_screen.dart';

import '../user/profile_completion_wizard.dart';
import '../User/profile_fill_screen.dart';
import '../User/user_auth_screen.dart';
import '../legal/legal_page.dart';

// NEW: use the styled login screen
import '../login/login_screen_styled.dart';
import '../../state/auth_manager.dart';
import '../../config/app_colors.dart';
 import 'featured_trainers_section.dart';
//import 'circular_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _openSupportAndPoliciesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              color: Colors.black.withOpacity(0.30),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).padding.bottom + 16,
                top: 12,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 4, width: 36, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.support_agent, color: Colors.white70),
                      title: const Text('Support', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openSupport();
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    ),
                    _policyTile(ctx, Icons.info_outline, 'About Us', 'About Us', 'assets/legal/about.html'),
                    _policyTile(ctx, Icons.privacy_tip_outlined, 'Privacy Policy', 'Privacy Policy', 'assets/legal/privacy.html'),
                    _policyTile(ctx, Icons.rule_folder_outlined, 'Terms & Conditions', 'Terms & Conditions', 'assets/legal/terms.html'),
                    _policyTile(ctx, Icons.receipt_long_outlined, 'Refund & Cancellation', 'Refund & Cancellation', 'assets/legal/refund.html'),
                    _policyTile(ctx, Icons.local_shipping_outlined, 'Shipping Policy', 'Shipping Policy', 'assets/legal/shipping.html'),
                    _policyTile(ctx, Icons.contact_support_outlined, 'Contact Us', 'Contact Us', 'assets/legal/contact.html'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _policyTile(BuildContext ctx, IconData icon, String label, String title, String assetPath) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(ctx);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalPage(title: title, assetHtmlPath: assetPath)));
      },
    );
  }
  bool _profileComplete = false;
  bool _loadingProfileState = true;
  UserRole _role = UserRole.unknown;
  String _greetingName = '';


  // ===== Notifications (USER) =====
  int _notificationCount = 0;
  List<dynamic> _notifications = [];
  bool _loadingNotifications = false;
  OverlayEntry? _notifEntry;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Removed animated background to simplify performance

  void _onAuthChanged() {
    _loadProfileState();
    _fetchNotificationsIfLoggedIn();
  }

  @override
  void initState() {
    super.initState();
    _loadProfileState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthManager?>();
      auth?.addListener(_onAuthChanged);
      _fetchNotificationsIfLoggedIn();
    });
  }

  @override
  void dispose() {
    try {
      final auth = context.read<AuthManager?>();
      auth?.removeListener(_onAuthChanged);
    } catch (_) {}
    try {
      _hideNotificationOverlay();
    } catch (_) {}
    super.dispose();
  }


  Future<void> _loadProfileState() async {
    final role = await getUserRole();
    final done = await getProfileComplete();
    final name = await getUserName();
    final mobile = await getMobile();

    if (!mounted) return;
    setState(() {
      _role = role;
      _profileComplete = done;
      _loadingProfileState = false;
      _greetingName = (name != null && name.isNotEmpty)
          ? name
          : (mobile != null && mobile.isNotEmpty)
              ? mobile
              : 'there';
    });

    // If logged in but no name yet, fetch profile to populate fullName
    try {
      final auth = context.read<AuthManager?>();
      if (auth != null && auth.isLoggedIn) {
        if (name == null || name.isEmpty) {
          if (role == UserRole.trainer) {
            final id = await auth.getApiTrainerId();
            if (id != null && id.isNotEmpty) {
              await auth.fetchTrainerProfile(id);
            }
          } else {
            await auth.getUserProfile();
          }
          final freshName = await getUserName();
          if (!mounted) return;
          if (freshName != null && freshName.isNotEmpty) {
            setState(() => _greetingName = freshName);
          }
        }
      }
    } catch (_) {}
  }

  void refreshGreeting() => _loadProfileState();

  Future<void> _openProfileFill() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileCompletionWizard()),
    );
    await _loadProfileState();
  }

  // ===== Support & SOS (mirror trainer dashboard) =====
  void _openSupport() {
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
title: const Text(
  "Support",
  style: TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  ),
),
content: const Text(
  "Need help?\nEmail: support@fitstreet.in\nPhone / WhatsApp: +91 8100 20 1919\n\nOur team is available 24×7 to assist you with anything you need.",
  style: TextStyle(
    color: Colors.white70,
    height: 1.5,
  ),
),

            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Close", style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerSOS() {
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
            title: const Text("Emergency (SOS)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text("This will alert support. Proceed?", style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
              TextButton(
                onPressed: () {
                  Navigator.pop(dCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS triggered.")));
                  }
                },
                child: Text("Confirm", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout(BuildContext ctx) async {
    final auth = ctx.read<AuthManager?>();
    if (auth == null) return;
    final confirm = await showDialog<bool>(
      context: ctx,
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
            title: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text("Are you sure you want to logout?", style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text("Cancel", style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm == true) {
      await auth.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  // ===== Notifications (USER) =====
  // Decide which API target to hit for notifications based on role
  Future<Map<String, String>?> _resolveNotificationTarget() async {
    final auth = context.read<AuthManager?>();
    final sp = await SharedPreferences.getInstance();

    if (_role == UserRole.trainer) {
      // Trainer: use canonical DB id for trainer endpoints
      String? trainerId;
      try {
        trainerId = await auth?.getApiTrainerId();
      } catch (_) {
        trainerId = null;
      }
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');
      if (trainerId == null || trainerId.isEmpty) return null;
      return {'type': 'trainer', 'id': trainerId};
    }

    // Default to user
    String? userId = auth?.userId;
    userId ??= sp.getString('fitstreet_user_db_id') ?? sp.getString('fitstreet_user_id');
    if (userId == null || userId.isEmpty) return null;
    return {'type': 'user', 'id': userId};
  }

  Future<void> _fetchNotificationsIfLoggedIn() async {
    try {
      final auth = context.read<AuthManager?>();
      if (auth?.isLoggedIn != true) {
        setState(() {
          _notifications = [];
          _notificationCount = 0;
        });
        return;
      }

      final target = await _resolveNotificationTarget();
      if (target == null) {
        setState(() {
          _notifications = [];
          _notificationCount = 0;
        });
        return;
      }

      await _getNotifications(target['type']!, target['id']!);
    } catch (_) {}
  }

  Future<void> _getNotifications(String userType, String id) async {
    setState(() => _loadingNotifications = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);

      // GET /api/common/notifications/{userType}/{id}/unread
      final resp = await api.getNotifications(userType, id);
      if (resp.statusCode == 200) {
        dynamic body;
        try {
          body = resp.body.isNotEmpty ? (jsonDecode(resp.body) as Object) : {};
        } catch (_) {
          body = {};
        }
        final map = (body is Map) ? body : {};
        final List raw = (map['notifications'] ?? []) as List;
        final now = DateTime.now();
        final cutoff = now.subtract(const Duration(days: 7));
        bool within7(dynamic n) {
          try {
            final v = n?['createdAt'];
            DateTime? dt;
            if (v is String) {
              dt = DateTime.tryParse(v);
              if (dt == null) {
                final numVal = int.tryParse(v);
                if (numVal != null) {
                  dt = numVal > 100000000000 ? DateTime.fromMillisecondsSinceEpoch(numVal) : DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
                }
              }
            } else if (v is int) {
              dt = v > 100000000000 ? DateTime.fromMillisecondsSinceEpoch(v) : DateTime.fromMillisecondsSinceEpoch(v * 1000);
            }
            if (dt == null) return true; // keep if unknown timestamp
            return dt.isAfter(cutoff);
          } catch (_) {
            return true;
          }
        }
        final filtered = raw.where(within7).toList();
        setState(() {
          _notifications = filtered;
          _notificationCount = filtered.length;
        });
      }
    } catch (_) {
      // ignore for badge
    } finally {
      if (mounted) setState(() => _loadingNotifications = false);
    }
  }

  Future<void> _markNotificationsAsRead(String userType, String id) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);

      // PATCH /api/common/notifications/{id}/read/{userType}
      await api.markNotificationsAsRead(id, userType);
      if (mounted) setState(() => _notificationCount = 0);
    } catch (_) {}
  }

  void _toggleNotificationList() async {
    // If already visible, hide it
    if (_notifEntry != null) {
      _hideNotificationOverlay();
      return;
    }

    final target = await _resolveNotificationTarget();
    if (target == null) return;

    _showNotificationOverlay();

  // Mark-as-read; do not refresh on open
    if (_notificationCount > 0) {
      await _markNotificationsAsRead(target['type']!, target['id']!);
      _notifEntry?.markNeedsBuild();
    }
  // Use the currently loaded list to avoid extra refresh
  }

  void _showNotificationOverlay() {
    if (!mounted) return;
    _notifEntry = _createNotifOverlayEntry();
    Overlay.of(context).insert(_notifEntry!);
  }

  void _hideNotificationOverlay() {
    _notifEntry?.remove();
    _notifEntry = null;
  }

  OverlayEntry _createNotifOverlayEntry() {
    return OverlayEntry(
      builder: (ctx) {
        final topPad = MediaQuery.of(ctx).padding.top + kToolbarHeight + 8;
        return Stack(
          children: [
            // Tap outside to dismiss
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideNotificationOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              right: 16,
              top: topPad,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(width: 0.75, color: Colors.white.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _loadingNotifications
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : (_notifications.isEmpty
                              ? const Text('No notifications', style: TextStyle(color: Colors.white70))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: _notifications.map<Widget>((n) {
                                    final msg = (n?['message'] ?? '').toString();
                                    final createdAt = (n?['createdAt'] ?? '').toString();
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(msg, style: const TextStyle(color: Colors.white)),
                                          Text(createdAt, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                )),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
  endDrawer: _buildEndDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 90,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/image/fitstreet-bull-logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),
        actions: [
          Builder(builder: (ctx) {
            final auth = ctx.watch<AuthManager?>();
            final loggedIn = auth?.isLoggedIn ?? false;

            if (loggedIn) {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    tooltip: "Wallet",
                    onPressed: () {
                      Navigator.pushNamed(context, '/wallet/user');
                    },
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications, color: Colors.white),
                        tooltip: "Notifications",
                        onPressed: _toggleNotificationList,
                      ),
                      if (_notificationCount > 0)
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
                              '$_notificationCount',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    tooltip: 'Menu',
                    onPressed: _openOverflowPanel,
                  ),
                  const SizedBox(width: 8),
                ],
              );
            } else {
              return Row(
                children: [
                  TextButton(
                    onPressed: () => _openLoginScreen(context),
                    child: const Text(
                      "Login",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => UserAuthScreen()));
                    },
                    child: const Text(
                      "Register",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            }
          }),
        ],
      ),

      // Body in a Stack so the dropdown can be positioned under the AppBar
      body: Stack(
        children: [
          // Background: image + subtle animated liquid gradient overlay
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/image/bg.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
              ),
            ),
            child: Stack(
              children: [
                // Static subtle overlay (animation removed)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.2,
                          colors: [
                            Colors.white.withOpacity(0.04),
                            Colors.white.withOpacity(0.00),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Auth state for body controls
                        Builder(builder: (ctx) {
                          // This empty builder exists just to establish a local watch context
                          // for auth within the body section below.
                          return const SizedBox.shrink();
                        }),
                        // Greeting
                        Text("Hi $_greetingName 👋", style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        const Text("Ready for your transformation?", style: TextStyle(color: Colors.white70)),

                        const SizedBox(height: 20),

                        // Circular categories UI
                     //   GlassCard(
                      //    child: Padding(
                        //    padding: const EdgeInsets.symmetric(vertical: 12),
                         //   child: Center(child: CircularHomeScreen(embedded: true)),
                       //   ),
                      //  ),

                        const SizedBox(height: 20),

                        // Complete Profile CTA (only when logged in)
                        if (_loadingProfileState)
                          const SizedBox(height: 8)
                        else if ((context.watch<AuthManager?>()?.isLoggedIn ?? false) && (_role == UserRole.member) && !_profileComplete) ...[
                          GlassCard(
                            onTap: _openProfileFill,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.person_add, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Complete your profile",
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        SizedBox(height: 6),
                                        Text("Add weight, height, goals & profile to start booking.",
                                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Quick Actions
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            GlassCard(
                              onTap: () {
                                // Allow browsing trainers without login or profile completion
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainerListScreen()));
                              },
                              child: _quickAction(Icons.fitness_center, "Trainers"),
                            ),
                            GlassCard(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingScreen())),
                              child: _quickAction(Icons.calendar_today, "Bookings"),
                            ),
                           // TODO: add nutrition section
                            GlassCard(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionScreen())),
                              child: _quickAction(Icons.restaurant_menu, "Nutrition"),
                            ),
                            // TODO: add counsellors section
                            GlassCard(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CounsellorScreen())),
                              child: _quickAction(Icons.psychology, "Counsellors"),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // TODO: Featured Trainers
                        const FeaturedTrainersSection(),

                        const SizedBox(height: 32),

                        // Removed Popular Diet Plans and Special Offers sections
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Notification dropdown now rendered via OverlayEntry above the AppBar

          // Floating actions (Support & SOS)
          Positioned(
            left: 18,
            bottom: 18,
            child: FloatingActionButton(
              heroTag: 'home_support_fab',
              onPressed: _openSupport,
              backgroundColor: AppColors.secondary,
              child: const Icon(Icons.headset_mic, color: Colors.white),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton(
              heroTag: 'home_sos_fab',
              onPressed: _triggerSOS,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.sos, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Helpers =====

  void _openLoginScreen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreenStyled()));
  }

  void _openOverflowPanel() {
  _scaffoldKey.currentState?.openEndDrawer();
  }

  // Drawer helper with glass-ish styling similar to trainer dashboard
  Widget _buildEndDrawer(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final drawerWidth = width * 0.8;
    return Drawer(
      backgroundColor: Colors.transparent,
      width: drawerWidth,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            color: Colors.black.withOpacity(0.35),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greetingName.isNotEmpty ? _greetingName : 'User',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        const Text('View and edit profile', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _drawerItem(
                          icon: Icons.person_outline,
                          label: 'Profile',
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProfileFillScreen(editableBasics: true)),
                            );
                            await _loadProfileState();
                          },
                        ),
                      
                        _drawerItem(
                          icon: Icons.policy,
                          label: 'Support & Policies',
                          onTap: () {
                            Navigator.pop(context);
                            _openSupportAndPoliciesSheet(context);
                          },
                        ),
                    
                    
                        _drawerItem(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
                          },
                        ),
                        const Divider(height: 16, color: Colors.white24),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Logout', style: TextStyle(color: Colors.red)),
                          onTap: () async {
                            Navigator.pop(context);
                            await _confirmAndLogout(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon, color: Colors.white70),
          title: Text(label, style: const TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 40, color: Colors.white),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    );
  }

  // _trainerCard removed after extracting FeaturedTrainersSection


  // _dietCard helper removed
}