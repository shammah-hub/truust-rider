import 'package:flutter/material.dart';
import 'legal_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalPage(
      title: 'Privacy Policy',
      lastUpdated: DateTime(2026, 9, 10), // TODO: set to your actual publish date
      sections: const [
        LegalSection(
          '1. Information We Collect',
          '[PLACEHOLDER — name, phone, email, home address, city, ID '
              'document + selfie for KYC, vehicle/plate details, guarantor '
              'contact info, location data during active deliveries.]',
        ),
        LegalSection(
          '2. How We Use Your Information',
          '[PLACEHOLDER — matching you with delivery jobs, manual identity '
              'verification, rider tier/rewards calculation, payouts, '
              'fraud/dispute investigation, contacting guarantors only if '
              'something serious comes up.]',
        ),
        LegalSection(
          '3. Third-Party Services',
          '[PLACEHOLDER — list the actual processors you use: Firebase '
              '(storage/auth/database), Monnify (payments/payouts), '
              'Cloudinary (media uploads), push notification providers.]',
        ),
        LegalSection(
          '4. Data Retention',
          '[PLACEHOLDER — how long ID documents, selfies, and job history '
              'are kept, and what happens to them on account deletion.]',
        ),
        LegalSection(
          '5. Your Rights',
          '[PLACEHOLDER — access, correction, deletion requests, and how '
              'to exercise them.]',
        ),
        LegalSection(
          '6. Data Security',
          '[PLACEHOLDER — describe actual safeguards in place, e.g. '
              'Firestore security rules, encrypted storage.]',
        ),
        LegalSection(
          '7. Contact Us',
          '[PLACEHOLDER — support email/contact for privacy questions.]',
        ),
      ],
    );
  }
}
