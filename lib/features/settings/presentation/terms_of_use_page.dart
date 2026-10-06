import 'package:flutter/material.dart';
import 'legal_page.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalPage(
      title: 'Terms of Use',
      lastUpdated: DateTime(2026, 9, 10), // TODO: set to your actual publish date
      sections: const [
        LegalSection(
          '1. Acceptance of Terms',
          '[PLACEHOLDER — describe what it means for a rider to use the '
              'Truust Rider app and agree to these terms. Have a lawyer '
              'review before publishing.]',
        ),
        LegalSection(
          '2. Eligibility & Verification',
          '[PLACEHOLDER — describe age/legal requirements, the manual KYC '
              'review process, and what happens if verification is rejected.]',
        ),
        LegalSection(
          '3. Rider Responsibilities',
          '[PLACEHOLDER — vehicle condition, safe driving, handling of '
              'goods, timely pickup/delivery, communication with buyers/sellers.]',
        ),
        LegalSection(
          '4. Payments & Commission',
          '[PLACEHOLDER — how delivery fees are set/bid on, the 10% platform '
              'commission (referenced in getEarningsSummary), payout timing.]',
        ),
        LegalSection(
          '5. Cancellations & Disputes',
          '[PLACEHOLDER — when a job can be withdrawn/cancelled, how '
              'delivery disputes are handled, TRUUST\'s review process.]',
        ),
        LegalSection(
          '6. Account Suspension & Termination',
          '[PLACEHOLDER — grounds for suspension (fraud, repeated disputes, '
              'guarantor issues), and account deletion process.]',
        ),
        LegalSection(
          '7. Liability',
          '[PLACEHOLDER — this section carries real legal weight. Do not '
              'publish without a lawyer\'s review.]',
        ),
        LegalSection(
          '8. Governing Law & Contact',
          '[PLACEHOLDER — jurisdiction, and how to reach Truust support.]',
        ),
      ],
    );
  }
}
