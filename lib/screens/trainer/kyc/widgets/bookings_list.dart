// lib/screens/trainer/widgets/bookings_list.dart
import 'package:flutter/material.dart';
import '../../../../widgets/glass_card.dart';

class BookingsList extends StatelessWidget {
  final TabController tabController;
  final List<Map<String, dynamic>> live;
  final List<Map<String, dynamic>> completed;
  final List<Map<String, dynamic>> upcoming;
  final void Function(Map<String, dynamic>) onAccept;
  final void Function(Map<String, dynamic>) onComplete;
  final void Function(Map<String, dynamic>) onViewContact;

  const BookingsList({
    super.key,
    required this.tabController,
    required this.live,
    required this.completed,
    required this.upcoming,
    required this.onAccept,
    required this.onComplete,
    required this.onViewContact,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(children: [
        TabBar(
          controller: tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicator: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
          tabs: const [
            Tab(text: "Live"),
            Tab(text: "Completed"),
            Tab(text: "Upcoming"),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 360),
          child: TabBarView(controller: tabController, children: [
            // Live
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: live.isEmpty ? const Center(child: Text("No live sessions", style: TextStyle(color: Colors.white70))) :
              ListView.separated(
                itemCount: live.length,
                separatorBuilder: (_,__) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final b = live[i];
                  final accepted = b['accepted'] == true;
                  return GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(b['client'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("${b['time']} • ${b['location']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text("₹${b['amount']}", style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            Text(accepted ? "Accepted" : "Pending", style: TextStyle(color: accepted ? Colors.greenAccent : Colors.orangeAccent)),
                          ])
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          if (!accepted) OutlinedButton(onPressed: () => onAccept(b), child: const Text("Accept")),
                          if (accepted) ElevatedButton(onPressed: () => onComplete(b), child: const Text("Complete")),
                          const SizedBox(width: 8),
                          TextButton(onPressed: () => onViewContact(b), child: const Text("View")),
                          const Spacer(),
                          if (accepted) Text("Contact: ${b['contact']}", style: const TextStyle(color: Colors.white70)),
                        ])
                      ]),
                    ),
                  );
                },
              ),
            ),

            // Completed
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: completed.isEmpty ? const Center(child: Text("No completed sessions", style: TextStyle(color: Colors.white70))) :
              ListView.separated(
                itemCount: completed.length,
                separatorBuilder: (_,__) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final b = completed[i];
                  return GlassCard(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.white12, child: Text(b['client'][0], style: const TextStyle(color: Colors.white))),
                      title: Text(b['client'], style: const TextStyle(color: Colors.white)),
                      subtitle: Text("${b['time']} • ${b['location']}", style: const TextStyle(color: Colors.white70)),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text("₹${b['amount']}", style: const TextStyle(color: Colors.white70)),
                        Text("Net ₹${(b['amount'] * 0.9).toStringAsFixed(0)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                      ]),
                    ),
                  );
                },
              ),
            ),

            // Upcoming
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: upcoming.isEmpty ? const Center(child: Text("No upcoming bookings", style: TextStyle(color: Colors.white70))) :
              ListView.separated(
                itemCount: upcoming.length,
                separatorBuilder: (_,__) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final b = upcoming[i];
                  return GlassCard(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.white12, child: Text(b['client'][0], style: const TextStyle(color: Colors.white))),
                      title: Text(b['client'], style: const TextStyle(color: Colors.white)),
                      subtitle: Text("${b['time']} • ${b['location']}", style: const TextStyle(color: Colors.white70)),
                      trailing: Text("₹${b['amount']}", style: const TextStyle(color: Colors.white70)),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
