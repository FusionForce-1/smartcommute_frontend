// js/legal.js
//
// User Agreement + Privacy Policy: the text, the popup that shows it, and
// the "I confirm that I have read..." checkbox used on both registration
// forms. The popup has its own layer so it can open on top of the Google
// "Complete your Profile" popup without replacing it.
//
// This is the OPERATOR version (the web portal only registers operators).
// The commuter version lives in lib/constants/legal_text.dart (mobile app);
// shared sections (account, acceptable use, rights...) should stay alike.

const LEGAL_DOCS = {
  userAgreement: {
    title: 'User Agreement',
    updated: 'October 2026',
    intro: 'This agreement covers your use of SmartCommute as a public utility vehicle (PUV) operator: the operator portal where you manage your routes, vehicles, drivers and announcements for commuters in Cebu City. By creating an operator account you agree to these terms.',
    sections: [
      ['Your account', [
        'Give accurate information when you register, including your real company name, franchise number and contact number, and keep it up to date.',
        'Keep your password private. You are responsible for what happens under your account, including actions by anyone you share it with.',
        'New operator accounts are reviewed by a SmartCommute administrator. Fleet, route and announcement tools unlock once your account is verified.',
      ]],
      ['Your franchise, fleet and drivers', [
        'You must hold a valid LTFRB franchise for the routes you operate.',
        'You are responsible for the vehicles, drivers, routes, fares and announcements you add, and for keeping them accurate. Commuters rely on them to plan their trips.',
        'Only add drivers who work for you, with their permission. You are responsible for handing them their app login and for how they use it.',
        'Keep GPS trackers on your vehicles working and assigned to the right vehicle, so commuters see where your PUVs really are.',
      ]],
      ['Subscription', [
        'Your first 3 months are free. After that the plan is ₱1,000 a year, paid through PayPal, for unlimited vehicles.',
        'Without an active plan, the number of vehicles you can run is limited, and vehicles over the limit are hidden from commuters until you renew.',
      ]],
      ['Acceptable use', [
        'Do not misuse the service: no fake accounts, false alerts or announcements, spam, or attempts to break into, overload or copy the system.',
        'Do not use SmartCommute for anything unlawful.',
      ]],
      ['Suspension and closing accounts', [
        'We may suspend or close an account that breaks this agreement or puts commuters at risk. You can stop using SmartCommute at any time.',
      ]],
      ['No guarantees', [
        'SmartCommute is provided "as is". We work to keep it accurate and available, but we cannot promise it will always be error-free or online, and we are not liable for losses from relying on it.',
      ]],
      ['Changes', [
        'We may update this agreement. If the changes are significant we will let you know in the portal. Continuing to use SmartCommute after an update means you accept it.',
      ]],
    ],
  },

  privacyPolicy: {
    title: 'Privacy Policy',
    updated: 'October 2026',
    intro: 'SmartCommute respects your privacy and handles personal data in line with the Data Privacy Act of 2012 (Republic Act No. 10173). This policy explains what we collect from operators and why.',
    sections: [
      ['What we collect', [
        'Account details: your name, email address, and password (stored encrypted, never in plain text). If you sign in with Google, we receive your name and email from Google.',
        'Company details: company name, franchise number and contact number.',
        'Your fleet: the vehicles, routes, stops and announcements you add, the daily remittances you record, and your drivers\' details, including the driver license images you scan.',
        'Vehicle location: GPS positions from your vehicles\' trackers while they are on duty.',
        'Payments: your subscription plan and payment records. Card and account details are handled by PayPal, not stored by us.',
      ]],
      ['How we use it', [
        'To run the operator portal and show your routes, live vehicles and announcements to commuters.',
        'To verify operator accounts and keep them secure, including sign-in codes when two-factor authentication is on.',
        'To process your subscription and to improve SmartCommute.',
      ]],
      ['Who we share it with', [
        'Commuters see your company name, routes, fares, vehicle positions and announcements. They do not see your contact details or your drivers\' license details.',
        'You see ratings and feedback commuters give your drivers and routes. Commuters stay anonymous to you.',
        'Service providers that help run SmartCommute, such as Google (sign-in), PayPal (payments) and our hosting provider, only as needed to provide their service.',
        'Government authorities, only when the law requires it.',
        'We do not sell your personal data.',
      ]],
      ['How long we keep it', [
        'We keep your data while your account is active. When an account is closed we delete or anonymise its personal data, except what we must keep by law, such as payment records.',
      ]],
      ['Security', [
        'We protect your data with encrypted connections, hashed passwords and access controls. No system is perfectly secure, so please keep your password private.',
      ]],
      ['Your rights', [
        'Under the Data Privacy Act you may ask to see, correct or delete your personal data, and object to how it is used. You can also file a complaint with the National Privacy Commission.',
        'To make a request, contact the SmartCommute team.',
      ]],
      ['Changes', [
        'We may update this policy. If the changes are significant we will let you know in the portal.',
      ]],
    ],
  },
};

