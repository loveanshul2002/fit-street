import 'package:flutter/material.dart';

class PolicyTile extends StatelessWidget {
  final String title, body;
  final bool value;
  final ValueChanged<bool> onChanged;
  const PolicyTile({super.key, required this.title, required this.body, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          iconColor: Colors.white70, collapsedIconColor: Colors.white70,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(12,0,12,8),
                child: Text(body, style: const TextStyle(color: Colors.white70))),
            CheckboxListTile(
                value: value, onChanged: (v)=> onChanged(v ?? false),
                checkColor: Colors.white, activeColor: Colors.white.withOpacity(0.25),
                title: const Text("I have read and agree", style: TextStyle(color: Colors.white)),
                controlAffinity: ListTileControlAffinity.leading),
          ],
        ),
      ),
    );
  }
}
