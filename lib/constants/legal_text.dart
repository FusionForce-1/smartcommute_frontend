// lib/constants/legal_text.dart
//
// User Agreement + Privacy Policy shown from the register screen's consent
// checkbox. Same text as the web portal's web_portal/js/legal.js - keep
// them in sync.

class LegalDoc {
  const LegalDoc({
    required this.title,
    required this.updated,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String updated;
  final String intro;

  /// (heading, bullet points)
  final List<(String, List<String>)> sections;
}

const LegalDoc userAgreement = LegalDoc(
  title: 'User Agreement',
  updated: 'October 2026',
  intro:
      'This agreement covers your use of SmartCommute, a transit information service for Cebu City that connects commuters, jeepney operators and their drivers. By creating an account you agree to these terms.',
  sections: [
    (
      'Your account',
      [
        'Give accurate information when you register and keep it up to date.',
        'Keep your password private. You are responsible for what happens under your account.',
        'One account per person. Do not sign up on behalf of someone else without their permission.',
      ],
    ),
    (
      'For commuters',
      [
        'Routes, stops, fares and arrival estimates are for information only. Vehicles can be delayed, rerouted or off duty, so plan with some allowance.',
        'Official fares are set by the LTFRB. Fare estimates in the app may differ from what you pay.',
        'Ride reviews and feedback must be honest and respectful. Do not post false reports, insults or personal information about drivers or other commuters.',
      ],
    ),
    (
      'For operators',
      [
        'You must hold a valid franchise for the routes you operate and give your real company and franchise details.',
        'New operator accounts are reviewed by a SmartCommute administrator. Fleet, route and announcement tools unlock once your account is verified.',
        'You are responsible for the vehicles, drivers, routes and announcements you add, and for keeping them accurate.',
        'Your first 3 months are free. After that the plan is ₱1,000 a year, paid through PayPal. Without an active plan, the number of vehicles you can run is limited.',
      ],
    ),
    (
      'Acceptable use',
      [
        'Do not misuse the service: no fake accounts, false alerts, spam, harassment, or attempts to break into, overload or copy the system.',
        'Do not use SmartCommute for anything unlawful.',
      ],
    ),
    (
      'Suspension and closing accounts',
      [
        'We may suspend or close an account that breaks this agreement or puts other users at risk. You can stop using SmartCommute at any time.',
      ],
    ),
    (
      'No guarantees',
      [
        'SmartCommute is provided "as is". We work to keep it accurate and available, but we cannot promise it will always be error-free or online, and we are not liable for missed trips or losses from relying on it.',
      ],
    ),
    (
      'Changes',
      [
        'We may update this agreement. If the changes are significant we will let you know in the app. Continuing to use SmartCommute after an update means you accept it.',
      ],
    ),
  ],
);

const LegalDoc privacyPolicy = LegalDoc(
  title: 'Privacy Policy',
  updated: 'October 2026',
  intro:
      'SmartCommute respects your privacy and handles personal data in line with the Data Privacy Act of 2012 (Republic Act No. 10173). This policy explains what we collect and why.',
  sections: [
    (
      'What we collect',
      [
        'Account details: your name, email address, and password (stored encrypted, never in plain text). If you sign in with Google, we receive your name and email from Google.',
        'Operator details: company name, franchise number and contact number, plus the vehicles, routes and drivers you register, including driver license images.',
        'Location: vehicle GPS positions while a vehicle is on duty. A commuter\'s location is used only when they allow it, for example to find nearby stops or plan a trip.',
        'Activity: trips, saved routes, ride reviews, feedback and notification settings.',
      ],
    ),
    (
      'How we use it',
      [
        'To run the service: show live vehicles, plan trips, estimate fares and send alerts you have turned on.',
        'To verify operators and keep accounts secure, including sign-in codes when two-factor authentication is on.',
        'To process subscription payments and to improve SmartCommute.',
      ],
    ),
    (
      'Who we share it with',
      [
        'Operators see reviews and feedback about their own routes and drivers. Commuters stay anonymous to operators.',
        'Service providers that help run SmartCommute, such as Google (sign-in), PayPal (payments) and our hosting provider, only as needed to provide their service.',
        'Government authorities, only when the law requires it.',
        'We do not sell your personal data.',
      ],
    ),
    (
      'How long we keep it',
      [
        'We keep your data while your account is active. When an account is closed we delete or anonymise its personal data, except what we must keep by law.',
      ],
    ),
    (
      'Security',
      [
        'We protect your data with encrypted connections, hashed passwords and access controls. No system is perfectly secure, so please keep your password private.',
      ],
    ),
    (
      'Your rights',
      [
        'Under the Data Privacy Act you may ask to see, correct or delete your personal data, and object to how it is used. You can also file a complaint with the National Privacy Commission.',
        'To make a request, contact us through Help & Support in the app.',
      ],
    ),
    (
      'Changes',
      [
        'We may update this policy. If the changes are significant we will let you know in the app.',
      ],
    ),
  ],
);
