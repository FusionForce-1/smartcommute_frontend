// lib/constants/legal_text.dart
//
// User Agreement + Privacy Policy shown from the register screen's consent
// checkbox and Profile → Account. This is the COMMUTER version (the app
// only registers commuters). The operator version lives in the web portal's
// web_portal/js/legal.js; shared sections (account, acceptable use,
// rights...) should stay alike.

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
      'This agreement covers your use of the SmartCommute app, a transit information service '
      'that helps commuters in Cebu City find jeepney routes, fares and live vehicle locations. '
      'By creating an account you agree to these terms.',
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
      'Using SmartCommute',
      [
        'Routes, stops, fares and arrival estimates are for information only. Vehicles can be '
            'delayed, rerouted or off duty, so plan with some allowance.',
        'Official fares are set by the LTFRB. Fare estimates in the app may differ from what you pay.',
        'Stay safe: watch the road, not your phone, when walking to a stop or boarding a jeep.',
      ],
    ),
    (
      'Reviews and feedback',
      [
        'Ride reviews and feedback must be honest and respectful.',
        'Do not post false reports, insults or personal information about drivers or other commuters.',
        'We may remove reviews that break these rules.',
      ],
    ),
    (
      'Acceptable use',
      [
        'Do not misuse the service: no fake accounts, false reports, spam, harassment, or attempts '
            'to break into, overload or copy the system.',
        'Do not use SmartCommute for anything unlawful.',
      ],
    ),
    (
      'Suspension and closing accounts',
      [
        'We may suspend or close an account that breaks this agreement or puts other users at '
            'risk. You can stop using SmartCommute at any time.',
      ],
    ),
    (
      'No guarantees',
      [
        'SmartCommute is provided "as is". We work to keep it accurate and available, but we '
            'cannot promise it will always be error-free or online, and we are not liable for '
            'missed trips or losses from relying on it.',
      ],
    ),
    (
      'Changes',
      [
        'We may update this agreement. If the changes are significant we will let you know in the '
            'app. Continuing to use SmartCommute after an update means you accept it.',
      ],
    ),
  ],
);

const LegalDoc privacyPolicy = LegalDoc(
  title: 'Privacy Policy',
  updated: 'October 2026',
  intro:
      'SmartCommute respects your privacy and handles personal data in line with the Data Privacy '
      'Act of 2012 (Republic Act No. 10173). This policy explains what we collect from commuters '
      'and why.',
  sections: [
    (
      'What we collect',
      [
        'Account details: your name, email address, and password (stored encrypted, never in plain '
            'text). If you sign in with Google, we receive your name and email from Google.',
        'Location: only when you allow it, for example to show nearby stops and jeeps or to plan a '
            'trip from where you are.',
        'Activity: the trips you plan, your saved routes, ride reviews, feedback and notification '
            'settings.',
      ],
    ),
    (
      'How we use it',
      [
        'To run the app: show live jeeps, plan trips, estimate fares and send the alerts you have '
            'turned on.',
        'To keep your account secure, including sign-in codes when two-factor authentication is on.',
        'To improve SmartCommute.',
      ],
    ),
    (
      'Who we share it with',
      [
        'Operators see the reviews and feedback you give about their routes and drivers, but not '
            'your name or email.',
        'Service providers that help run SmartCommute, such as Google (sign-in) and our hosting '
            'provider, only as needed to provide their service.',
        'Government authorities, only when the law requires it.',
        'We do not sell your personal data.',
      ],
    ),
    (
      'How long we keep it',
      [
        'We keep your data while your account is active. When an account is closed we delete or '
            'anonymise its personal data, except what we must keep by law.',
      ],
    ),
    (
      'Security',
      [
        'We protect your data with encrypted connections, hashed passwords and access controls. No '
            'system is perfectly secure, so please keep your password private.',
      ],
    ),
    (
      'Your rights',
      [
        'Under the Data Privacy Act you may ask to see, correct or delete your personal data, and '
            'object to how it is used. You can also file a complaint with the National Privacy '
            'Commission.',
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
