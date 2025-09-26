// lib/widgets/glass_button.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool elevated; // subtle elevation toggle

  const GlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.7, -0.5),
          end: Alignment(0.8, 0.6),
          colors: [
            Color.fromRGBO(255,255,255,0.10),
            Color.fromRGBO(255,255,255,1.0),
            Color.fromRGBO(255,255,255,0.10),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevated
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ]
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(0.9),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 0.9),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Material(
              color: Colors.white.withOpacity(0.10),
              child: InkWell(
                onTap: onPressed,
                splashColor: Colors.white.withOpacity(0.06),
                child: Container(
                  padding: padding,
                  alignment: Alignment.center,
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
