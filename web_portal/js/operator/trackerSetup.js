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

  /** The WiFi rows as [{ssid, password}], or throws a readable error. */
  function readWifi(m) {
    const nets = [...m.querySelectorAll('.ts-wifi')]
      .map((row) => ({
        ssid: row.querySelector('.ts-ssid').value.trim(),
        password: row.querySelector('.ts-pass').value,
      }))
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
          + 'and that the tracker runs Smart Commute firmware 2.0 or newer.'));
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

  function openUsb(vehicle, onDone) {
    let info = null;
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
              return;
            }
            const networks = readWifi(modal);
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
    m.querySelector('#ts-scan').addEventListener('click', async (e) => {
      const btn = e.currentTarget;
      btn.disabled = true;
      btn.textContent = 'Scanning…';
      try {
        const { networks } = await command('scan', {}, { timeoutMs: 15000 });
        m.querySelector('#ts-ssids').innerHTML = [...new Set(networks.map((n) => n.ssid).filter(Boolean))]
          .map((s) => `<option value="${esc(s)}"></option>`).join('');
        btn.textContent = `${networks.length} found — pick one in the WiFi name box`;
      } catch (err) {
        btn.textContent = err.message;
      } finally {
        btn.disabled = false;
      }
    });
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
      </div>`;
  }

  function openClaim(vehicle, onDone) {
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
            <input id="ts-code" maxlength="12" placeholder="ABCD-EFGH" autocomplete="off"
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
    m.querySelector('#ts-code').focus();
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

  return { open: openChooser };
})();
