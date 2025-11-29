import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';

class LegalPage extends StatelessWidget {
  final String title;
  final String assetHtmlPath;
  const LegalPage({super.key, required this.title, required this.assetHtmlPath});

  bool get _isAbout => title.toLowerCase().contains('about');
  bool get _privacy => title.toLowerCase().contains('privacy');
  bool get _terms => title.toLowerCase().contains('terms');
  bool get _refund => title.toLowerCase().contains('refund') || title.toLowerCase().contains('cancellation');
  bool get _shipping => title.toLowerCase().contains('shipping') || title.toLowerCase().contains('delivery');
  bool get _contact => title.toLowerCase().contains('contact');



        Widget _aboutContent() {
  const body = '''🏋️‍♂️ About FitStreet
Last Updated: October 27, 2025
Operated by: Ball Street Private Limited
Registered Office: B-10/128 , Kalyani, Nadia , West Bengal 741235
Official Email: support@fitstreet.in
Website: https://fitstreet.in

1. Who We Are
FitStreet is a doorstep fitness and wellness platform operated by Ball Street Private Limited, an Indian company registered under the Companies Act, 2013.
We bring verified personal trainers, nutritionists, and mental health counsellors directly to you — anywhere in Delhi NCR (Complete online platform outside Delhi NCR), 24 hours a day, 7 days a week.
Our mission is to make professional fitness and wellness accessible, safe, and personalized — whether you prefer one-on-one training at home or expert guidance online.
FitStreet connects:
• Certified fitness trainers who visit your location for personalized, safe, and goal-oriented workouts.
• Qualified nutritionists who provide online consultations and dietary guidance.
• Licensed mental health counsellors who offer private online sessions for emotional wellness and motivation.

2. Our Legal & Business Nature
Fit Street functions as a technology platform and facilitator, not a medical or healthcare institution.
We:
• Connect users with verified professionals.
• Provide tools for booking, payments, communication, and scheduling.
• Do not provide medical diagnosis, prescriptions, or emergency healthcare.
Each trainer, nutritionist, and counsellor operate as an independent service provider.
Fit Street is not responsible for the outcome of individual sessions but ensures professionalism, verification, and secure digital infrastructure.
We operate in compliance with:
• Companies Act, 2013
• Information Technology Act, 2000 & Rules (2021 Amendment)
• Digital Personal Data Protection Act, 2023 (DPDP Act)
• Consumer Protection Act, 2019
• Payment Aggregator Guidelines 2020 (RBI)
• Mental Healthcare Act, 2017 (for counsellor listings)

3. Our Services
🏠 1. Doorstep Fitness Training (24×7 Availability)
• Book certified trainers at your home, society gym, park, or office.
• Sessions are available anytime — 24 hours, 7 days a week, as per trainer availability.
• All trainers are identity-verified, background-checked, and trained in client safety protocols.
🧠 2. Mental Wellness Counselling (Online)
• Book private, one-on-one online sessions with licensed counsellors or psychologists.
• All counsellors follow the Mental Healthcare Act, 2017 and maintain strict confidentiality.
• FitStreet provides a secure digital environment for safe emotional support.
🥗 3. Nutrition Consultations (Online)
• Consult qualified nutritionists for balanced, healthy dietary guidance.
• Fit Street does not provide meal plans directly — only certified nutritionists offer professional recommendations through online sessions.
• All consultations follow ethical and evidence-based nutrition standards.

4. Our Mission
Our mission is simple —
👉 To make fitness and mental wellness as accessible as ordering food online.
We aim to revolutionize India’s fitness ecosystem by offering:
• 24×7 doorstep access to verified trainers.
• Scientifically guided online consultations with certified nutritionists and counsellors.
• Transparent, affordable, and secure wellness services for every home in Delhi NCR.

5. Our Core Principles
1. Safety First: Trainers are trained to maintain client safety and hygiene during sessions.
2. Data Privacy: All communications, bookings, and data are encrypted and stored securely.
3. Transparency: All pricing, profiles, and credentials are visible upfront.
4. Accessibility: Sessions available 24×7 — early morning, late night, or weekends.
5. Professionalism: Every professional on Fit Street is verified through a multi-level screening.

6. Legal & Regulatory Compliance
Fit Street strictly adheres to the following laws and guidelines:
Area — Regulation — Compliance
Business Registration — Companies Act, 2013 — ✅
Data Protection — Digital Personal Data Protection Act, 2023 (DPDP) — ✅
Online Payments — RBI Guidelines, PCI-DSS 3.2+ — ✅
Consumer Protection — CPA 2019 & E-commerce Rules, 2020 — ✅
Health & Safety — MHCA 2017 (for counsellors) — ✅
App Store Rules — Google Play & Apple App Store policies — ✅

7. Data Protection & User Privacy
We take user privacy extremely seriously.
Fit Street collects and processes data only to deliver booked services — never for unauthorised marketing or resale.
• All personal data is stored on encrypted servers.
• All transmissions are SSL/HTTPS secured.
• Access is restricted to authorised employees and verified professionals only.
• Users can request data access or deletion anytime under the DPDP Act 2023.
See our full Privacy Policy for detailed data handling and user rights.

8. Verification & Safety Protocol
• All trainers undergo KYC verification, background checks, and certification validation before activation.
• Female clients can request female trainers for safety.
• Sessions are monitored for client feedback and safety assurance.
• Counsellors and nutritionists are bound by confidentiality and ethical practice agreements.

9. Grievance Redressal & Consumer Support
As per Rule 3(2) of the IT (Intermediary Guidelines) Rules, 2021, the following officer is designated to handle complaints and disputes:
Grievance Officer: Aashu Nagar
Email: support@fitstreet.in
Response Time: Within 15 working days
Address: C Block , Sector – 63 , Noida , 201301
For general queries or assistance:
📧 support@fitstreet.app
📞 8587001919

10. Disclaimer
Fit Street is not a medical organisation.
All fitness, nutrition, and counselling services are intended for general wellness only and should not replace medical treatment.
Users are advised to consult their physicians before starting any new fitness or nutrition program.
Fit Street is not liable for injuries, damages, or outcomes arising from trainer or user actions outside professional scope.

11. Corporate Details
Entity: Ball Street Private Limited
Brand: Fit Street
Corporate Identity No.: U93190WB2025PTC280216
Registered Address: B-10/128, Kalyani, Nadia, West Bengal 741235
Email: Support@ballstreet.club
Directors: Gopal Mondal, Ashish Mishra
Jurisdiction: Courts of West Bengal

12. Continuous Improvement
Fit Street regularly updates its systems, terms, and policies to ensure compliance with:
• Latest Google Play & Apple App Store developer guidelines
• DPDP Act, 2023
• RBI, MeitY, and MHCA standards
All changes are publicly posted with an updated 27/10/2025.

🔒 Fit Street — India’s First 24×7 Doorstep Fitness & Wellness Platform
Delivering certified trainers at your doorstep across Delhi NCR, and Online across Pan India, and expert online guidance from nutritionists and mental health professionals — all in one secure, compliant, and trusted app.''';

    final baseStyle = const TextStyle(color: Colors.white70, height: 1.45);
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700, color: Colors.white);
    final lines = body.split('\n');
    final headingPattern = RegExp(r'^\d+\.\s');

    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isHeading = headingPattern.hasMatch(line);
      spans.add(TextSpan(text: line, style: isHeading ? boldStyle : baseStyle));
      // Re-add newline except possibly after last line to keep original formatting
      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _privacyContent() {
    const body = '''FitStreet Privacy Policy
Last Updated: September 15, 2025
Effective Date: September 15, 2025
FitStreet, operated by Ball Street Private Limited ("we", "our" or "us"), respects your privacy and is committed to protecting your personal data. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you visit our website, use our mobile applications, and engage with our fitness platform services (“Services”). By accessing or using FitStreet’s Services, you agree to the terms of this Privacy Policy and consent to the collection, use, and disclosure of your information as described below.
Compliance statement: This Privacy Policy complies with the Information Technology Act, 2000, the Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011, and Google Play Developer Program Policies (including the User Data Policy). We declare accurate data collection and sharing practices in the Google Play Console Data Safety form.

1. Information We Collect
1.1 Information You Provide to Us
• Personal Identification Information: name, date of birth, gender, photo, email address, phone number, address, and other contact details.
• Government Identifiers: PAN, Aadhaar (masked or reference tokens only), KYC documents, selfie for identity verification. By providing KYC or identity documents you expressly consent to such processing for verification and compliance purposes.
• Professional Information (trainers): certifications, experience, specialties, languages spoken.
• Payment Information: bank account details, UPI IDs, payment history, transaction details (processed via third-party payment processors). We do not store raw card numbers on our servers.
• Health & Fitness Data (sensitive): fitness goals, medical conditions (if shared), workout metrics, session notes, progress photos. By providing health or fitness data you explicitly consent to our processing of such sensitive personal data for the purposes described in this Policy.
• Communication Data: messages, feedback, and communications exchanged through the platform.
• User-generated Content: reviews, ratings, photos, or videos you upload.
1.2 Information Collected Automatically
• Device Information: IP address, device type, operating system, browser type.
• Usage Data: pages visited, features used, session duration, clicks, crash logs and diagnostics.
• Location Data: approximate location derived from IP or precise GPS location if you enable location sharing (with explicit consent).
• Cookies and Similar Technologies: used to personalize content, optimize user experience, and for analytics and advertising (with consent where required).

2. How We Use Your Information
We use data to:
• Provide, operate, and maintain our Services.
• Verify identities and perform KYC compliance checks (for trainers/payments).
• Connect trainers to clients and facilitate bookings, scheduling, and payments.
• Process payments, refunds, invoices and keep financial records.
• Communicate about bookings, updates, support issues, and security alerts.
• Personalize user experience (recommendations, reminders).
• Perform analytics to improve and debug the App.
• Send marketing communications where you have opted in (you may opt out).
• Comply with legal obligations and respond to lawful requests.
• Detect, prevent and respond to fraud, abuse and security threats.

3. Legal Basis for Processing (if applicable)
Under applicable laws (including the Information Technology Act, 2000):
• Processing necessary for contract performance (service delivery).
• Processing necessary to comply with legal obligations (KYC, taxation).
• Processing based on your consent (which you can withdraw to the extent permitted by law).
• Processing necessary for legitimate interests (security, fraud prevention), balanced with your rights.

4. Information Sharing and Disclosure
We do not sell or rent personal information. We may share data with:
• Service Providers: payment gateways, cloud hosting, analytics, push notifications, crash reporting, customer support and marketing providers. Example provider categories: Analytics (e.g., Google Analytics for Firebase), Push Notifications (e.g., Firebase Cloud Messaging), Payments (e.g., Razorpay, Stripe), Cloud Hosting (e.g., AWS, Google Cloud). Replace these examples with the actual providers you use.
• Regulatory Authorities: for compliance with laws, KYC, taxation or court orders.
• Trainers and Clients: limited profile information necessary to facilitate bookings and services.
• Legal Process: in response to lawful requests or to protect rights, property or safety.
• Business Transfers: in a merger, acquisition or sale; any such transfer will include appropriate confidentiality protections.
• Aggregate/Anonymised Data: shared for research or analytics in a manner that cannot identify you.

5. Storage, Retention & Security
• Storage & Transfers: Data is processed and stored in India and may be transferred to other countries with adequate protections. We implement reasonable safeguards for international transfers.
• Retention: We retain personal data only as long as necessary for service provision and legal compliance. When you delete your account, we will delete or anonymise account data within 90 days, except where we must retain certain records for legal, tax, or fraud-prevention reasons. Backups may persist for up to 180 days but will be isolated and deleted according to policy.
• Security: We use industry-standard technical and organisational measures (encryption in transit and at rest, access controls, periodic security audits and vulnerability assessments). However, no method is 100% secure.

6. Your Rights & Choices
Where local law grants you rights, you may:
• Access and correct personal data.
• Request deletion or restriction of processing (subject to legal exceptions).
• Request portability of your data in a machine-readable format.
• Withdraw consent for processing (where processing is consent-based).
• Opt out of marketing communications.
• Control cookies via browser or app settings.
• Data Deletion Request
If you want to delete your Fit Street account or any personal data shared with us, please email support@fitstreet.in with the subject “Delete My Account”.
Once we receive your request, your account and associated data will be permanently deleted within 7 business days.

To exercise rights, contact us at support@ballstreet.club. We will respond as required by applicable law.

7. Children’s Privacy
Our Services are not directed at children under 18. We do not knowingly collect personal data from children under 18 without verified parental consent. If we learn we have collected such data without consent, we will delete it promptly.

8. Cookies and Tracking Technologies
We use cookies and similar technologies to enhance UX, remember preferences, analyze usage, and (with consent) deliver targeted advertising. You can control cookie settings in your browser and within the app.

9. Third-Party SDKs and Links
Third-party SDKs used in the App (analytics, crash reporting, ad SDKs, payment SDKs) may collect data independently. Please review the privacy policies of such providers. The App may contain links to third-party websites; we are not responsible for their privacy practices.

10. Changes to This Privacy Policy
We may update this Policy. Material changes will be posted and, where required, we will notify you. Continued use constitutes acceptance.

11. Google Play Compliance
FitStreet collects and uses data in accordance with Google Play’s User Data Policy. We accurately disclose all data collection, use, and sharing practices in the Play Console Data Safety form and do not sell personal or sensitive user data to third parties.

12. Grievance Officer (India)
Grievance Officer: Abhishek Chauhan
Email: support@ballstreet.club
Phone: +91 8100 20 1919
Address: Ball Street Private Limited, Delhi NCR, India
We will acknowledge and respond to grievances within 30 days.

13. Contact Us
Email: support@ballstreet.club
Phone: +91 8100 20 1919
Address: Ball Street Private Limited, Delhi NCR, India
FitStreet – Fitness Delivered at your Door-Step''';

    final baseStyle = const TextStyle(color: Colors.white70, height: 1.45);
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700, color: Colors.white);
    final lines = body.split('\n');
    final headingPattern = RegExp(r'^\d+\.\s');

    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isHeading = headingPattern.hasMatch(line);
      spans.add(TextSpan(text: line, style: isHeading ? boldStyle : baseStyle));
      // Re-add newline except possibly after last line to keep original formatting
      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _termsContent() {
    const body = '''🧾 FitStreet Terms & Conditions (Updated for 2025)
(Applicable to both FitStreet Trainers and Members)
Last Updated: October 27 2025
FitStreet is owned and operated by Ball Street Private Limited, having its registered office in India (“Company”, “we”, “us”, or “our”).
These Terms govern your access to and use of the FitStreet mobile application, website, and related services (collectively, the “Platform”).
By registering, accessing, or using FitStreet, you agree to these Terms & Conditions and our Privacy Policy.
If you do not agree, you must not use the Platform.

PART A — Terms for Trainers / Counsellors / Psychologists
1. Registration & Membership
1.1 Trainers must complete digital registration and pay a one-time, non-refundable onboarding fee of ₹1499 (or as updated).
1.2 Registration includes digital profile access and visibility to potential clients.
1.3 FitStreet may approve, reject, or revoke registrations at its sole discretion and without obligation to disclose reasons.
2. Independent Contractor Status
2.1 Trainers act as independent professionals, not employees or agents of FitStreet.
2.2 They are solely responsible for taxes, statutory compliance, and professional licensing.
2.3 Nothing in this Agreement shall create employer-employee, joint-venture, or franchise relationships.
3. Professional Duties & Conduct
3.1 Provide safe, ethical, and professional fitness or wellness services.
3.2 Maintain valid certifications and liability insurance where required by law.
3.3 Wear FitStreet apparel and ID during sessions when applicable.
3.4 Do not share or solicit clients outside the Platform.
3.5 Maintain strict confidentiality regarding client information and platform data.
3.6 Breach may result in immediate suspension or termination.
4. Client Allocation & Payments
4.1 Client leads depend on geography, demand, and trainer performance; FitStreet provides no guarantee of minimum work or income.
4.2 Session payouts follow the rate card communicated in-app or via email and are processed weekly or monthly.
4.3 Platform fees, taxes, and gateway charges may be deducted before payout.
4.4 All payments are processed through RBI-regulated gateways compliant with PCI-DSS 3.2+, UPI, and Income Tax Act obligations.
5. Cancellations & No-Shows
5.1 Notify cancellations at least 12 hours in advance.
5.2 Repeated no-shows or late cancellations may reduce visibility or lead assignments.
5.3 FitStreet may impose penalties or deactivate accounts for habitual default.
6. Liability & Indemnity
6.1 Trainers are responsible for ensuring client safety and halting sessions upon signs of distress.
6.2 FitStreet is not liable for injuries, damages, or losses arising from trainer acts or omissions.
6.3 Trainers agree to indemnify and hold harmless FitStreet, its affiliates, directors, and employees against all claims resulting from their conduct or breach.
7. Intellectual Property & Branding
7.1 All FitStreet logos, marks, and materials remain Company property.
7.2 Trainers may use branding only for authorised promotional purposes.
7.3 Trainers cannot represent themselves as employees or authorised agents.
8. Data Protection & Confidentiality
8.1 Trainers shall protect client personal data in compliance with India’s Information Technology Act 2000, the Digital Personal Data Protection Act 2023, and (where applicable) GDPR.
8.2 Data collected must be used only for delivering booked services via FitStreet.
9. Termination
9.1 FitStreet may suspend or terminate Trainer accounts for misconduct, breach, inactivity, or fraud.
9.2 Termination may be immediate for severe violations.
9.3 Onboarding fees are non-refundable.
10. Platform Compliance
10.1 Trainers using the FitStreet App agree to abide by Google Play Store, Apple App Store, and any third-party service policies.
10.2 Any misuse of store platforms or payment gateways constitutes material breach.
11. Dispute Resolution & Governing Law
11.1 Disputes shall first be attempted through amicable negotiation, then mediation or arbitration under the Arbitration & Conciliation Act 1996.
11.2 Governing law: India.
11.3 Exclusive jurisdiction: Courts of West Bengal..

PART B — Terms for Members / Users
1. Eligibility & Account Responsibility
1.1 Users must be 18 years or older. Minors may participate under guardian supervision.
1.2 Provide accurate registration details and maintain confidentiality of login credentials.
1.3 You are responsible for all activity under your account.
2. Bookings & Payments
2.1 Sessions and plans may be booked through the app, website, or WhatsApp (where available).
2.2 Prices and taxes are displayed transparently. Payment confirms booking.
2.3 We accept secure digital payments via RBI-licensed gateways (UPI, cards, wallets).
2.4 Refunds follow FitStreet’s official Refund Policy, compliant with Consumer Protection Act 2019.
2.5 Partial or full refunds are at FitStreet’s discretion for valid cancellations or service failures.
3. User Obligations & Safety
3.1 Disclose any medical conditions before starting sessions.
3.2 Follow trainer guidance and safety instructions.
3.3 Provide adequate space and environment for workouts.
3.4 FitStreet may suspend accounts for unsafe or abusive behaviour.
4. Trainer Engagement
4.1 Trainers are independent service providers; FitStreet acts as a facilitator, not employer.
4.2 FitStreet verifies basic credentials but does not guarantee outcomes.
4.3 Report any misconduct immediately via in-app complaint form or email.
5. Cancellations & No-Shows
5.1 Cancel or reschedule at least 12 hours prior to avoid forfeiture.
5.2 No-shows are charged in full unless otherwise stated.
5.3 Frequent cancellations may limit booking privileges.
6. Assumption of Risk & Liability Waiver
6.1 You acknowledge fitness activities carry inherent risks and agree to participate voluntarily.
6.2 FitStreet, its Trainers, or affiliates shall not be liable for injury, illness, or damages arising from participation.
6.3 Consult a physician before starting any new program.
7. Privacy & Data Usage
7.1 Personal information is processed according to the FitStreet Privacy Policy.
7.2 Data may be shared with Trainers solely to deliver booked services.
7.3 We implement technical and organisational safeguards (encryption, secure storage, limited access).
7.4 Users may exercise data rights such as access or deletion via the support email.
8. Intellectual Property & Content
8.1 All text, graphics, videos, and software belong to FitStreet.
8.2 Users may not reproduce or distribute any Platform content without written consent.
8.3 User-generated reviews or media grant FitStreet a non-exclusive licence to use for promotional purposes.
9. App Store & Gateway Compliance
9.1 Your use of the FitStreet App is also governed by Google Play Store and Apple App Store policies.
9.2 All in-app purchases and subscriptions comply with the respective platform billing and refund rules.
9.3 Payment gateways are PCI-DSS-certified and operate under RBI’s Payment Aggregator Guidelines 2020.
10. Termination & Account Action
10.1 FitStreet may suspend or terminate accounts for breach, misuse, or fraud.
10.2 Termination does not relieve outstanding payment obligations.
10.3 Users may request account deletion by writing to support@fitstreet.in
11. Dispute Resolution & Governing Law
11.1 Parties agree to attempt mediation before arbitration.
11.2 Governing law: India.
11.3 Courts of West Bengal shall have exclusive jurisdiction.

PART C — General Provisions
• Entire Agreement: These Terms and Privacy Policy constitute the full agreement between you and FitStreet.
• Severability: If any provision is found invalid, remaining provisions remain enforceable.
• Amendments: FitStreet may modify these Terms by posting updated versions; continued use constitutes acceptance.
• Notices: All legal notices to be sent to Support@ballstreet.club''';

       final baseStyle = const TextStyle(color: Colors.white70, height: 1.45);
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700, color: Colors.white);
    final lines = body.split('\n');
    final headingPattern = RegExp(r'^\d+\.\s');

    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isHeading = headingPattern.hasMatch(line);
      spans.add(TextSpan(text: line, style: isHeading ? boldStyle : baseStyle));
      // Re-add newline except possibly after last line to keep original formatting
      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _refundContent() {
    const body = '''FitStreet Refund & Cancellation Policy
Last Updated: October 27, 2025
Operated by: Ball Street Private Limited
Website: https://fitstreet.in
Email: support@ballstreet.club

1. Overview
This Refund & Cancellation Policy governs payments and refunds for all users of the Fit Street Platform, operated by Ball Street Private Limited (“Company”, “we”, “us”).
It applies to both:
• Members/Clients who book fitness, nutrition, or counselling sessions, and
• Trainers/Counsellors/Nutritionists who register and provide services via the platform.
By completing a registration or booking, you agree to this Policy along with the Terms & Conditions and Shipping & Service Delivery Policy.

2. Nature of Services
Fit Street provides doorstep personal training, online nutrition consultations, and mental wellness counselling across Delhi NCR and online.
All offerings are services only — no physical goods are shipped.
Bookings are confirmed only after advance payment through secure RBI-compliant gateways.

3. Refund & Cancellation — For Members / Clients
3.1 Booking Payments
• Members pay 100% of the session or package amount in advance at the time of booking.
• Payment confirms your trainer’s time slot and session allocation.
3.2 Cancellation by Members
• Doorstep Training: Cancel or reschedule ≥12 hours before the session → full refund or free reschedule.
• Cancel <12 hours before the session → session fee forfeited (non-refundable).
• Online Sessions (Nutrition / Counselling): Cancel or reschedule ≥6 hours before start time → full refund or reschedule.
• Missed session or joining >15 minutes late → treated as delivered, non-refundable.
3.3 Package / Multi-Session Bookings
• Cancellation permitted within 7 days of purchase, provided no session has been availed.
• Once the first session is completed, the package becomes non-refundable.
• Remaining sessions can be rescheduled within package validity.
3.4 Cancellation by Fit Street
Fit Street may cancel or reassign bookings due to trainer unavailability, emergencies, or safety reasons.
In such cases:
• Members receive a free reschedule or 100% refund within 5–7 business days.
3.5 Refund Process for Members
• Approved refunds are processed via the original payment method only.
• Processing time: 5–7 business days (excluding bank delays).
• No cash or offline refunds are issued.

4. Refund & Cancellation — For Trainers / Counsellors / Nutritionists
4.1 Registration Fee
• Trainers pay a one-time non-refundable onboarding fee at the time of registration.
• This fee covers verification, profile setup, marketing, and onboarding materials.
• It is strictly non-refundable under all circumstances, including withdrawal, rejection, or inactivity.
4.2 Session Payments & Earnings
• When a member books a trainer, the full payment is collected in advance by Fit Street.
• Fit Street holds the amount in escrow until the session is delivered.
Payouts to Trainers:
Booking Type
Payment Release Timeline
Single session
Same day after completion verification
Multi-session / monthly package
Weekly payouts for completed sessions
FitStreet may withhold payments if:
• The trainer fails to deliver sessions,
• There are customer disputes, safety violations, or unverified attendance,
• There is breach of the Trainer Code of Conduct.
4.3 Cancellations by Trainers
• Trainers must provide ≥12 hours’ notice for cancellations.
• Frequent or last-minute cancellations can lead to reduced client allocations or deactivation.
• If a trainer cancels without notice, FitStreet may deduct or forfeit corresponding payouts.
4.4 Refunds Affecting Trainers
If FitStreet issues a refund to a client for an undelivered session, the respective payout will be reversed or adjusted from the trainer’s next cycle.

5. Exceptions & Non-Refundable Scenarios
Refunds will not be provided in the following cases:
• Trainer registration fee (non-refundable onboarding).
• Cancellations made by clients within 12 hours of session start.
• Client no-shows or late logins (beyond 15 minutes).
• Completed or partially completed sessions.
• Package cancellations after first session.
• Refund requests beyond 7 days of booking date.

6. Force Majeure
In events beyond FitStreet’s reasonable control (natural disasters, government restrictions, strikes, etc.), services may be postponed or rescheduled.
Refunds may be offered at FitStreet’s discretion depending on impact.

7. Fraud, Abuse & Misuse
Fit Street reserves the right to deny or reverse refunds in cases of:
• Payment disputes raised after verified service delivery,
• Fraudulent chargebacks, or
• Misuse of cancellation policy for repeated free sessions.

8. Refund & Payment Queries
For refund status, payment disputes, or transaction support:
📧 Email: support@fitstreet.in
📞 Helpline: +91 8100201919
Response Time: Within 24 working hours
For unresolved issues:
👤 Grievance Officer:Ashu Nagar
📧 Email: grievance@fitstreet.in
📍 Address: B-10/128, Kalyani , Nadia , West Bengal 741235
⏱️ Response Time: Within 15 working days

9. Governing Law
This Policy is governed by and construed in accordance with the laws of India, specifically under:
• The Consumer Protection Act, 2019, and
• The Indian Contract Act, 1872, and
• The Information Technology (Intermediary Guidelines) Rules, 2021.
Any disputes arising under this Policy shall be subject to the exclusive jurisdiction of courts at West Bengal, India.''';

        final baseStyle = const TextStyle(color: Colors.white70, height: 1.45);
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700, color: Colors.white);
    final lines = body.split('\n');
    final headingPattern = RegExp(r'^\d+\.\s');

    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isHeading = headingPattern.hasMatch(line);
      spans.add(TextSpan(text: line, style: isHeading ? boldStyle : baseStyle));
      // Re-add newline except possibly after last line to keep original formatting
      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _shippingContent() {
    const body = '''🚚 FitStreet Shipping & Service Delivery Policy
Last Updated: October 27, 2025
Operated by: Ball Street Private Limited
Website: https://fitstreet.in
Email: support@fitstreet.in

1. Overview
Fit Street is a service-based digital platform that provides doorstep personal training, online nutrition consultations, and mental wellness counselling.
We do not sell or ship any physical goods, merchandise, or equipment.
All bookings made through the Fit Street App or Website are treated as service appointments, not product deliveries.

2. Service “Delivery” Definition
For the purpose of consumer protection and platform compliance, “delivery” on FitStreet refers to:
• 🏠 Doorstep Fitness Sessions: The arrival of a verified trainer at the customer’s chosen location (home, park, gym, or office) within the scheduled time slot.
• 💻 Online Nutrition or Counselling Sessions: Activation of a secure video or chat session link at the confirmed date and time.
Once the trainer, nutritionist, or counsellor successfully conducts the booked session, the service is considered delivered in full.

3. Service Areas & Availability
• Doorstep training is currently available 24×7 across Delhi NCR, including Delhi, Gurugram, Noida, Faridabad, and Ghaziabad.
• Online consultations (nutrition & counselling) are available pan-India via the Fit Street App.
• All services are subject to professional availability and prior booking confirmation.

4. Booking Confirmation & Scheduling
• After successful payment, you will receive a booking confirmation message and session details through the app, email, or WhatsApp (where applicable).
• Users may reschedule sessions as per the Cancellation & Rescheduling Policy (generally 12-hour prior notice).
• FitStreet reserves the right to reassign trainers in case of unavailability, emergencies, or safety concerns.

5. Timelines
• Doorstep trainers generally reach within ±15 minutes of the scheduled slot, depending on traffic and location.
• Online sessions begin at the exact booked time; users must join on time to receive full session value.
• Delays caused by users may shorten the session duration without refund.

6. Cancellations, Rescheduling & Non-Delivery
FitStreet defines non-delivery as:
• Trainer or expert failing to show up within the scheduled time window without rescheduling or prior notice.
• Platform or technical failure preventing service access.
In such cases, the booking will either be:
• Rescheduled at no extra charge, or
• Fully refunded, as per the Refund Policy.
Cancellations by users with less than 12 hours’ notice are subject to session forfeiture.

7. Refunds & Failed Sessions
If a booked service cannot be delivered due to FitStreet’s internal error or unavailability, users are entitled to:
• Full refund of the session fee, or
• Free rescheduling within 7 days.
Refunds are processed via the original payment method and usually reflect within 5–7 business days, depending on the user’s bank or payment gateway.

8. No Physical Shipments
FitStreet does not:
• Ship fitness equipment, supplements, or accessories;
• Offer courier or logistics services;
• Charge any shipping or handling fees.
All services are digital or in-person experiences confirmed via the app.

9. Proof of Delivery
FitStreet may collect proof of service delivery in the following forms:
• GPS attendance verification of trainers.
• Digital session logs or screenshots for online consultations.
• User feedback or digital acknowledgment within the app.
This ensures transparency and compliance under the Consumer Protection (E-commerce) Rules, 2020.

10. Contact & Grievance Redressal
For any issues related to session delivery or booking disputes, please contact:
Grievance Officer: Ashu Nagar
📧 grievance@fitstreet.in
📍 B-10/128 , Kalyani, Nadia , West Bengal 741235
⏱️ Response Time: Within 15 working days

11. Governing Law
This Shipping & Delivery Policy is governed by the laws of India, and any disputes shall be subject to the exclusive jurisdiction of Courts in West Bengal''';




    final baseStyle = const TextStyle(color: Colors.white70, height: 1.45);
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700, color: Colors.white);
    final lines = body.split('\n');
    final headingPattern = RegExp(r'^\d+\.\s');

    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isHeading = headingPattern.hasMatch(line);
      spans.add(TextSpan(text: line, style: isHeading ? boldStyle : baseStyle));
      // Re-add newline except possibly after last line to keep original formatting
      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _contactcontent() {
    const body = '''Contact Us — FitStreet
Last Updated: October 27, 2025
Operated By: Ball Street Private Limited
Registered Office: B-10/128, Kalyani, Nadia, West Bengal 741235
Corporate Website: https://fitstreet.in

1. General Customer Support
Our team is available 24 × 7 to assist you with:
• Booking or rescheduling sessions
• Payment or refund queries
• Trainer or counsellor feedback
• App or technical support
📧 Email: support@fitstreet.in
📞 Phone / WhatsApp:+91 8100 20 1919
Response Time: Within 24 working hours

2. Corporate & Partnership Enquiries
For business collaborations, corporate fitness plans, or press inquiries:
📧 Email: ceo@ballstreet.club
📍 Mailing Address: Ball Street Private Limited, B-10/128, Kalyani, Nadia, West Bengal 741235

3. Legal & Grievance Redressal
In accordance with Rule 3(2) of the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, FitStreet has appointed a Grievance Officer to address user complaints relating to privacy, data use, or service delivery.
👤 Grievance Officer: Ashu Nagar
📧 Email: grievance@fitstreet.in
📍 Address: C Block , Sector 63 Noida
⏱️ Response Time: Within 15 working days of receipt of complaint
You may submit written complaints by email or postal mail. Please include:
• Your full name and registered contact details
• Description of the issue with supporting evidence
• Order ID or Booking reference (if applicable)

4. Data Protection Queries
For questions about how we collect, use, or store personal data under the Digital Personal Data Protection Act 2023 (DPDP), please contact our Data Protection Desk:
📧 Email: Support@ballstreet.club
We respond to all data rights requests (access, correction, erasure) within 30 days.

5. Operating Hours
Our administrative and customer support operations run round the clock for service issues.
For corporate and legal communications, office hours are:
Monday – Friday, 10 AM to 6 PM (IST).

6. Jurisdiction and Compliance
This Contact page is published in compliance with the Consumer Protection (E-Commerce) Rules 2020 and the Information Technology (Intermediary Guidelines 2021).
All communications are governed by the laws of India and subject to the exclusive jurisdiction of the courts at West Bengal.

🔒 FitStreet — Always Here for You, 24 × 7
Doorstep Fitness | Online Nutrition | Mental Wellness Support
''';

    final baseStyle = const TextStyle(color: Colors.white70, height: 1.45);
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700, color: Colors.white);
    final lines = body.split('\n');
    final headingPattern = RegExp(r'^\d+\.\s');

    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isHeading = headingPattern.hasMatch(line);
      spans.add(TextSpan(text: line, style: isHeading ? boldStyle : baseStyle));
      // Re-add newline except possibly after last line to keep original formatting
      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
          _isAbout
            ? _aboutContent()
            : _privacy
              ? _privacyContent()
              : _terms
                ? _termsContent()
                : _refund
                    ? _refundContent()
                    : _shipping
                      ? _shippingContent()
          : _contact
          ? _contactcontent()
                      : const Text(
                          'Content goes here. You can load markdown/HTML or static text. Contact us if you want us to wire live links or CMS-backed content.',
                          style: TextStyle(color: Colors.white70),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
