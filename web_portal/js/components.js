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
  'layout-grid': '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="3" y="3" width="8" height="8" rx="1.5"/><rect x="13" y="3" width="8" height="5" rx="1.5"/><rect x="13" y="10" width="8" height="11" rx="1.5"/><rect x="3" y="13" width="8" height="8" rx="1.5"/></svg>',
  users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
  'circle-check': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="12" r="10"/><path d="m8 12 3 3 5-6"/></svg>',
  bell: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a6 6 0 0 0-6 6v4.2L4.3 15.6A1 1 0 0 0 5.2 17h13.6a1 1 0 0 0 .9-1.4L18 12.2V8a6 6 0 0 0-6-6Z"/><path d="M9.5 19a2.5 2.5 0 0 0 5 0Z"/></svg>',
  'file-text': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6M8 13h8M8 17h8M8 9h2"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg>',
  'log-out': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>',
  'circle-help': '<svg viewBox="0 0 24 24" fill="currentColor"><path fill-rule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm-.1 5.2c-1.7 0-2.9 1-3.1 2.5h1.9c.1-.6.6-.9 1.2-.9.7 0 1.1.4 1.1 1 0 .5-.2.8-.9 1.2-.9.5-1.3 1.1-1.2 2.1v.5h1.8v-.4c0-.6.2-.8.9-1.2.8-.5 1.4-1.1 1.4-2.2 0-1.6-1.3-2.6-3.1-2.6ZM12 15.3a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4Z"/></svg>',
  'check-square': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
  map: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M14.1 5.55a2 2 0 0 0 1.8 0l3.65-1.83A1 1 0 0 1 21 4.62v12.76a1 1 0 0 1-.55.9l-4.55 2.27a2 2 0 0 1-1.8 0l-4.2-2.1a2 2 0 0 0-1.8 0l-3.65 1.83A1 1 0 0 1 3 19.38V6.62a1 1 0 0 1 .55-.9L8.1 3.45a2 2 0 0 1 1.8 0Z"/><path d="M15 5.76v15M9 3.24v15"/></svg>',
  route: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="6" cy="19" r="3"/><path d="M9 19h8.5a3.5 3.5 0 0 0 0-7h-11a3.5 3.5 0 0 1 0-7H15"/><circle cx="18" cy="5" r="3"/></svg>',
  bus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M8 6v6M15 6v6M2 12h19.6"/><path d="M18 18h3s.5-1.7.8-2.8c.1-.4.2-.8.2-1.2s-.1-.8-.2-1.2l-1.4-5C20.1 6.8 19.1 6 18 6H4a2 2 0 0 0-2 2v10h3"/><circle cx="7" cy="18" r="2"/><path d="M9 18h5"/><circle cx="16" cy="18" r="2"/></svg>',
  'id-card': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="2" y="5" width="20" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M6.17 15a3 3 0 0 1 5.66 0M16 10h2M16 14h2"/></svg>',
  megaphone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="m3 11 18-5v12L3 14v-3Z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/></svg>',
  'bar-chart-3': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 3v18h18M18 17V9M13 17V5M8 17v-3"/></svg>',
  'user-round': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="8" r="5"/><path d="M20 21a8 8 0 0 0-16 0"/></svg>',
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
        ${iconMarkup('toastError')}<span class="error-banner__text">${message}</span>
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