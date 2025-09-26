import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';

class DietScreen extends StatelessWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dietItems = [
      {"name": "Organic Protein Pack", "price": "₹999", "desc": "High protein blend"},
      {"name": "Weight Loss Meal Plan", "price": "₹1499", "desc": "30-day diet program"},
      {"name": "Superfood Combo", "price": "₹799", "desc": "Chia, Flax, Seeds mix"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Diet & Wellness"),
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
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: dietItems.length,
          itemBuilder: (context, index) {
            final item = dietItems[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Added ${item['name']} to cart!")),
                  );
                },
                child: ListTile(
                  leading: const Icon(Icons.restaurant_menu, color: Colors.white),
                  title: Text(item["name"]!,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(item["desc"]!,
                      style: const TextStyle(color: Colors.white70)),
                  trailing: Text(item["price"]!,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
