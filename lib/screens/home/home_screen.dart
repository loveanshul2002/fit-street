// lib/screens/home/home_screen.dart
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// import '../../widgets/glass_card.dart';

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
import '../yoga/yoga_screen.dart';
import '../consultation/consultation.dart';

import '../user/profile_completion_wizard.dart';
import '../User/profile_fill_screen.dart';
import '../User/user_auth_screen.dart';
import '../legal/legal_page.dart';

// NEW: use the styled login screen
import '../login/login_screen_styled.dart';
import '../../state/auth_manager.dart';
import '../../config/app_colors.dart';
// import 'featured_trainers_section.dart'; // removed in Figma redesign
//import 'circular_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // User avatar url for greeting pill
  String? _userImageUrl;
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
  // ignore: unused_field
  bool _profileComplete = false;
  // ignore: unused_field
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

  // Previously: show a modal dialog as a nudge. Replaced with a top banner on Home.
  // _maybePromptProfileCompletion();

    // If logged in but no name yet, fetch profile to populate fullName
    try {
      final auth = context.read<AuthManager?>();
      if (auth != null && auth.isLoggedIn) {
        // Always try to ensure image once, and name if missing
        Map<String, dynamic>? resp;
        if (role == UserRole.trainer) {
          final id = await auth.getApiTrainerId();
          if (id != null && id.isNotEmpty) {
            resp = await auth.fetchTrainerProfile(id);
          }
        } else {
          resp = await auth.getUserProfile();
        }

        // Refresh name if it was missing earlier
        final freshName = await getUserName();
        if (!mounted) return;
        if (freshName != null && freshName.isNotEmpty) {
          setState(() => _greetingName = freshName);
        }

        // Extract a plausible user image url from profile response
        try {
          if (_userImageUrl == null || _userImageUrl!.isEmpty) {
            final body = resp?['body'];
            String? url;
            if (body is Map) {
              final data = (body['data'] ?? body);
              if (data is Map) {
                const keys = [
                  'userImageURL', 'userImageUrl', 'imageUrl', 'imageURL', 'profileImageURL', 'profileImage', 'avatar', 'photo', 'image'
                ];
                for (final k in keys) {
                  final v = data[k];
                  if (v is String && v.trim().isNotEmpty) {
                    url = v.trim();
                    break;
                  }
                }
              }
            }
            if (url != null && mounted) {
              setState(() => _userImageUrl = url);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }


  void refreshGreeting() => _loadProfileState();

  // ignore: unused_element
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

  // ignore: unused_element
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
    final auth = context.watch<AuthManager?>();
    final loggedIn = auth?.isLoggedIn ?? false;
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      endDrawer: _buildEndDrawer(context),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: loggedIn ? 0 : 90,
        leading: loggedIn
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/image/fitstreet-bull-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
        title: loggedIn ? _userGreetingPill(context) : null,
        centerTitle: false,
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
                  // Orange filled Login pill
                  ElevatedButton(
                    onPressed: () => _openLoginScreen(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5B01),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      "Login",

                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // White Sign up pill with orange text/border
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => UserAuthScreen()));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5B01),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFFF5B01), width: 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      "Sign up",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 22),
                ],
              );
            }
          }),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/home-bg.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              if (loggedIn && !_profileComplete) ...[
                _profileIncompleteBanner(context),
                const SizedBox(height: 12),
              ],
              const Text(
                '24×7 at your Doorstep',
                style: TextStyle(color: Color(0xFFFF5C00), fontWeight: FontWeight.w900, fontSize: 20),

              ),
              const SizedBox(height: 16),
              _heroBanner(context),
              const SizedBox(height: 16),
              _ctaButton(context),
              const SizedBox(height: 20),
              _servicesGrid(context),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
      ),

      bottomNavigationBar: _bottomNav(context),
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
                          icon: Icons.calendar_month_outlined,
                          label: 'My Bookings',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingScreen()));
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

  // _trainerCard removed after extracting FeaturedTrainersSection


  // _dietCard helper removed

  // ===== New UI helpers =====
  Widget _profileIncompleteBanner(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B46C1).withOpacity(0.25), // subtle purple glow like screenshot
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Your profile is incomplete. Please update your profile to get the best experience.',
                style: TextStyle(color: Colors.white, height: 1.3),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () async {
                await _openProfileFill();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.12),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: const StadiumBorder(),
              ),
              child: const Text('Update Profile', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
  Widget _heroBanner(BuildContext context) {
    // Preserve original Figma aspect ratio (660×308) and cover the area without distortion
    return ClipRRect(
      borderRadius: BorderRadius.circular(45),
      child: AspectRatio(
        aspectRatio: 660 / 308,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image fills while keeping proportions
            Image.asset(
              'assets/image/Frame 178.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            // Left-to-right orange overlay like the Figma Frame 179
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerLeft,
                  colors: [Colors.transparent, Color(0xFFFF5C00)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctaButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5B01),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
  onPressed: () {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationScreen()));
  },
        child: const Text(
          'BOOK YOUR FREE CONSULTATION',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    );
  }

  Widget _servicesGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
  childAspectRatio: 0.85,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _serviceCard(
          title: 'Fitness Trainers',
          image: 'assets/image/Frame 30.png',
          alignment: Alignment.center,
          imageHeight:   130,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 0.001,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainerListScreen())),
        ),
        _serviceCard(
          title: 'Yoga Trainers',
          image: 'assets/image/Frame 30-2.png',
          alignment: Alignment.centerRight,
          imageHeight: 130,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 0.01,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const YogaScreen())),
        ),
        _serviceCard(
          title: 'Nutritionists',
          image: 'assets/image/Frame 30-3.png',
          alignment: Alignment.topCenter,
          imageHeight: 130,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 0.01,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionScreen())),
        ),
        _serviceCard(
          title: 'psychiatrists',
          image: 'assets/image/Frame 30-4.png',
          alignment: Alignment.center,
          imageHeight: 130,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 0.01,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CounsellorScreen())),
        ),
      ],
    );
  }

  Widget _serviceCard({
    required String title,
    required String image,
    required VoidCallback onTap,
    Alignment alignment = Alignment.center,
    double imageHeight = 217,
  TextStyle? titleStyle,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 6))],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: imageHeight,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  alignment: alignment,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: Center(
                child: Text(
                  title,
                  style: titleStyle ?? const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5C00),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [BoxShadow(color: Color(0x66FF5C00), blurRadius: 10, offset: Offset(0, 7))],
                  ),
                  child: const Text('Book Now', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
    final List<_BottomItem> items = [
      _BottomItem(Icons.home, 'Home'),
      _BottomItem(Icons.account_balance_wallet_outlined, 'Wallet'),
      _BottomItem(Icons.search, 'Search'),
      _BottomItem(Icons.notifications_none, 'Notification'),
      _BottomItem(Icons.person_outline, 'Account'),
    ];
    return Container(
      height: 84,
      decoration: const BoxDecoration(color: Color(0xFF020202)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((i) {
          return GestureDetector(
            onTap: () {
              switch (i.label) {
                case 'Wallet':
                  Navigator.pushNamed(context, '/wallet/user');
                  break;
                case 'Search':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainerListScreen()));
                  break;
                case 'Notification':
                  _toggleNotificationList();
                  break;
                case 'Account':
                  _openOverflowPanel();
                  break;
                default:
                  break;
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Icon(i.icon, color: const Color(0xFFD4D4D4)),
                const SizedBox(height: 6),
                Text(i.label, style: const TextStyle(color: Color(0xFFFF5503), fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _userGreetingPill(BuildContext context) {
    final name = _greetingName.isNotEmpty ? _greetingName : 'User';
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white12,
            backgroundImage: (_userImageUrl != null && _userImageUrl!.startsWith('http'))
                ? NetworkImage(_userImageUrl!)
                : null,
            child: (_userImageUrl == null || !_userImageUrl!.startsWith('http'))
                ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello  $name',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
              // Location intentionally omitted per request
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomItem {
  final IconData icon;
  final String label;
  const _BottomItem(this.icon, this.label);
}