import 'package:flutter/material.dart';

class PolicyTile extends StatelessWidget {
  final String title, body;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onRead; // optional navigation/open callback
  const PolicyTile({super.key, required this.title, required this.body, required this.value, required this.onChanged, this.onRead});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      // was Colors.white.withOpacity(0.10)
      color: Color.fromARGB((0.10 * 255).round(), 255, 255, 255),
      borderRadius: BorderRadius.circular(12),
      // was Colors.white.withOpacity(0.25)
      border: Border.all(color: Color.fromARGB((0.25 * 255).round(), 255, 255, 255))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          iconColor: Colors.white70, collapsedIconColor: Colors.white70,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12,0,12,8),
              child: GestureDetector(
                onTap: onRead,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  body,
                  style: TextStyle(
                    color: onRead != null ? Colors.lightBlueAccent : Colors.white70,
                    decoration: onRead != null ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
              ),
            ),
      CheckboxListTile(
        value: value,
        onChanged: (v)=> onChanged(v ?? false),
        checkColor: Colors.white,
        // was Colors.white.withOpacity(0.25)
        activeColor: Color.fromARGB((0.25 * 255).round(), 255, 255, 255),
        title: const Text("I have read and agree", style: TextStyle(color: Colors.white)),
        controlAffinity: ListTileControlAffinity.leading),
          ],
        ),
      ),
    );
  }
}
