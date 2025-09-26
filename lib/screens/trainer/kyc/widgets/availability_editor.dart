// lib/screens/trainer/widgets/availability_editor.dart
import 'package:flutter/material.dart';

// Shows a bottom-sheet availability editor and returns updated availability via onSave.
Future<void> showAvailabilityEditor({
  required BuildContext context,
  required Map<String, Set<String>> availability,
  required Set<String> selectedDays,
  required List<String> slotLabels,
  required void Function(Map<String, Set<String>> newAvailability, Set<String> newSelectedDays) onSave,
}) {
  // create local copy so we don't mutate original until save
  final tempAvail = <String, Set<String>>{};
  for (final k in availability.keys) tempAvail[k] = Set<String>.from(availability[k]!);
  final tempSelected = Set<String>.from(selectedDays);

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx2, setState) {
        return Container(
          padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(child: Text("Edit Availability", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => Navigator.pop(ctx2), icon: const Icon(Icons.close, color: Colors.white)),
              ]),
              const SizedBox(height: 8),
              const Align(alignment: Alignment.centerLeft, child: Text("Select days", style: TextStyle(color: Colors.white70))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: tempAvail.keys.map((d) {
                final sel = tempSelected.contains(d);
                return FilterChip(
                  label: Text(d, style: const TextStyle(color: Colors.white)),
                  selected: sel,
                  selectedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                  onSelected: (_) => setState(() {
                    if (sel) { tempSelected.remove(d); tempAvail[d]!.clear(); } else { tempSelected.add(d); }
                  }),
                );
              }).toList()),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text("Choose slots (toggled for selected days)", style: TextStyle(color: Colors.white70))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: slotLabels.map((slot) {
                final any = tempAvail.values.any((s) => s.contains(slot));
                return ChoiceChip(
                  label: Text(slot, style: const TextStyle(color: Colors.white)),
                  selected: any,
                  selectedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                  onSelected: (_) {
                    setState(() {
                      if (tempSelected.isEmpty) tempSelected.add("Mon");
                      for (final d in tempSelected) {
                        final set = tempAvail[d]!;
                        if (set.contains(slot)) set.remove(slot); else set.add(slot);
                      }
                    });
                  },
                );
              }).toList()),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(onPressed: () {
                    setState(() {
                      tempSelected.clear();
                      for (final k in tempAvail.keys) tempAvail[k]!.clear();
                    });
                    Navigator.pop(ctx2);
                  }, child: const Text("Clear"), style: OutlinedButton.styleFrom(foregroundColor: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(onPressed: () {
                    onSave(tempAvail, tempSelected);
                    Navigator.pop(ctx2);
                  }, child: const Text("Save"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white12)),
                ),
              ])
            ]),
          ),
        );
      });
    },
  );
}
