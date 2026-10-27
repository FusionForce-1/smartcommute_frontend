// js/operator/views/playback.js
//
// Playback: replays where one of the operator's vehicles went, from its GPS
// fixes (GET /vehicles/{id}/track). Raw GPS is kept for 24 hours, so a
// window can start at most a day back. The shifts on the vehicle in the
// window can be picked to replay just that shift. The Fleet Map's vehicle
// popup opens this tab on its vehicle (PLAYBACK_VEHICLE_KEY).

const PLAYBACK_VEHICLE_KEY = 'sc_playback_vehicle';

OperatorRouter.register('playback', {
  title: 'Playback',
  heading: 'Vehicle Playback',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    const CEBU = [10.3157, 123.8854];
    const DAY_MS = 24 * 60 * 60 * 1000;
    const GAP_MS = 60 * 1000;        // no fix for this long: the line breaks (signal lost)
    const SPEEDS = [1, 5, 10, 30, 60];
    const PRESETS = [[1, 'Last hour'], [3, 'Last 3 h'], [6, 'Last 6 h'], [12, 'Last 12 h'], [24, 'Last 24 h']];

    let fleet = [];
    let points = [];        // [{ t (ms), lat, lng, speed, heading, source }]
    let segments = [];      // index ranges [from, to] without a gap
    let now = 0;            // playback time, ms
    let speed = 10;
    let playing = false;
    let frame = null;
    let lastTick = null;
    let request = 0;        // ignores answers to older loads

    el.innerHTML = `
      <div class="op-page-head">
        <div>
          <h2>Playback</h2>
          <p>Replay where a vehicle went. GPS is kept for 24 hours.</p>
        </div>
      </div>
      <section class="op-card">
        <div class="op-pb-controls">
          <div class="op-field">
            <label for="pb-vehicle">Vehicle</label>
            <select id="pb-vehicle"><option value="">Loading…</option></select>
          </div>
          <div class="op-field">
            <label for="pb-from">From</label>
            <input id="pb-from" type="datetime-local" />
          </div>
          <div class="op-field">
            <label for="pb-to">To</label>
            <input id="pb-to" type="datetime-local" />
          </div>
          <button type="button" class="op-btn" id="pb-load">Show</button>
        </div>
        <div class="op-pb-presets">
          ${PRESETS.map(([h, label]) => `<button type="button" class="btn-sm" data-hours="${h}">${label}</button>`).join('')}
        </div>
        <div id="pb-shifts" class="op-pb-presets"></div>
      </section>
      <div class="op-map" id="pb-map" role="region" aria-label="Playback map"></div>
      <section class="op-card op-pb-player" id="pb-player" hidden>
        <button type="button" class="op-btn" id="pb-play" aria-label="Play">▶</button>
        <input type="range" id="pb-slider" min="0" max="1" step="1000" value="0" aria-label="Playback position" />
        <select id="pb-speed" aria-label="Playback speed">
          ${SPEEDS.map((x) => `<option value="${x}"${x === speed ? ' selected' : ''}>${x}×</option>`).join('')}
        </select>
        <div class="op-pb-readout" id="pb-readout"></div>
      </section>
      <p class="modal-text" id="pb-status"></p>`;

    const $ = (sel) => el.querySelector(sel);
    const vehicleSelect = $('#pb-vehicle');
    const fromInput = $('#pb-from');
    const toInput = $('#pb-to');
    const shiftsEl = $('#pb-shifts');
    const playerEl = $('#pb-player');
    const playBtn = $('#pb-play');
    const slider = $('#pb-slider');
    const readout = $('#pb-readout');
    const statusEl = $('#pb-status');

    // ---------- Time inputs (local time, as datetime-local shows it) ----------

    const pad = (n) => String(n).padStart(2, '0');
    const toLocalInput = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    const clock = (ms, seconds = false) => new Date(ms).toLocaleTimeString('en-US',
      { hour: 'numeric', minute: '2-digit', ...(seconds ? { second: '2-digit' } : {}) });

    function setWindow(start, end) {
      const oldest = Date.now() - DAY_MS;
      fromInput.value = toLocalInput(new Date(Math.max(start, oldest)));
      toInput.value = toLocalInput(new Date(Math.min(end, Date.now())));
    }

    function limitInputs() {
      const min = toLocalInput(new Date(Date.now() - DAY_MS));
      const max = toLocalInput(new Date());
      [fromInput, toInput].forEach((input) => { input.min = min; input.max = max; });
    }

    // ---------- Map ----------

    const map = window.L ? L.map($('#pb-map')).setView(CEBU, 13) : null;
    if (map) {
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors',
      }).addTo(map);
    } else {
      $('#pb-map').innerHTML = AdminUi.stateMessage('The map could not load. Check your internet connection.', { error: true });
    }
    const routeLayer = map ? L.layerGroup().addTo(map) : null;
    const pathLayer = map ? L.layerGroup().addTo(map) : null;
    const doneLayer = map ? L.layerGroup().addTo(map) : null;
    let doneLines = [];     // one polyline per segment, grown as the vehicle moves
    let marker = null;

    const puvIcon = () => L.divIcon({
      className: '',
      html: '<div class="op-puv"><img class="op-puv__img" src="../assets/icons/puv.svg" alt="" draggable="false" /></div>',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
    });
    const endDot = (color) => L.circleMarker([0, 0], { radius: 6, color: '#fff', weight: 2, fillColor: color, fillOpacity: 1 });

    async function drawRoute(routeId) {
      routeLayer?.clearLayers();
      if (!map || !routeId) return;
      try {
        const route = await OperatorApi.route(routeId);
        const coords = route.geometry?.coordinates || [];
        if (coords.length > 1) {
          L.polyline(coords.map(([lng, lat]) => [lat, lng]), { color: '#3B8A9E', weight: 6, opacity: 0.25 }).addTo(routeLayer);
        }
      } catch {
        // No map line for this route: the GPS path alone is still shown.
      }
    }

    // ---------- Loading a window ----------

    function selectedVehicle() {
      return fleet.find((v) => v.vehicle_id === vehicleSelect.value);
    }

    async function load() {
      const vehicle = selectedVehicle();
      if (!vehicle) return;
      const start = new Date(fromInput.value);
      const end = new Date(toInput.value);
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start >= end) {
        statusEl.textContent = 'Pick a "From" time before the "To" time.';
        return;
      }
      pause();
      const mine = ++request;
      statusEl.textContent = 'Loading…';
      try {
        const [track] = await Promise.all([
          OperatorApi.vehicleTrack(vehicle.vehicle_id, { start: start.toISOString(), end: end.toISOString() }),
          drawRoute(vehicle.route_id),
        ]);
        if (mine !== request) return;
        show(track);
      } catch (err) {
        if (mine !== request) return;
        statusEl.textContent = err.message || 'Could not load the GPS track.';
      }
    }

    function show(track) {
      points = track.points.map((p) => ({ ...p, t: OperatorUi.parseDate(p.t).getTime() }));
      renderShifts(track.shifts);
      pathLayer?.clearLayers();
      doneLayer?.clearLayers();
      doneLines = [];
      marker = null;

      if (!points.length) {
        playerEl.hidden = true;
        statusEl.textContent = `No GPS from ${track.plate_number} between ${clock(+new Date(fromInput.value))} and ${clock(+new Date(toInput.value))}.`;
        return;
      }

      segments = [];
      let from = 0;
      for (let i = 1; i <= points.length; i++) {
        if (i === points.length || points[i].t - points[i - 1].t > GAP_MS) {
          segments.push([from, i - 1]);
          from = i;
        }
      }
      if (map) {
        segments.forEach(([a, b]) => {
          L.polyline(points.slice(a, b + 1).map((p) => [p.lat, p.lng]), { color: '#7D868E', weight: 4, opacity: 0.6 }).addTo(pathLayer);
          doneLines.push(L.polyline([], { color: '#3B8A9E', weight: 5 }).addTo(doneLayer));
        });
        endDot('#27AE60').setLatLng([points[0].lat, points[0].lng]).bindTooltip(`Start ${clock(points[0].t)}`).addTo(pathLayer);
        const last = points[points.length - 1];
        endDot('#D72F33').setLatLng([last.lat, last.lng]).bindTooltip(`End ${clock(last.t)}`).addTo(pathLayer);
        marker = L.marker([points[0].lat, points[0].lng], { icon: puvIcon(), zIndexOffset: 1000 }).addTo(doneLayer);
        map.fitBounds(L.latLngBounds(points.map((p) => [p.lat, p.lng])), { padding: [40, 40], maxZoom: 16 });
      }

      slider.min = String(points[0].t);
      slider.max = String(points[points.length - 1].t);
      playerEl.hidden = false;
      const thinned = track.total_fixes > points.length ? ` (thinned from ${track.total_fixes})` : '';
      const gaps = segments.length > 1 ? ` · GPS was off ${segments.length - 1} time${segments.length === 2 ? '' : 's'}` : '';
      statusEl.textContent = `${points.length} GPS fixes${thinned} for ${track.plate_number}${gaps}.`;
      seek(points[0].t);
    }

    function renderShifts(shifts) {
      shiftsEl.innerHTML = shifts.length
        ? `<span class="op-card__sub" style="align-self:center;">Shifts:</span>${shifts.map((s) => `
            <button type="button" class="btn-sm btn-sm--teal" data-start="${esc(s.started_at)}" data-end="${esc(s.ended_at || '')}">
              ${esc(s.driver_name)} · ${esc(clock(OperatorUi.parseDate(s.started_at).getTime()))} – ${s.ended_at ? esc(clock(OperatorUi.parseDate(s.ended_at).getTime())) : 'now'}
            </button>`).join('')}`
        : '';
    }

    // ---------- Playing ----------

    /** Index of the last fix at or before time t. */
    function indexAt(t) {
      let lo = 0;
      let hi = points.length - 1;
      while (lo < hi) {
        const mid = (lo + hi + 1) >> 1;
        if (points[mid].t <= t) lo = mid; else hi = mid - 1;
      }
      return lo;
    }

    function seek(t) {
      now = Math.min(Math.max(t, points[0].t), points[points.length - 1].t);
      slider.value = String(now);
      const i = indexAt(now);
      const p = points[i];
      const next = points[i + 1];
      let lat = p.lat;
      let lng = p.lng;
      // Glide between fixes, but not across a gap (the vehicle wasn't seen there).
      if (next && next.t - p.t <= GAP_MS && next.t > p.t) {
        const f = (now - p.t) / (next.t - p.t);
        lat += (next.lat - p.lat) * f;
        lng += (next.lng - p.lng) * f;
      }
      if (marker) {
        marker.setLatLng([lat, lng]);
        const heading = p.heading ?? (next ? OperatorUi.bearing([p.lat, p.lng], [next.lat, next.lng]) : null);
        const img = marker.getElement()?.querySelector('.op-puv__img');
        if (img && heading != null) img.style.transform = `rotate(${heading}deg)`;
      }
      segments.forEach(([a, b], k) => {
        const line = doneLines[k];
        if (!line) return;
        if (b <= i) line.setLatLngs(points.slice(a, b + 1).map((q) => [q.lat, q.lng]));
        else if (a <= i) line.setLatLngs([...points.slice(a, i + 1).map((q) => [q.lat, q.lng]), [lat, lng]]);
        else line.setLatLngs([]);
      });
      const kmh = typeof p.speed === 'number' ? `${Math.round(p.speed)} km/h` : '— km/h';
      const source = p.source === 'phone' ? ' · from the driver’s phone' : '';
      readout.textContent = `${clock(now, true)} · ${kmh}${source}`;
    }

    function tick(stamp) {
      if (!playing) return;
      if (lastTick !== null) seek(now + (stamp - lastTick) * speed);
      lastTick = stamp;
      if (now >= points[points.length - 1].t) {
        pause();
        return;
      }
      frame = requestAnimationFrame(tick);
    }

    function play() {
      if (!points.length) return;
      if (now >= points[points.length - 1].t) seek(points[0].t);   // replay from the start
      playing = true;
      lastTick = null;
      playBtn.textContent = '❚❚';
      playBtn.setAttribute('aria-label', 'Pause');
      frame = requestAnimationFrame(tick);
    }

    function pause() {
      playing = false;
      if (frame) cancelAnimationFrame(frame);
      frame = null;
      playBtn.textContent = '▶';
      playBtn.setAttribute('aria-label', 'Play');
    }

    // ---------- Events ----------

    playBtn.addEventListener('click', () => (playing ? pause() : play()));
    slider.addEventListener('input', () => { if (points.length) seek(Number(slider.value)); });
    $('#pb-speed').addEventListener('change', (e) => { speed = Number(e.target.value); });
    $('#pb-load').addEventListener('click', load);
    vehicleSelect.addEventListener('change', load);
    el.querySelector('.op-pb-presets').addEventListener('click', (e) => {
      const btn = e.target.closest('[data-hours]');
      if (!btn) return;
      const end = Date.now();
      setWindow(end - Number(btn.dataset.hours) * 60 * 60 * 1000, end);
      load();
    });
    shiftsEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-start]');
      if (!btn) return;
      const start = OperatorUi.parseDate(btn.dataset.start).getTime();
      const end = btn.dataset.end ? OperatorUi.parseDate(btn.dataset.end).getTime() : Date.now();
      setWindow(start, end);
      load();
    });

    // ---------- Start ----------

    limitInputs();
    setWindow(Date.now() - 60 * 60 * 1000, Date.now());
    OperatorApi.fleet().then((f) => {
      fleet = f;
      if (!fleet.length) {
        vehicleSelect.innerHTML = '<option value="">No vehicles yet</option>';
        statusEl.textContent = 'Register a vehicle first (Vehicles page).';
        return;
      }
      vehicleSelect.innerHTML = fleet.map((v) => `<option value="${esc(v.vehicle_id)}">${esc(v.plate_number)}</option>`).join('');
      let wanted = null;
      try {
        wanted = sessionStorage.getItem(PLAYBACK_VEHICLE_KEY);
        sessionStorage.removeItem(PLAYBACK_VEHICLE_KEY);
      } catch { /* private mode */ }
      if (wanted && fleet.some((v) => v.vehicle_id === wanted)) vehicleSelect.value = wanted;
      load();
    }).catch((err) => {
      vehicleSelect.innerHTML = '<option value="">—</option>';
      statusEl.textContent = err.message || 'Could not load your vehicles.';
    });

    return () => {
      pause();
      request++;
      map?.remove();
    };
  },
});
