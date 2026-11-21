// Portal rules tests
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const portal = path.join(__dirname, '..', '..', 'web_portal');

// Load portal script
function load(file, context) {
  vm.createContext(context);
  vm.runInContext(`${fs.readFileSync(path.join(portal, file), 'utf8')}\nthis.__exports = typeof PasswordRule !== 'undefined' ? PasswordRule : (typeof IdleTimeout !== 'undefined' ? IdleTimeout : null);`, context);
  return context.__exports;
}

let failures = 0;
// Run one check
function check(name, fn) {
  return Promise.resolve().then(fn).then(
    () => console.log(`ok - ${name}`),
    (err) => { failures += 1; console.log(`not ok - ${name}\n  ${err.message}`); },
  );
}

(async () => {
  const rule = load('js/passwordRule.js', { TextEncoder });
  await check('password rule matches the server', () => {
    assert.ok(rule.problem('Short1'));
    assert.ok(rule.problem('lettersonly'));
    assert.ok(rule.problem('12345678'));
    assert.ok(rule.problem(`a1${'x'.repeat(71)}`));
    assert.strictEqual(rule.problem('Commute2026'), '');
  });

  const storage = (remember) => ({ getItem: (k) => (remember && k === 'smartcommute.session' ? '{}' : null) });
  const fakeWindow = { addEventListener() {}, removeEventListener() {} };
  const body = { appended: [], appendChild(el) { this.appended.push(el); } };
  const fakeDocument = {
    body,
    createElement() {
      const el = {
        style: {}, setAttribute() {}, remove() { el.removed = true; },
        set innerHTML(v) { el._html = v; },
        querySelector(sel) { return sel === '[data-idle-stay]' ? { addEventListener() {} } : { textContent: '' }; },
      };
      return el;
    },
  };

  await check('remembered sign-ins are never timed out', () => {
    const idle = load('js/services/idleTimeout.js', {
      localStorage: storage(true), window: fakeWindow, document: fakeDocument, setInterval, clearInterval,
    });
    assert.strictEqual(idle.start(() => {}), false);
  });

  await check('a session without Remember me warns at 29 min and signs out at 30 min', async () => {
    let expired = 0;
    body.appended = [];
    const idle = load('js/services/idleTimeout.js', {
      localStorage: storage(false), window: fakeWindow, document: fakeDocument,
      setInterval: () => 1, clearInterval: () => {},
    });
    assert.strictEqual(idle.start(() => { expired += 1; }), true);
    idle._idleFor(idle.IDLE_MS - idle.WARN_MS + 1000);
    await idle._tick();
    assert.strictEqual(body.appended.length, 1, 'warning shown');
    assert.strictEqual(expired, 0);
    idle._idleFor(idle.IDLE_MS + 1);
    await idle._tick();
    assert.strictEqual(expired, 1);
  });

  await check('route form no longer sends a typed fare', () => {
    const api = fs.readFileSync(path.join(portal, 'js/operator/operatorApi.js'), 'utf8');
    assert.ok(!/fare_matrix/.test(api));
    assert.ok(!/USE_MOCKS|mockDispatch/.test(fs.readFileSync(path.join(portal, 'js/services/authModule.js'), 'utf8')));
  });

  // CSP directive map
  const directives = (policy) => Object.fromEntries(policy.split(';').map((d) => d.trim()).filter(Boolean)
    .map((d) => { const [name, ...values] = d.split(/\s+/); return [name, values]; }));
  const headerPolicy = directives(JSON.parse(fs.readFileSync(path.join(portal, 'vercel.json'), 'utf8'))
    .headers[0].headers.find((h) => h.key === 'Content-Security-Policy').value);
  const pages = ['index.html', 'admin/admin.html', 'operator/operator.html'];
  const metaPolicies = pages.map((page) => directives(fs.readFileSync(path.join(portal, page), 'utf8')
    .match(/http-equiv="Content-Security-Policy" content="([^"]+)"/)[1]));
  const CDN_HOSTS = ['https://unpkg.com', 'https://cdnjs.cloudflare.com'];

  await check('deployed CSP never allows localhost', () => {
    assert.ok(!headerPolicy['connect-src'].some((src) => /localhost|127\.0\.0\.1/.test(src)), headerPolicy['connect-src'].join(' '));
  });

  await check('CSP pins CDN scripts to exact library paths', () => {
    for (const policy of [headerPolicy, ...metaPolicies]) {
      const scripts = policy['script-src'];
      for (const host of CDN_HOSTS) assert.ok(!scripts.includes(host) && !scripts.includes(`${host}/`), `bare ${host} in script-src`);
      for (const src of scripts.filter((s) => CDN_HOSTS.some((h) => s.startsWith(h)))) {
        assert.ok(/@\d+\.\d+\.\d+\/$|\/\d+\.\d+\.\d+\/$/.test(src), `unversioned script path ${src}`);
      }
    }
  });

  await check('every CDN script the portal loads is allowed by its CSP', () => {
    const code = [...pages, 'js/operator/trackerSetup.js'].map((f) => fs.readFileSync(path.join(portal, f), 'utf8')).join('\n');
    const used = [...code.matchAll(/https:\/\/(?:unpkg\.com|cdnjs\.cloudflare\.com)\/[^'"`\s?]+\.js/g)].map((m) => m[0]);
    assert.ok(used.length >= 3, used.join(' '));
    for (const policy of [headerPolicy, ...metaPolicies]) {
      for (const url of used) assert.ok(policy['script-src'].some((src) => url.startsWith(src)), `${url} blocked`);
    }
  });

  // Load operator UI helpers
  function loadOperatorUi() {
    const context = { AdminUi: { escapeHtml: (v) => String(v).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`) } };
    vm.createContext(context);
    vm.runInContext(`${fs.readFileSync(path.join(portal, 'js/operator/operatorUi.js'), 'utf8')}\nthis.__ui = OperatorUi;`, context);
    return context.__ui;
  }

  await check('fleet map shows the driver away and off-route chips', () => {
    const ui = loadOperatorUi();
    const both = ui.flagChips({ driver_away: true, off_route: true });
    assert.ok(both.includes('Driver away from PUV'), both);
    assert.ok(both.includes('Off route'), both);
    assert.ok(both.includes('amber'), both);
    assert.strictEqual(ui.flagChips({ driver_away: false, off_route: false }), '');
    assert.strictEqual(ui.FLAG_TEXT.off_route, 'Off route (more than 150 m from its route)');
    const map = fs.readFileSync(path.join(portal, 'js/operator/views/fleetMap.js'), 'utf8');
    assert.ok(/msg\.off_route/.test(map), 'live frames update off_route');
    assert.ok(/flagChips\(v\)/.test(map) && /FLAG_TEXT\.off_route/.test(map), 'popup shows both');
    assert.ok(/flagChips\(v\)/.test(fs.readFileSync(path.join(portal, 'js/operator/views/vehicles.js'), 'utf8')), 'vehicle list');
  });

  await check('driver activity shows away and off-route times', () => {
    const src = fs.readFileSync(path.join(portal, 'js/operator/driverActivity.js'), 'utf8');
    assert.ok(/driver_away: 'Away'/.test(src) && /off_route: 'Off route'/.test(src));
    assert.ok(/e\.until \? clock\(e\.until\) : 'now'/.test(src));
  });

  if (failures) process.exit(1);
})();