const LegalPopup = (() => {
  let backdropEl = null;

  function onKeydown(e) {
    if (e.key === 'Escape') close();
  }

  function render({ title, updated, intro, sections }) {
    return `
      <button type="button" class="modal-close" data-legal-close aria-label="Close">
        ${Components.icon('close')}
      </button>
      <h1 class="auth-card__title legal-doc__title" id="legal-title">${escapeHtml(title)}</h1>
      <p class="legal-doc__updated">Last updated ${escapeHtml(updated)}</p>
      <div class="legal-doc__body">
        <p>${escapeHtml(intro)}</p>
        ${sections.map(([heading, points]) => `
          <h2>${escapeHtml(heading)}</h2>
          <ul>${points.map((p) => `<li>${escapeHtml(p)}</li>`).join('')}</ul>`).join('')}
      </div>
      ${Components.button({ id: 'legal-done', label: 'Close', variant: 'primary', type: 'button' })}`;
  }

  /** @param {'userAgreement'|'privacyPolicy'} key */
  function open(key) {
    close();
    backdropEl = document.createElement('div');
    backdropEl.className = 'modal-backdrop modal-backdrop--legal';
    backdropEl.innerHTML = `
      <div class="modal-shell auth-card legal-doc" tabindex="-1" role="dialog" aria-modal="true" aria-labelledby="legal-title">
        ${render(LEGAL_DOCS[key])}
      </div>`;
    document.body.appendChild(backdropEl);
    document.addEventListener('keydown', onKeydown);

    backdropEl.addEventListener('click', (e) => {
      if (e.target === backdropEl || e.target.closest('[data-legal-close], #legal-done')) close();
    });
    // Focus the dialog (for Escape / screen readers) without scrolling it
    // down to a button — readers should start at the top.
    backdropEl.querySelector('.legal-doc').focus({ preventScroll: true });
  }

  function close() {
    if (!backdropEl) return;
    backdropEl.remove();
    backdropEl = null;
    document.removeEventListener('keydown', onKeydown);
  }

  return { open, close };
})();

const Consent = {
  /** The "I confirm that I have read..." checkbox, as on the registration mockups. */
  checkbox(id) {
    return `
      <div class="consent-row">
        <input type="checkbox" id="${id}" />
        <label for="${id}">
          I confirm that I have read, consent and agree to SmartCommute's
          <button type="button" class="consent-link" data-legal="userAgreement">User Agreement</button>
          and
          <button type="button" class="consent-link" data-legal="privacyPolicy">Privacy Policy</button>
        </label>
      </div>`;
  },

  /** Opens the matching document when a link inside `root` is clicked. */
  wire(root) {
    root.addEventListener('click', (e) => {
      const link = e.target.closest('[data-legal]');
      if (!link) return;
      e.preventDefault(); // don't toggle the checkbox the link sits in
      LegalPopup.open(link.dataset.legal);
    });
  },

  MESSAGE: 'Please confirm that you agree to the User Agreement and Privacy Policy.',
};
