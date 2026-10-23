// js/operator/views/subscription.js
//
// Subscription popup, opened from the header's Subscription button: the
// operator's plan (3-month free trial on first sign-in, then PHP 1,000 /
// year), with checkout through PayPal.
//
// PayPal round trip: "Pay with PayPal" -> POST /subscriptions/checkout with
// this page as return_url -> PayPal's approval page -> back here with
// ?paypal=return&token=<order id> -> POST /subscriptions/paypal/capture,
// which takes the payment and adds a year. ?paypal=cancel means they backed out.
// operatorApp.js reopens this popup on the way back from PayPal.

const OperatorSubscription = {
  open() {
    const esc = AdminUi.escapeHtml;
    let status = null;
    let busy = false;

    const el = AdminModal.open({
      title: 'Subscription',
      size: 'wide',
      body: `
        <p class="modal-text">Unlimited vehicles while your trial or yearly plan is active.</p>
        <div id="sub-notice"></div>
        <section id="sub-card"></section>`,
    });

    const cardEl = el.querySelector('#sub-card');
    const noticeEl = el.querySelector('#sub-notice');

    const peso = (centavos) =>
      `₱${(centavos / 100).toLocaleString('en-PH', { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;

    // Backend datetimes are UTC without an offset ("2026-10-12T08:00:00").
    const parseUtc = (iso) => (iso ? new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(iso) ? iso : `${iso}Z`) : null);

    const daysLeft = (iso) => {
      const end = parseUtc(iso);
      if (!end) return null;
      return Math.max(0, Math.ceil((end - Date.now()) / 86400000));
    };

    const STATE = {
      trial: { label: 'Free Trial', tone: 'blue' },
      active: { label: 'Active', tone: 'green' },
      grace: { label: 'Grace Period', tone: 'amber' },
      free: { label: 'Free Plan', tone: '' },
    };

    function notice(text, tone) {
      noticeEl.innerHTML = text
        ? `<div class="op-card" style="border-left:4px solid var(--op-${tone || 'blue'});margin-bottom:16px;">
             <p class="modal-text" style="margin:0;">${esc(text)}</p>
           </div>`
        : '';
    }

    function row(label, value) {
      return `<div class="op-detail-row"><span>${esc(label)}</span><strong>${value}</strong></div>`;
    }

    function render() {
      const s = status;
      const meta = STATE[s.state] || { label: s.state, tone: '' };
      const price = `${peso(s.plan_price)} / year`;
      const months = Math.round(s.trial_days / 30);

      // Coverage, step by step: free trial, then each paid year stacked
      // after it — so "Jan 2028" is clearly 3 free months + 1 paid year.
      let coverage = '';
      const trialLeft = daysLeft(s.trial_ends_at);
      if (s.trial_ends_at && trialLeft > 0) {
        coverage += row('Free trial', `until ${esc(AdminUi.formatDate(s.trial_ends_at))} (${trialLeft} day${trialLeft === 1 ? '' : 's'} left)`);
      }
      if (s.paid_until) {
        const paidStart = parseUtc(s.paid_until);
        const years = Math.max(1, Math.round((paidStart - Math.max(Date.now(), parseUtc(s.trial_ends_at) || 0)) / (365 * 86400000)));
        coverage += row(s.state === 'grace' || s.state === 'free' ? 'Last paid until' : `Paid (${years} year${years === 1 ? '' : 's'})`,
          `until ${esc(AdminUi.formatDate(s.paid_until))}`);
      }
      const coveredUntil = [s.paid_until, s.trial_ends_at].map(parseUtc).filter(Boolean).sort((a, b) => b - a)[0];
      if (coveredUntil && coveredUntil > Date.now() && s.paid_until) {
        const total = daysLeft(coveredUntil.toISOString());
        // Nearest month: the 90-day trial is a couple of days short of 3 calendar months.
        const months = Math.round(total / 30.44);
        const y = Math.floor(months / 12), m = months % 12;
        const span = [y && `${y} year${y > 1 ? 's' : ''}`, m && `${m} month${m > 1 ? 's' : ''}`].filter(Boolean).join(' ') || `${total} days`;
        coverage += row('Total coverage', `<span style="color:var(--op-green)">about ${esc(span)} · until ${esc(AdminUi.formatDate(coveredUntil.toISOString()))}</span>`);
      }
      if (s.state === 'grace') {
        coverage += row('Renew before', esc(AdminUi.formatDate(s.grace_ends_at)));
      }

      const vehicles = s.vehicle_limit == null
        ? `${s.vehicle_count} · unlimited`
        : `${s.vehicle_count} of ${s.vehicle_limit}`;

      const canPay = s.payment_provider === 'paypal' || s.payment_provider === 'mock';
      const payLabel = s.state === 'active' || s.state === 'trial'
        ? `Add another year · ${peso(s.plan_price)}`
        : `Subscribe · ${peso(s.plan_price)} / year`;

      cardEl.innerHTML = `
        <div class="op-page-head" style="margin-bottom:8px;">
          <div><h3 style="margin:0;">Smart Commute Operator Plan</h3>
          <p class="op-card__sub" style="margin:4px 0 0;">${esc(price)} · first ${months} months free</p></div>
          ${OperatorUi.chip(meta.label, meta.tone)}
        </div>
        ${coverage}
        ${row('Vehicles', esc(vehicles))}
        <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:16px;">
          ${s.trial_available ? `<button type="button" class="op-btn" id="sub-trial">Start ${months}-month free trial</button>` : ''}
          <button type="button" class="op-btn" id="sub-pay" ${canPay ? '' : 'disabled'}>
            ${s.payment_provider === 'paypal' ? 'Pay with PayPal — ' : ''}${esc(payLabel)}
          </button>
        </div>
        <p class="op-card__sub" style="margin-top:12px;">
          ${s.state === 'active' || s.state === 'trial'
            ? 'Paying now adds a full year after your current coverage ends — you never lose days.'
            : `Without a plan you can run up to ${esc(String(s.vehicle_limit ?? ''))} vehicles.`}
          ${s.payment_provider === 'paypal' ? ' You will be taken to PayPal to pay securely.' : ''}
          ${canPay ? '' : ' Online payment is not set up yet.'}
        </p>`;

      el.querySelector('#sub-pay')?.addEventListener('click', pay);
      el.querySelector('#sub-trial')?.addEventListener('click', startTrial);
    }

    async function load() {
      AdminUi.loadInto(cardEl, OperatorApi.subscription, (s) => {
        status = s;
        render();
      });
    }

    async function startTrial() {
      if (busy) return;
      busy = true;
      try {
        status = await OperatorApi.startTrial();
        notice(`Your ${Math.round(status.trial_days / 30)}-month free trial has started. Enjoy unlimited vehicles!`, 'green');
        render();
      } catch (err) {
        notice(err.message, 'red');
      } finally {
        busy = false;
      }
    }

    async function pay() {
      if (busy) return;
      busy = true;
      const btn = el.querySelector('#sub-pay');
      btn.disabled = true;
      btn.textContent = 'Opening checkout…';
      // Come back to this exact address, so the login saved in this browser
      // origin (localhost vs 127.0.0.1) is still there after PayPal.
      const here = `${location.origin}${location.pathname}`;
      try {
        const checkout = await OperatorApi.checkout({
          return_url: `${here}?paypal=return`,
          cancel_url: `${here}?paypal=cancel`,
        });
        if (status.payment_provider === 'mock') {
          // Development stand-in: "pays" instantly through the backend.
          status = await OperatorApi.mockPay(checkout.checkout_url);
          notice('Test payment recorded (mock provider). Your plan is active.', 'green');
          render();
        } else {
          window.location.assign(checkout.checkout_url);   // off to PayPal
          return;
        }
      } catch (err) {
        notice(err.message, 'red');
        render();
      } finally {
        busy = false;
      }
    }

    /** Back from PayPal? Finish (or note the cancel), then tidy the address bar. */
    async function handleReturn() {
      const params = new URLSearchParams(location.search);
      const result = params.get('paypal');
      if (!result) return false;
      history.replaceState(null, '', `${location.pathname}${location.hash}`);

      if (result === 'cancel') {
        notice('Payment cancelled — you have not been charged.', 'amber');
        return false;
      }
      const orderId = params.get('token');
      if (!orderId) return false;

      cardEl.innerHTML = '<p class="modal-text">Confirming your PayPal payment…</p>';
      try {
        status = await OperatorApi.capturePayPal(orderId);
        notice(`Payment received — thank you! Your plan is active until ${AdminUi.formatDate(status.paid_until)}.`, 'green');
        render();
        return true;
      } catch (err) {
        notice(err.message, 'red');
        return false;
      }
    }

    handleReturn().then((done) => {
      if (!done) load();
    });
  },
};
