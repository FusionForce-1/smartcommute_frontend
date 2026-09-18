// js/components.js
//
// Reusable, param-only UI builders for Login / Operator Register /
// Forgot Password / Verify OTP. Icons resolve through js/constants/icons.js.

const LucideSvg = {
  mail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m2 6 10 7 10-7"/></svg>',
  'mail-check': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M22 13V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h8"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/><path d="m16 19 2 2 4-4"/></svg>',
  'key-round': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M2 18v3c0 .6.4 1 1 1h4v-3h3v-3h2l1.3-1.3a6.5 6.5 0 1 0-4-4Z"/><circle cx="16.5" cy="7.5" r=".5" fill="currentColor"/></svg>',
  eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7Z"/><circle cx="12" cy="12" r="3"/></svg>',
  'eye-off': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M17.94 17.94A10.94 10.94 0 0 1 12 20c-7 0-11-8-11-8a19.4 19.4 0 0 1 4.22-5.44M9.9 4.24A10.6 10.6 0 0 1 12 4c7 0 11 8 11 8a19.5 19.5 0 0 1-2.4 3.6M14.12 14.12a3 3 0 1 1-4.24-4.24"/><path d="M1 1l22 22"/></svg>',
  'chevron-left': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg>',
  x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6 6 18M6 6l12 12"/></svg>',
  'alert-circle': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="10"/><path d="M12 8v5M12 16h.01"/></svg>',
  square: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="3" width="18" height="18" rx="2"/></svg>',
  'check-square': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
};

function iconMarkup(iconKey, className = '') {
  const name = ICONS[iconKey] || iconKey;
  const svg = LucideSvg[name] || LucideSvg.mail;
  return `<span class="sc-icon ${className}" data-lucide="${name}">${svg}</span>`;
}

const Components = {
  icon: iconMarkup,

  field({ id, label, type = 'text', placeholder = '', withToggle = false, value = '' }) {
    return `
      <div class="field-group">
        <label class="field-group__label" for="${id}">${label}</label>
        <div class="field-group__input-wrap">
          <input
            class="field-input${withToggle ? ' field-input--with-toggle' : ''}"
            id="${id}"
            name="${id}"
            type="${type}"
            placeholder="${placeholder}"
            value="${value}"
            autocomplete="off"
          />
          ${withToggle ? `
            <button type="button" class="field-toggle" data-toggle-for="${id}" aria-label="Show password">
              ${iconMarkup('passwordVisible')}
            </button>` : ''}
        </div>
      </div>`;
  },

  button({ id, label, variant = 'primary', type = 'button' }) {
    const classMap = { primary: 'btn-primary', outline: 'btn-outline', google: 'btn-google' };
    const icon = variant === 'google'
      ? `<img class="google-g" src="${GOOGLE_LOGO_SRC}" alt="" width="20" height="20" />`
      : '';
    return `
      <button id="${id}" type="${type}" class="btn ${classMap[variant] || 'btn-primary'}">
        ${icon}<span>${label}</span>
      </button>`;
  },

  orDivider(label = 'or') {
    return `<div class="or-divider">${label}</div>`;
  },

  errorBanner({ id, message }) {
    return `
      <div id="${id}" class="error-banner" hidden>
        ${iconMarkup('toastError')}<span>${message}</span>
      </div>`;
  },

  bottomLinkRow({ prompt, linkText, href, id }) {
    const extra = id ? ` id="${id}"` : '';
    return `<p class="bottom-link-row">${prompt} <a href="${href}"${extra}>${linkText}</a></p>`;
  },

  popupIcon(iconKey) {
    return `<div class="popup-icon">${iconMarkup(iconKey)}</div>`;
  },

  brandHeader({ tagline = 'Cebu City Transit Information' } = {}) {
    return `
      <header class="brand-header">
        <div class="brand-header__lockup">
          <img class="brand-header__logo" src="assets/images/smart-commute-logo-landscape.png" alt="Smart Commute" />
        </div>
        <span class="brand-header__tagline">${tagline}</span>
      </header>`;
  },
};