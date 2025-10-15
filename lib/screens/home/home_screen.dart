// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';

// utils
import '../../utils/role_storage.dart';
import '../../utils/profile_storage.dart';
import '../../utils/user_role.dart';
import 'package:provider/provider.dart';
import '../../state/auth_manager.dart';


// screens referenced from the home screen
import '../trainers/trainer_list_screen.dart';
import '../bookings/booking_screen.dart';
import '../diet/diet_screen.dart';
import '../counsellors/counsellor_screen.dart';
import '../trainers/trainer_profile_screen.dart';
import '../trainer/trainer_register_wizard.dart';
import '../user/user_auth_screen.dart';
import '../user/profile_completion_wizard.dart';

// NEW: use the styled login screen
import '../login/login_screen_styled.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _profileComplete = false;
  bool _loadingProfileState = true;
  UserRole _role = UserRole.unknown;
  String _greetingName = '';
  void _onAuthChanged() {
    // When auth (login/logout) changes, refresh greeting and flags
    _loadProfileState();
  }

  @override
  void initState() {
    super.initState();
    _loadProfileState();
    // Listen for auth changes to update greeting live
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthManager?>();
      auth?.addListener(_onAuthChanged);
    });
  }

  @override
  void dispose() {
    // Remove listener to avoid leaks
    try {
      final auth = context.read<AuthManager?>();
      auth?.removeListener(_onAuthChanged);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadProfileState() async {
    // load role and profile-complete flag
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
          // Re-read saved name and update greeting
          final freshName = await getUserName();
          if (!mounted) return;
          if (freshName != null && freshName.isNotEmpty) {
            setState(() {
              _greetingName = freshName;
            });
          }
        }
      }
    } catch (_) {}
  }

  // Public method to trigger greeting refresh from other screens
  void refreshGreeting() {
    _loadProfileState();
  }

  Future<void> _openProfileFill() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileCompletionWizard()),
    );
    await _loadProfileState(); // refresh flag after return
  }

  Future<void> _confirmAndLogout(BuildContext ctx) async {
    final auth = ctx.read<AuthManager?>();
    if (auth == null) return;
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top bar with Login and Register button
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // We use AuthManager (Provider) to decide which buttons to show.
          Builder(builder: (ctx) {
            final auth = ctx.watch<AuthManager?>();
            final loggedIn = auth?.isLoggedIn ?? false;

            if (loggedIn) {
              // Show Logout button when logged in
              return Row(
                children: [
                  TextButton(
                    onPressed: () => _confirmAndLogout(ctx),
                    child: const Text(
                      "Logout",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            } else {
              // Not logged in — show Login and Register
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
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAuthScreen())),
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


      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Text("Hi $_greetingName 👋", style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text("Ready for your transformation?", style: TextStyle(color: Colors.white70)),

                const SizedBox(height: 20),

                // ===== Complete Profile CTA - only show when:
                //  - we've finished loading AND
                //  - user role == member (i.e. registered as user) AND
                //  - profile is NOT complete
                if (_loadingProfileState)
                  const SizedBox(height: 8)
                else if ((_role == UserRole.member || _role == UserRole.unknown) && !_profileComplete) ...[
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
                        if (!_profileComplete) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete profile to book trainers.")));
                          return;
                        }
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainerListScreen()));
                      },
                      child: _quickAction(Icons.fitness_center, "Trainers"),
                    ),
                    GlassCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingScreen())),
                      child: _quickAction(Icons.calendar_today, "Bookings"),
                    ),
                    GlassCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DietScreen())),
                      child: _quickAction(Icons.restaurant_menu, "Diet Plans"),
                    ),
                    GlassCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CounsellorScreen())),
                      child: _quickAction(Icons.psychology, "Counsellors"),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Featured Trainers
                Text("🔥 Featured Trainers", style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _trainerCard(context, "Rahul Sharma", "Yoga", "₹500"),
                      _trainerCard(context, "Sneha Kapoor", "Strength", "₹700"),
                      _trainerCard(context, "Amit Singh", "Zumba", "₹600"),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Popular Diet Plans
                Text("🥗 Popular Diet Plans", style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _dietCard(context, "Organic Protein Pack", "₹999"),
                      _dietCard(context, "Weight Loss Plan", "₹1499"),
                      _dietCard(context, "Superfood Combo", "₹799"),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Special Offers
                Text("⚡ Special Offers", style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                GlassCard(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Offer applied!")));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("20% OFF on First Booking 🎉",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text("Book your first session now and save big!", style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== Helpers =====

  // Removed: _showRoleDialog. Register now always opens UserAuthScreen.

  // OPEN the new styled login screen
  void _openLoginScreen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreenStyled()));
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

  Widget _trainerCard(BuildContext context, String name, String speciality, String price) {
    final trainer = {"name": name, "speciality": speciality, "price": price};
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GlassCard(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TrainerProfileScreen(trainer: trainer)));
        },
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white24), child: const Center(child: Icon(Icons.person, size: 50, color: Colors.white70)))),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text("$speciality · $price", style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _dietCard(BuildContext context, String name, String price) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GlassCard(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DietScreen())),
        child: Container(
          width: 160,
          height: 140, // Fixed height to prevent overflow
          padding: const EdgeInsets.all(12), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              const Icon(Icons.restaurant, color: Colors.white, size: 32), // Smaller icon
              const SizedBox(height: 8), // Reduced spacing
              Flexible(
                child: Text(
                  name, 
                  textAlign: TextAlign.center, 
                  maxLines: 2, // Limit to 2 lines
                  overflow: TextOverflow.ellipsis, // Handle overflow
                  style: const TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.w600,
                    fontSize: 14, // Smaller font
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                price, 
                maxLines: 1, // Single line for price
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70, 
                  fontWeight: FontWeight.bold,
                  fontSize: 13, // Smaller font
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
