import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/legal/legal_page.dart';

class FooterGlass extends StatelessWidget {
  final bool isLoggedIn;
  const FooterGlass({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Brand logo
                  Image.asset(
                    'assets/image/fitstreet-bull-logo.png',
                    height: 40,
                  ),
                  const Spacer(),
                  // Social icons
                  _SocialIcon(
                    icon: Icons.camera_alt_outlined,
                    url: 'https://www.instagram.com/fitstreet.in/',
                  ),
                  const SizedBox(width: 8),
                  _SocialIcon(
                    assetPath: 'assets/image/twitter.png',
                    url: 'https://x.com/Fitstreetindia',
                  ),
                  const SizedBox(width: 8),
                  _SocialIcon(
                    icon: Icons.facebook,
                    url:
                        'https://www.facebook.com/profile.php?id=61580348527991',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Links row
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  _FooterLegalLink(
                      label: 'About Us',
                      title: 'About Us',
                      assetPath: 'assets/legal/about.html'),
                  _FooterLegalLink(
                      label: 'Contact Us',
                      title: 'Contact Us',
                      assetPath: 'assets/legal/contact.html'),
                  _FooterLegalLink(
                      label: 'Terms & Conditions',
                      title: 'Terms & Conditions',
                      assetPath: 'assets/legal/terms.html'),
                  _FooterLegalLink(
                      label: 'Privacy Policy',
                      title: 'Privacy Policy',
                      assetPath: 'assets/legal/privacy.html'),
                  _FooterLegalLink(
                      label: 'Cancellation & Refunds Policy',
                      title: 'Refund & Cancellation',
                      assetPath: 'assets/legal/refund.html'),
                  _FooterLegalLink(
                      label: 'Shipping Policy',
                      title: 'Shipping Policy',
                      assetPath: 'assets/legal/shipping.html'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '© ${DateTime.now().year} FitStreet. All rights reserved. | A unit of Ballstreet pvt. ltd.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'GST No.: 19AANCB6485G1Z4 | CIN No.: U93190WB2025PTC280216',
                style: TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLegalLink extends StatelessWidget {
  final String label;
  final String title;
  final String assetPath;
  const _FooterLegalLink(
      {required this.label, required this.title, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LegalPage(title: title, assetHtmlPath: assetPath),
          ),
        );
      },
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData? icon;
  final String? assetPath; // e.g., 'assets/image/twitter.png'
  final String url;
  const _SocialIcon({this.icon, this.assetPath, required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: assetPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  assetPath!,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
