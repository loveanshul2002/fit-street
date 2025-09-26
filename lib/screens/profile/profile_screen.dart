import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = {
      "name": "Amit Sharma",
      "membership": "Premium Plan",
      "validTill": "Feb 2025",
      "wallet": "₹1200",
      "sessions": "12",
      "trainers": "8",
      "hours": "45"
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ✅ Profile Card
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundImage: AssetImage("assets/image/user.png"),
                      ),
                      const SizedBox(height: 12),
                      Text(user["name"]!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(user["membership"]!,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text("Valid till ${user["validTill"]}",
                          style: const TextStyle(
                              color: Colors.greenAccent, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ✅ Wallet
              GlassCard(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet,
                      color: Colors.white),
                  title: const Text("Wallet Balance",
                      style: TextStyle(color: Colors.white)),
                  trailing: Text(user["wallet"]!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ),

              const SizedBox(height: 24),

              // ✅ Stats
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(user["sessions"]!, "Sessions"),
                      _buildStat(user["trainers"]!, "Trainers"),
                      _buildStat(user["hours"]!, "Hours"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ✅ Settings & Logout
              GlassCard(
                onTap: () {},
                child: const ListTile(
                  leading: Icon(Icons.settings, color: Colors.white),
                  title: Text("Settings",
                      style: TextStyle(color: Colors.white)),
                  trailing:
                  Icon(Icons.arrow_forward_ios, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Logging out... (not implemented)")));
                },
                child: const ListTile(
                  leading: Icon(Icons.logout, color: Colors.redAccent),
                  title: Text("Logout",
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
