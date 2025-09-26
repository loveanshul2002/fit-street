import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final upcoming = [
      {
        "trainer": "Rahul Sharma",
        "speciality": "Yoga Trainer",
        "time": "Tomorrow · 7:00 AM",
        "price": "₹500",
        "status": "Confirmed"
      },
      {
        "trainer": "Dr. Meera Kapoor",
        "speciality": "Psychologist",
        "time": "Sep 6 · 6:00 PM",
        "price": "₹800",
        "status": "Pending"
      },
    ];

    final past = [
      {
        "trainer": "Sneha Kapoor",
        "speciality": "Strength Trainer",
        "time": "Aug 28 · 8:00 PM",
        "price": "₹700",
        "status": "Completed"
      },
      {
        "trainer": "Amit Singh",
        "speciality": "Zumba Trainer",
        "time": "Aug 15 · 7:00 AM",
        "price": "₹600",
        "status": "Completed"
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bookings"),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text("📅 Upcoming Sessions",
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              ...upcoming.map((b) => _bookingCard(b)),

              const SizedBox(height: 24),
              Text("✅ Past Sessions",
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              ...past.map((b) => _bookingCard(b)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, String> booking) {
    Color statusColor;
    switch (booking["status"]) {
      case "Confirmed":
        statusColor = Colors.greenAccent;
        break;
      case "Pending":
        statusColor = Colors.orangeAccent;
        break;
      default:
        statusColor = Colors.white70;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        onTap: () {},
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white24,
            child: Text(
              booking["trainer"]![0],
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(booking["trainer"]!,
              style: const TextStyle(color: Colors.white)),
          subtitle: Text("${booking["speciality"]} · ${booking["time"]}",
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(booking["price"]!,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text(booking["status"]!,
                  style: TextStyle(color: statusColor, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
