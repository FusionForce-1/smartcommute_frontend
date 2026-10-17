// js/operator/trackerSetup.js
//
// "Set up GPS tracker" for one vehicle, two ways:
//
//  * USB — the tracker is plugged into this computer. The browser talks to
//    it over the cable (Web Serial: Chrome/Edge on a computer), the portal
//    issues the vehicle's device key and writes WiFi + vehicle + key into
//    the tracker. The operator never sees or types the key.
//
//  * Claim code — the tracker joins the shared setup hotspot and waits; the
//    operator types the code from its sticker, and the server hands the
//    tracker its settings on its next check-in (POST /devices/claim).
//
// Serial protocol (firmware smart_commute_tracker.ino): one JSON object per
// line prefixed "@@"; the tracker answers "@@{...}" amid its normal logs.

const TrackerSetup = (() => {
  const esc = (s) => AdminUi.escapeHtml(String(s ?? ''));
  const SETUP_SSID = 'SmartCommute-Setup';
  const SETUP_PASS = 'smartcommute';
  const MAX_NETWORKS = 3;

  // ---------- WiFi list (shared by both ways) ----------

  function wifiRows(count = 1) {
    return Array.from({ length: count }, (_, i) => wifiRow(i)).join('');
  }

  function wifiRow(i) {
    return `
      <div class="ts-wifi" data-row="${i}" style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:8px;">
        <input class="ts-ssid" list="ts-ssids" maxlength="32" placeholder="WiFi name${i ? ' (optional)' : ''}" autocomplete="off" />
        <input class="ts-pass" type="password" maxlength="63" placeholder="Password" autocomplete="new-password" />
      </div>`;
  }

  function wifiSection() {
    return `
      <div class="form-field">
        <label>WiFi the tracker will use <span style="color:var(--op-muted)">(2.4 GHz, e.g. the jeep's hotspot)</span></label>
        <div id="ts-wifi-list">${wifiRows(1)}</div>
        <datalist id="ts-ssids"></datalist>
        <p class="op-card__sub" style="margin:0 0 8px;">The name must match exactly — capitals, spaces and symbols like "?" count.</p>
        <button type="button" class="btn-sm" id="ts-add-wifi">+ Add a backup network</button>
      </div>`;
  }

  function bindWifi(m) {
    m.querySelector('#ts-add-wifi').addEventListener('click', () => {
      const list = m.querySelector('#ts-wifi-list');
      const n = list.querySelectorAll('.ts-wifi').length;
      if (n < MAX_NETWORKS) list.insertAdjacentHTML('beforeend', wifiRow(n));
      if (n + 1 >= MAX_NETWORKS) m.querySelector('#ts-add-wifi').hidden = true;
    });
  }

  /**
   * The WiFi rows as [{ssid, password}], or throws a readable error. Names
   * are trimmed, except one that exactly matches a scanned network: WiFi
   * names may really start or end with a space.
   */
  function readWifi(m, nearby = []) {
    const nets = [...m.querySelectorAll('.ts-wifi')]
      .map((row) => {
        const raw = row.querySelector('.ts-ssid').value;
        return {
          ssid: nearby.includes(raw) ? raw : raw.trim(),
          password: row.querySelector('.ts-pass').value,
        };
      })
      .filter((n) => n.ssid);
    if (!nets.length) throw new Error('Enter the WiFi name the tracker should connect to.');
    for (const n of nets) {
      if (new TextEncoder().encode(n.ssid).length > 32) throw new Error(`WiFi name "${n.ssid}" is too long (max 32).`);
      if (n.password && (n.password.length < 8 || n.password.length > 63)) {
        throw new Error(`The password for "${n.ssid}" must be 8-63 characters (leave it empty for an open network).`);
      }
    }
    return nets;
  }

  // ---------- Serial link to the tracker (USB) ----------

  // One port per page: reopening a port that is already open throws.
  const link = { port: null, reader: null, writer: null, pipe: null, buffer: '', waiters: [], log: [] };
  let watchingUnplug = false;

  function onLine(line) {
    if (!line.startsWith('@@')) {
      link.log.push(line);
      if (link.log.length > 50) link.log.shift();
      return;
    }
    let msg;
    try { msg = JSON.parse(line.slice(2)); } catch { return; }
    link.waiters = link.waiters.filter((w) => {
      if (w.cmd !== msg.cmd && msg.cmd !== '?') return true;
      w.resolve(msg);
      return false;
    });
  }

  async function readLoop() {
    const decoder = new TextDecoderStream();
    link.pipe = link.port.readable.pipeTo(decoder.writable).catch(() => {});
    link.reader = decoder.readable.getReader();
    try {
      for (;;) {
        const { value, done } = await link.reader.read();
        if (done) break;
        link.buffer += value;
        let nl;
        while ((nl = link.buffer.search(/\r?\n/)) >= 0) {
          const line = link.buffer.slice(0, nl).trim();
          link.buffer = link.buffer.slice(link.buffer[nl] === '\r' ? nl + 2 : nl + 1);
          if (line) onLine(line);
        }
      }
    } catch {
      // Unplugged or closed: callers time out with a clear message.
    }
  }

  async function connect() {
    if (link.port) return;
    // Must run straight from the click: the browser only shows its device
    // picker in response to a user gesture.
    const port = await navigator.serial.requestPort();
    await port.open({ baudRate: 115200 });
    // Release the auto-reset lines so the ESP32 runs instead of sitting in
    // reset / the bootloader (the board ties them to EN and GPIO0).
    try { await port.setSignals({ dataTerminalReady: false, requestToSend: false }); } catch { /* not all adapters */ }
    link.port = port;
    link.writer = port.writable.getWriter();
    readLoop();
    if (!watchingUnplug) {
      watchingUnplug = true;
      navigator.serial.addEventListener('disconnect', (e) => {
        if (e.target === link.port) disconnect();
      });
    }
  }

  async function disconnect() {
    const { port, reader, writer, pipe } = link;
    Object.assign(link, { port: null, reader: null, writer: null, pipe: null, buffer: '' });
    // The port only closes once its streams are unlocked: stop reading, let
    // the pipe finish, release the writer.
    try { await reader?.cancel(); } catch { /* already closed */ }
    await pipe;
    try { writer?.releaseLock(); } catch { /* already released */ }
    try { await port?.close(); } catch { /* already closed */ }
  }

  /**
   * Sends a command and waits for its "@@" reply. It's re-sent every
   * `retryMs`, because the tracker may be rebooting (opening the port can
   * reset it) or busy with a scan.
   */
  async function command(cmd, payload = {}, { timeoutMs = 20000, retryMs = 0 } = {}) {
    if (!link.writer) throw new Error('The tracker is not connected.');
    const line = `@@${JSON.stringify({ cmd, ...payload })}\n`;
    const encoder = new TextEncoder();
    return new Promise((resolve, reject) => {
      let timer;
      let retry;
      const waiter = {
        cmd,
        resolve: (msg) => {
          clearTimeout(timer);
          clearInterval(retry);
          if (msg.ok) resolve(msg);
          else reject(new Error(`Tracker refused: ${msg.error || 'unknown error'}`));
        },
      };
      link.waiters.push(waiter);
      const send = () => link.writer?.write(encoder.encode(line)).catch(() => {});
      send();
      if (retryMs) retry = setInterval(send, retryMs);
      timer = setTimeout(() => {
        clearInterval(retry);
        link.waiters = link.waiters.filter((w) => w !== waiter);
        reject(new Error('The tracker did not answer. Check the cable (it must carry data, not only charge) '
          + 'and that the tracker runs Smart Commute firmware 2.0 or newer — a new or blank tracker needs it '
          + 'installed first: Vehicles → Install tracker firmware.'));
      }, timeoutMs);
    });
  }

  /** Where the tracker should report: the server this portal uses, when it's a public (https) one. */
  function serverForTracker() {
    const url = new URL(API_BASE_URL);
    if (url.protocol !== 'https:') return null;   // local dev backend: the tracker keeps its default
    return { host: url.hostname, port: Number(url.port) || 443, tls: true };
  }

  // ---------- Screens ----------

  function openChooser(vehicle, onDone) {
    const usbOk = 'serial' in navigator;
    AdminModal.open({
      title: `Set up GPS tracker — ${vehicle.plate_number}`,
      body: `
        <p class="modal-text">How is the tracker connected?</p>
        <div style="display:grid;gap:12px;">
          <button type="button" class="op-card" data-way="usb" style="text-align:left;cursor:pointer;" ${usbOk ? '' : 'disabled'}>
            <strong>USB cable to this computer</strong>
            <p class="op-card__sub" style="margin:4px 0 0;">Plug the tracker in, pick it, enter the WiFi. About a minute.
              ${usbOk ? '' : '<br><span style="color:var(--op-red)">Needs Chrome or Edge on a computer.</span>'}</p>
          </button>
          <button type="button" class="op-card" data-way="code" style="text-align:left;cursor:pointer;">
            <strong>Claim code (no cable)</strong>
            <p class="op-card__sub" style="margin:4px 0 0;">Turn on the setup hotspot, then type the code from the tracker's sticker.</p>
          </button>
        </div>
        <p class="modal-text" style="margin-top:12px;color:var(--op-muted)">Either way replaces any tracker this vehicle had before.</p>`,
      actions: [{ label: 'Cancel', variant: 'ghost', onClick: AdminModal.close }],
    }).querySelectorAll('[data-way]').forEach((btn) => btn.addEventListener('click', () => {
      if (btn.dataset.way === 'usb') openUsb(vehicle, onDone);
      else openClaim(vehicle, onDone);
    }));
  }

  // Lowercase, letters/digits only: "Connect Ka?" and "connect ka" look alike.
  const looseName = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '');

  /** Stops a near-miss typo (e.g. "connect ka" for "connect ka?") before it strands the tracker. */
  function checkAgainstNearby(networks, nearby) {
    for (const n of networks) {
      if (nearby.includes(n.ssid)) continue;
      const near = nearby.find((s) => looseName(s) === looseName(n.ssid));
      if (near) {
        throw new Error(`There's no WiFi named "${n.ssid}" nearby. Did you mean "${near}"? `
          + 'The name must match exactly, including capitals and symbols.');
      }
      // Not nearby at all: fine (e.g. the jeep's hotspot is off right now).
    }
  }

  function openUsb(vehicle, onDone) {
    let info = null;
    let nearby = [];   // WiFi names the tracker can see, from its last scan

    async function scan(modal) {
      const btn = modal.querySelector('#ts-scan');
      btn.disabled = true;
      btn.textContent = 'Scanning nearby WiFi…';
      try {
        const { networks } = await command('scan', {}, { timeoutMs: 15000 });
        nearby = [...new Set(networks.map((n) => n.ssid).filter(Boolean))];
        modal.querySelector('#ts-ssids').innerHTML = nearby.map((n) => `<option value="${esc(n)}"></option>`).join('');
        btn.textContent = `${nearby.length} networks nearby — click the WiFi name box to pick one (scan again)`;
      } catch (err) {
        btn.textContent = `Scan failed: ${err.message} (scan again)`;
      } finally {
        btn.disabled = false;
      }
    }
    const m = AdminModal.open({
      title: `USB setup — ${vehicle.plate_number}`,
      body: `
        <ol class="modal-text" style="padding-left:18px;margin-top:0;">
          <li>Plug the tracker into this computer with a USB <em>data</em> cable.</li>
          <li>Close the Arduino Serial Monitor if it's open (only one program can use the port).</li>
          <li>Click <strong>Connect</strong> and pick the tracker (often "USB-SERIAL CH340" or "CP210x").</li>
        </ol>
        <div id="ts-device" class="modal-text"></div>
        <form novalidate id="ts-form" hidden>
          ${wifiSection()}
          <button type="button" class="btn-sm" id="ts-scan">Scan nearby WiFi</button>
        </form>`,
      actions: [
        { label: 'Back', variant: 'ghost', onClick: () => openChooser(vehicle, onDone) },
        {
          label: 'Connect',
          variant: 'primary',
          onClick: async (modal) => {
            if (!info) {
              await connect();
              modal.querySelector('#ts-device').textContent = 'Connected — waiting for the tracker to answer…';
              info = await command('info', {}, { timeoutMs: 25000, retryMs: 1500 });
              showDevice(modal, info, vehicle);
              modal.querySelector('#ts-form').hidden = false;
              modal.querySelector('.admin-modal__foot [data-index="1"]').textContent = 'Save to tracker';
              modal.querySelector('.ts-ssid').focus();
              await scan(modal);   // fills the name suggestions
              return;
            }
            const networks = readWifi(modal, nearby);
            checkAgainstNearby(networks, nearby);
            const { device_key: key } = await OperatorApi.issueDeviceKey(vehicle.vehicle_id);
            const server = serverForTracker();
            await command('configure', {
              networks, vehicle_id: vehicle.vehicle_id, device_key: key, ...(server ? { server } : {}),
            }, { timeoutMs: 10000 });
            await disconnect();   // it restarts with the new settings
            done(vehicle, networks, onDone, 'saved over USB');
          },
        },
      ],
    });
    bindWifi(m);
    m.querySelector('#ts-scan').addEventListener('click', () => scan(m));
  }

  function showDevice(m, info, vehicle) {
    const current = info.configured
      ? (info.vehicle_id === vehicle.vehicle_id ? 'already set up for this vehicle' : 'currently set up for another vehicle')
      : 'not set up yet';
    m.querySelector('#ts-device').innerHTML = `
      <div class="op-card" style="margin:8px 0 16px;">
        <strong>Tracker ${esc(info.device_id)}</strong> · firmware ${esc(info.firmware)}<br>
        <span class="op-card__sub">Claim code ${esc(info.claim_code)} · ${esc(current)}${
          info.networks?.length ? ` · saved WiFi: ${info.networks.map(esc).join(', ')}` : ''}</span>
        <div style="margin-top:10px;">
          <button type="button" class="btn-sm btn-sm--teal" id="ts-print">Print label for this tracker</button>
        </div>
      </div>`;
    m.querySelector('#ts-print').addEventListener('click', () => printLabel(info));
  }

  // ---------- Label (sticker on the tracker) ----------

  /** Address a phone opens when it scans the label: the portal, with the code filled in. */
  function claimLink(code) {
    return `${location.origin}${location.pathname}?claim=${encodeURIComponent(code.replace(/-/g, ''))}`;
  }

  /**
   * Opens a printable sticker: big claim code, a QR code that opens the
   * portal with the code filled in, and the three steps an operator follows.
   * The QR is drawn in the print window by qrcodejs (no data leaves the browser).
   */
  function printLabel(info) {
    const win = window.open('', '_blank', 'width=480,height=640');
    if (!win) throw new Error('Allow pop-ups for this site to print the label.');
    const link = claimLink(info.claim_code);
    win.document.write(`<!doctype html>
<html><head><meta charset="utf-8"><title>Tracker label ${esc(info.device_id)}</title>
<style>
  @page { size: 70mm 50mm; margin: 3mm; }
  body { font-family: Arial, Helvetica, sans-serif; margin: 0; color: #000; }
  .label { width: 64mm; height: 44mm; border: 0.4mm solid #000; border-radius: 2mm;
           padding: 2.5mm; box-sizing: border-box; display: grid;
           grid-template-columns: 19mm 1fr; gap: 2.5mm; align-items: start; }
  .brand { grid-column: 1 / -1; font-weight: bold; font-size: 2.9mm; letter-spacing: .15mm; white-space: nowrap;
           border-bottom: 0.3mm solid #000; padding-bottom: 1mm; }
  #qr img, #qr canvas { width: 19mm !important; height: 19mm !important; }
  .code { font-family: "Courier New", monospace; font-weight: bold; font-size: 5.6mm; letter-spacing: .6mm; }
  .small { font-size: 2.3mm; line-height: 1.35; }
  .steps { grid-column: 1 / -1; font-size: 2.25mm; line-height: 1.3; margin: 0; padding-left: 3.5mm; }
  .tip { margin: 4mm; font-size: 12px; color: #444; }
  @media print { .tip { display: none; } }
</style></head>
<body>
  <div class="label">
    <div class="brand">SMART COMMUTE · GPS TRACKER</div>
    <div id="qr"></div>
    <div>
      <div class="small">Set-up code</div>
      <div class="code">${esc(info.claim_code)}</div>
      <div class="small">Device ${esc(info.device_id)}</div>
    </div>
    <ol class="steps">
      <li>Hotspot <b>${SETUP_SSID}</b> / <b>${SETUP_PASS}</b></li>
      <li>Turn this tracker on near the phone.</li>
      <li>Scan the QR code to finish set-up.</li>
    </ol>
  </div>
  <p class="tip">Printing on a label printer: choose 70 × 50 mm paper. On normal paper, cut along the border and tape it to the tracker.</p>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"><\/script>
  <script>
    new QRCode(document.getElementById('qr'), { text: ${JSON.stringify(link)}, width: 220, height: 220, correctLevel: QRCode.CorrectLevel.M });
    setTimeout(() => window.print(), 400);
  <\/script>
</body></html>`);
    win.document.close();
  }

  function openClaim(vehicle, onDone, code = '') {
    const m = AdminModal.open({
      title: `Claim code setup — ${vehicle.plate_number}`,
      body: `
        <ol class="modal-text" style="padding-left:18px;margin-top:0;">
          <li>On a phone, turn on a hotspot named <code>${SETUP_SSID}</code> with password <code>${SETUP_PASS}</code>
              (2.4 GHz / "maximize compatibility").</li>
          <li>Switch the tracker on near the phone and wait about 30 seconds.</li>
          <li>Enter the code from the tracker's sticker and the WiFi it should use from now on.</li>
        </ol>
        <form novalidate>
          <div class="form-field">
            <label for="ts-code">Claim code</label>
            <input id="ts-code" maxlength="12" placeholder="ABCD-EFGH" autocomplete="off" value="${esc(code)}"
                   style="text-transform:uppercase;letter-spacing:2px;font-family:monospace;font-size:1.1em;" />
          </div>
          ${wifiSection()}
        </form>
        <div id="ts-progress" class="modal-text"></div>`,
      actions: [
        { label: 'Back', variant: 'ghost', onClick: () => openChooser(vehicle, onDone) },
        {
          label: 'Claim tracker',
          variant: 'primary',
          onClick: async (modal) => {
            const code = modal.querySelector('#ts-code').value.trim();
            if (!code) throw new Error('Enter the claim code from the tracker.');
            const networks = readWifi(modal);
            const claim = await OperatorApi.claimTracker({ claim_code: code, vehicle_id: vehicle.vehicle_id, networks });
            const progress = modal.querySelector('#ts-progress');
            progress.textContent = `Claimed tracker ${claim.device_id}. Waiting for it to pick up its settings…`;
            await waitForDelivery(claim.device_id, progress);
            done(vehicle, networks, onDone, `tracker ${claim.device_id} picked up its settings`);
          },
        },
      ],
    });
    bindWifi(m);
    (code ? m.querySelector('.ts-ssid') : m.querySelector('#ts-code')).focus();
  }

  async function waitForDelivery(deviceId, progressEl) {
    const started = Date.now();
    while (Date.now() - started < 3 * 60 * 1000) {
      await new Promise((r) => setTimeout(r, 3000));
      if (!progressEl.isConnected) return new Promise(() => {});   // dialog closed: stop quietly
      const s = await OperatorApi.trackerSetupStatus(deviceId).catch(() => null);
      if (s?.state === 'delivered') return;
      const secs = Math.round((Date.now() - started) / 1000);
      progressEl.textContent = `Claimed. Waiting for the tracker to check in… (${secs} s — it checks every 15 s)`;
    }
    throw new Error('The tracker has not picked up its settings yet. Make sure it is on and connected to the '
      + `${SETUP_SSID} hotspot; it will still pick them up within the next hour.`);
  }

  function done(vehicle, networks, onDone, how) {
    AdminModal.open({
      title: 'Tracker set up',
      size: 'sm',
      body: `
        <p class="modal-text">✓ ${esc(vehicle.plate_number)}'s tracker is set up (${esc(how)}).</p>
        <p class="modal-text">It restarts, joins <strong>${esc(networks[0].ssid)}</strong>${
          networks.length > 1 ? ` (or ${networks.slice(1).map((n) => esc(n.ssid)).join(', ')})` : ''}
          and starts sending GPS. "Last GPS" updates once it has a satellite fix — outdoors, within a few minutes.</p>`,
      actions: [{ label: 'Done', variant: 'primary', onClick: () => { AdminModal.close(); onDone?.(); } }],
    });
  }

  window.addEventListener('beforeunload', () => { disconnect(); });

  /**
   * Opened from a scanned label (operator.html?claim=CODE): the code is
   * already known, so the operator only picks the jeep and the WiFi.
   */
  async function claimFromLabel(rawCode) {
    const code = String(rawCode).toUpperCase().replace(/[^0-9A-Z]/g, '');
    const shown = code.length === 8 ? `${code.slice(0, 4)}-${code.slice(4)}` : code;
    const fleet = await OperatorApi.fleet().catch(() => []);
    if (!fleet.length) {
      AdminModal.open({
        title: 'Add the jeep first',
        size: 'sm',
        body: `<p class="modal-text">You scanned tracker code <strong>${esc(shown)}</strong>, but you have no vehicles yet.
               Click <strong>+ Add Vehicle</strong>, then use <strong>Set up GPS → Claim code</strong> and type the code.</p>`,
        actions: [{ label: 'OK', variant: 'primary', onClick: AdminModal.close }],
      });
      return;
    }
    if (fleet.length === 1) {
      openClaim(fleet[0], null, shown);
      return;
    }
    const m = AdminModal.open({
      title: 'Which jeep is this tracker for?',
      size: 'sm',
      body: `
        <p class="modal-text">Tracker code <strong>${esc(shown)}</strong></p>
        <div class="form-field">
          <label for="ts-vehicle">Vehicle</label>
          <select id="ts-vehicle">${fleet.map((v) => `<option value="${esc(v.vehicle_id)}">${esc(v.plate_number)}</option>`).join('')}</select>
        </div>`,
      actions: [
        { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
        {
          label: 'Next',
          variant: 'primary',
          onClick: (modal) => {
            const id = modal.querySelector('#ts-vehicle').value;
            openClaim(fleet.find((v) => v.vehicle_id === id), null, shown);
          },
        },
      ],
    });
    m.querySelector('#ts-vehicle').focus();
  }

  // ---------- WiFi of a tracker that's already set up (remote) ----------
  //
  // Lists what the tracker reported, lets the operator keep, re-password,
  // remove or add networks (max 3, min 1) and sends the new list over the
  // tracker's GPS connection. Saved passwords are never shown or needed:
  // an unchanged network goes as {ssid, keep: true}.

  function wifiStatusLine(s) {
    if (s.last_error) return `<div class="op-card" style="border-left:4px solid var(--op-red);margin-bottom:12px;"><p class="modal-text" style="margin:0;">${esc(s.last_error)}</p></div>`;
    if (s.pending) {
      return `<div class="op-card" style="border-left:4px solid var(--op-amber);margin-bottom:12px;"><p class="modal-text" style="margin:0;">
        Waiting for the tracker to take the new list (${s.pending.networks.map(esc).join(', ')})${
          s.online ? '…' : ' — it is offline and gets it as soon as it reconnects.'}</p></div>`;
    }
    return '';
  }

  async function openWifi(vehicle) {
    const s = await OperatorApi.trackerWifi(vehicle.vehicle_id);
    if (!s.supports_remote) {
      AdminModal.open({
        title: `WiFi — ${vehicle.plate_number}`,
        size: 'sm',
        body: `<p class="modal-text">This tracker hasn't reported its WiFi networks yet, so they can't be changed from here.</p>
               <p class="modal-text">It needs Smart Commute firmware <strong>2.1 or newer</strong> and to have been online once.
               Until then, change its WiFi with <strong>Set up GPS → USB</strong>.</p>`,
        actions: [
          { label: 'Close', variant: 'ghost', onClick: AdminModal.close },
          { label: 'Set up over USB', variant: 'primary', onClick: () => openUsb(vehicle, null) },
        ],
      });
      return;
    }

    // One row per network: saved ones start as "keep".
    const rows = s.saved.map((ssid) => ({ ssid, saved: true, removed: false, changePw: false }));

    const m = AdminModal.open({
      title: `WiFi — ${vehicle.plate_number}`,
      body: `
        <p class="modal-text" id="tw-online"></p>
        <div id="tw-status"></div>
        <div id="tw-rows"></div>
        <button type="button" class="btn-sm" id="tw-add">+ Add a network</button>
        <p class="op-card__sub" style="margin-top:12px;">The tracker uses whichever of these is strongest. Up to 3; it keeps at least one.
          If it can't connect to a new network, it goes back to its old ones by itself.</p>
        <div id="tw-fw" style="margin-top:16px;border-top:1px solid var(--op-border, #e5e7eb);padding-top:12px;"></div>`,
      actions: [
        { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
        {
          label: 'Save to tracker',
          variant: 'primary',
          onClick: async (modal) => {
            const networks = collect(modal);
            const after = await OperatorApi.setTrackerWifi(vehicle.vehicle_id, networks);
            render(modal, after);
            await waitForTracker(modal);
          },
        },
      ],
    });

    function rowHtml(r, i) {
      if (r.removed) {
        return `<div class="op-card" style="margin-bottom:8px;opacity:.6;display:flex;justify-content:space-between;align-items:center;">
          <span><s>${esc(r.ssid)}</s> — will be removed</span>
          <button type="button" class="btn-sm" data-undo="${i}">Undo</button></div>`;
      }
      if (!r.saved) {
        return `<div class="op-card" style="margin-bottom:8px;">
          <div style="display:grid;grid-template-columns:1fr 1fr auto;gap:8px;">
            <input data-ssid="${i}" maxlength="32" placeholder="WiFi name" value="${esc(r.ssid)}" autocomplete="off" />
            <input data-pass="${i}" type="password" maxlength="63" placeholder="Password" autocomplete="new-password" />
            <button type="button" class="btn-sm btn-sm--danger" data-drop="${i}">Remove</button>
          </div></div>`;
      }
      const here = s.connected_to === r.ssid ? ' <span class="op-card__sub">· connected now</span>' : '';
      return `<div class="op-card" style="margin-bottom:8px;">
        <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;">
          <span><strong>${esc(r.ssid)}</strong>${here}</span>
          <span style="display:flex;gap:6px;">
            <button type="button" class="btn-sm" data-pw="${i}">${r.changePw ? 'Keep old password' : 'Change password'}</button>
            <button type="button" class="btn-sm btn-sm--danger" data-remove="${i}">Remove</button>
          </span>
        </div>
        ${r.changePw ? `<input data-pass="${i}" type="password" maxlength="63" placeholder="New password for ${esc(r.ssid)}"
                               autocomplete="new-password" style="margin-top:8px;width:100%;" />` : ''}
      </div>`;
    }

    // Typed values live in `rows`: read them before changing the list,
    // since redrawing renumbers the inputs.
    function captureRows(modal) {
      modal.querySelectorAll('[data-ssid]').forEach((el) => { rows[el.dataset.ssid].ssid = el.value; });
      modal.querySelectorAll('[data-pass]').forEach((el) => { rows[el.dataset.pass].password = el.value; });
    }

    function drawRows(modal) {
      modal.querySelector('#tw-rows').innerHTML = rows.map(rowHtml).join('');
      modal.querySelectorAll('[data-pass]').forEach((el) => { el.value = rows[el.dataset.pass].password || ''; });
      const live = rows.filter((r) => !r.removed).length;
      modal.querySelector('#tw-add').hidden = live >= MAX_NETWORKS;
    }

    function render(modal, status) {
      Object.assign(s, status);
      modal.querySelector('#tw-online').innerHTML = s.online
        ? `<span style="color:var(--op-green)">●</span> Tracker online${s.connected_to ? ` — connected to <strong>${esc(s.connected_to)}</strong>` : ''}`
        : '<span style="color:var(--op-muted)">●</span> Tracker offline — changes are sent the next time it connects.';
      modal.querySelector('#tw-status').innerHTML = wifiStatusLine(s);
    }

    function collect(modal) {
      captureRows(modal);
      const live = rows.filter((r) => !r.removed && (r.saved || r.ssid.trim()));
      if (!live.length) throw new Error('Keep at least one WiFi network, or the tracker could never reconnect.');
      const networks = live.map((r) => {
        if (r.saved && !r.changePw) return { ssid: r.ssid, keep: true };
        const ssid = r.saved ? r.ssid : r.ssid.trim();
        const password = r.password || '';
        if (password && (password.length < 8 || password.length > 63)) {
          throw new Error(`The password for "${ssid}" must be 8-63 characters (leave it empty for an open network).`);
        }
        return { ssid, password };
      });
      const names = networks.map((n) => n.ssid);
      if (new Set(names).size !== names.length) throw new Error('The same WiFi name is listed twice.');
      return networks;
    }

    async function waitForTracker(modal) {
      const started = Date.now();
      while (Date.now() - started < 60000) {
        await new Promise((r) => setTimeout(r, 3000));
        if (!modal.isConnected) return;
        const status = await OperatorApi.trackerWifi(vehicle.vehicle_id).catch(() => null);
        if (!status) continue;
        render(modal, status);
        if (!status.pending) {
          if (!status.last_error) {
            rows.splice(0, rows.length, ...status.saved.map((ssid) => ({ ssid, saved: true, removed: false, changePw: false })));
            drawRows(modal);
            modal.querySelector('#tw-status').innerHTML = `<div class="op-card" style="border-left:4px solid var(--op-green);margin-bottom:12px;">
              <p class="modal-text" style="margin:0;">✓ Saved on the tracker. It switches networks by itself when needed.</p></div>`;
          }
          return;
        }
        if (!status.online) return;   // offline: the banner says it'll get it on reconnect
      }
    }

    m.querySelector('#tw-rows').addEventListener('click', (e) => {
      const btn = e.target.closest('button');
      if (!btn) return;
      captureRows(m);
      const d = btn.dataset;
      if (d.remove !== undefined) rows[d.remove].removed = true;
      if (d.undo !== undefined) rows[d.undo].removed = false;
      if (d.drop !== undefined) rows.splice(Number(d.drop), 1);
      if (d.pw !== undefined) rows[d.pw].changePw = !rows[d.pw].changePw;
      drawRows(m);
    });
    m.querySelector('#tw-add').addEventListener('click', () => {
      captureRows(m);
      rows.push({ ssid: '', saved: false, removed: false, password: '' });
      drawRows(m);
      m.querySelector(`[data-ssid="${rows.length - 1}"]`)?.focus();
    });

    render(m, s);
    drawRows(m);
    showFirmware(m, vehicle);
  }

  // ---------- Firmware updates over the air ----------

  const FW_STATE = {
    pending: 'Waiting for the tracker to come online…',
    sent: 'Sent to the tracker…',
    downloading: 'Downloading and installing (about a minute — keep the tracker powered)…',
    done: '✓ Updated.',
  };

  async function showFirmware(m, vehicle) {
    const box = m.querySelector('#tw-fw');
    let fw;
    try {
      fw = await OperatorApi.trackerFirmware(vehicle.vehicle_id);
    } catch {
      box.innerHTML = '';
      return;
    }
    if (!m.isConnected) return;
    const job = fw.update;
    const busy = job && !['done', 'failed'].includes(job.state);
    const line = job?.state === 'failed'
      ? `<span style="color:var(--op-red)">${esc(job.error || 'Update failed.')}</span>`
      : busy ? esc(FW_STATE[job.state] || job.state)
        : job?.state === 'done' && !fw.update_available ? esc(FW_STATE.done) : '';
    box.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;">
        <span><strong>Firmware</strong> ${esc(fw.current || 'unknown')}${
          fw.latest ? (fw.update_available ? ` · <span style="color:var(--op-amber)">${esc(fw.latest)} available</span>` : ' · up to date') : ''}</span>
        ${fw.update_available && fw.can_update_remotely && !busy
          ? `<button type="button" class="btn-sm btn-sm--teal" id="fw-update">Update to ${esc(fw.latest)}</button>` : ''}
      </div>
      ${line ? `<p class="op-card__sub" style="margin:6px 0 0;">${line}</p>` : ''}
      ${fw.update_available && !fw.can_update_remotely
        ? '<p class="op-card__sub" style="margin:6px 0 0;">This version cannot update itself: use Vehicles → Install tracker firmware once (USB).</p>' : ''}`;
    box.querySelector('#fw-update')?.addEventListener('click', async (e) => {
      e.currentTarget.disabled = true;
      try {
        await OperatorApi.updateTrackerFirmware(vehicle.vehicle_id);
      } catch (err) {
        box.insertAdjacentHTML('beforeend', `<p class="op-card__sub" style="color:var(--op-red)">${esc(err.message)}</p>`);
        return;
      }
      showFirmware(m, vehicle);
    });
    if (busy) setTimeout(() => { if (m.isConnected) showFirmware(m, vehicle); }, 5000);
  }

  // ---------- Firmware installer (new / blank trackers) ----------
  //
  // ESP Web Tools writes the firmware published in /firmware (see
  // Smart-Commute-Backend/tools/release_firmware.py) straight from the
  // browser over USB. It writes only the program, never the settings area,
  // so reinstalling keeps a tracker's WiFi, vehicle and claim code.

  const ESP_WEB_TOOLS = 'https://unpkg.com/esp-web-tools@10.2.1/dist/web/install-button.js?module';
  const firmwareUrl = (file) => new URL(`../firmware/${file}`, location.href).href;

  function loadEspWebTools() {
    if (document.querySelector(`script[src="${ESP_WEB_TOOLS}"]`)) return;
    const script = document.createElement('script');
    script.type = 'module';
    script.src = ESP_WEB_TOOLS;
    document.head.appendChild(script);
  }

  async function openInstaller() {
    await disconnect();   // the installer needs the USB port to itself
    loadEspWebTools();
    const release = await fetch(firmwareUrl('latest.json'), { cache: 'no-store' })
      .then((r) => (r.ok ? r.json() : null)).catch(() => null);
    const m = AdminModal.open({
      title: 'Install tracker firmware',
      body: `
        <p class="modal-text">For a <strong>new or blank</strong> GPS tracker, or to repair one. No Arduino needed.</p>
        <ol class="modal-text" style="padding-left:18px;">
          <li>Plug the tracker into this computer with a USB <em>data</em> cable.</li>
          <li>Close the Arduino Serial Monitor and other portal tabs using the tracker.</li>
          <li>Click <strong>Install firmware</strong>, pick the tracker (e.g. "USB Serial (COM3)"), then <strong>Install</strong>. About 1 minute — don't unplug it meanwhile.</li>
          <li>When it's done, close this and use <strong>Set up GPS</strong> on the vehicle (USB or claim code), then <strong>Print label</strong>.</li>
        </ol>
        <p class="op-card__sub">${release ? `Installs Smart Commute firmware <strong>${esc(release.version)}</strong>. ` : ''}
          A tracker that was already set up keeps its WiFi, vehicle and claim code.</p>
        <esp-web-install-button manifest="${esc(firmwareUrl('manifest.json'))}">
          <button slot="activate" type="button" class="btn-lg btn-lg--primary" id="fw-install">Install firmware</button>
          <span slot="unsupported" class="modal-text" style="color:var(--op-red)">This browser can't install firmware. Use Chrome or Edge on a computer.</span>
          <span slot="not-allowed" class="modal-text" style="color:var(--op-red)">Firmware can only be installed from the portal's https address.</span>
        </esp-web-install-button>`,
      actions: [{ label: 'Close', variant: 'ghost', onClick: AdminModal.close }],
    });
    // The installer opens its own dialog; don't leave ours on top of it.
    m.querySelector('#fw-install')?.addEventListener('click', () => {
      m.style.visibility = 'hidden';
      const reveal = () => { m.style.visibility = ''; };
      setTimeout(() => {
        const dialog = document.querySelector('ewt-install-dialog');
        if (!dialog) return reveal();
        dialog.addEventListener('closed', reveal, { once: true });
      }, 400);
    });
  }

  return { open: openChooser, claimFromLabel, printLabel, openWifi, openInstaller };
})();
