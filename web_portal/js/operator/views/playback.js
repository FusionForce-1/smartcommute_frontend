// js/operator/views/playback.js
//
// Playback: replays where one of the operator's vehicles went, from its GPS
// fixes (GET /vehicles/{id}/track). Raw GPS is kept for 24 hours, so a
// window can start at most a day back. The shifts on the vehicle in the
// window can be picked to replay just that shift. Stretches without GPS show
// as breaks in the line, and playing jumps straight over them. The Fleet
// Map's vehicle popup opens this tab on its vehicle (PLAYBACK_VEHICLE_KEY).

const PLAYBACK_VEHICLE_KEY = 'sc_playback_vehicle';

OperatorRouter.register('playback', {
  title: 'Playback',
  heading: 'Vehicle Playback',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    const CEBU = [10.3157, 123.8854];
    const DAY_MS = 24 * 60 * 60 * 1000;
    const GAP_MS = 60 * 1000;        // no fix for this long: the line breaks (signal lost)
    const MOVE_M = 8;                // less than this between fixes is GPS jitter, not driving
    const GAP_NOTE_MS = 3000;        // how long the readout mentions a gap it just jumped
    const LINE_REDRAW_MS = 100;      // the travelled line redraws at most this often while playing
    const LONGEST_FRAME_MS = 250;    // back from a hidden tab: carry on, don't leap ahead
    const SPEEDS = [1, 5, 10, 30, 60];
    const PRESETS = [[1, 'Last hour'], [3, 'Last 3 h'], [6, 'Last 6 h'], [12, 'Last 12 h'], [24, 'Last 24 h']];

    let fleet = [];
    let points = [];        // [{ t (ms), lat, lng, speed, facing, source }]
    let segments = [];      // index ranges [from, to] without a gap
    let segmentLines = [];  // each segment's [lat, lng] pairs
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
    // The inputs have no seconds: rounding up keeps the last fixes in the window.
    const nextMinute = (ms) => new Date(Math.ceil(ms / 60000) * 60000);

    function setWindow(start, end) {
      limitInputs();
      fromInput.value = toLocalInput(new Date(Math.max(start, Date.now() - DAY_MS)));
      toInput.value = toLocalInput(nextMinute(Math.min(end, Date.now())));
    }

    function limitInputs() {
      const min = toLocalInput(new Date(Date.now() - DAY_MS));
      const max = toLocalInput(nextMinute(Date.now()));
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
    let lineStates = [];    // per segment: 'done', 'current' or 'ahead'
    let lastLineDraw = 0;
    let gapNote = '';
    let gapNoteUntil = 0;
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
      addFacing();
      renderShifts(track.shifts);
      pathLayer?.clearLayers();
      doneLayer?.clearLayers();
      doneLines = [];
      lineStates = [];
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
      segmentLines = segments.map(([a, b]) => points.slice(a, b + 1).map((p) => [p.lat, p.lng]));
      if (map) {
        segmentLines.forEach((line) => {
          L.polyline(line, { color: '#7D868E', weight: 4, opacity: 0.6 }).addTo(pathLayer);
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
      // A little slack: "Last 24 h" itself starts right at the limit.
      const clipped = OperatorUi.parseDate(track.oldest_available) - new Date(fromInput.value) > 5 * 60 * 1000
        ? ' GPS older than 24 hours is no longer kept.' : '';
      statusEl.textContent = `${points.length} GPS fixes${thinned} for ${track.plate_number}${gaps}.${clipped}`;
      seek(points[0].t);
    }

    /** Which way the PUV faces at each fix: its last real movement, so GPS jitter doesn't spin it while parked. */
    function addFacing() {
      const metres = (a, b) => Math.hypot(
        (b.lat - a.lat) * 110540,
        (b.lng - a.lng) * 111320 * Math.cos((a.lat * Math.PI) / 180),
      );
      let anchor = points[0];
      let facing = null;
      points.forEach((p) => {
        if (metres(anchor, p) >= MOVE_M) {
          facing = OperatorUi.bearing([anchor.lat, anchor.lng], [p.lat, p.lng]);
          anchor = p;
        }
        p.facing = facing;
      });
      // Before its first move it already faces the way it sets off.
      const first = points.find((p) => p.facing !== null)?.facing ?? null;
      points.forEach((p) => { p.facing ??= first; });
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
        const img = marker.getElement()?.querySelector('.op-puv__img');
        if (img && p.facing != null) img.style.transform = `rotate(${p.facing}deg)`;
      }
      drawTravelled(i, [lat, lng]);
      const kmh = typeof p.speed === 'number' ? `${Math.round(p.speed)} km/h` : '— km/h';
      const source = p.source === 'phone' ? ' · from the driver’s phone' : '';
      const note = performance.now() < gapNoteUntil ? gapNote : '';
      readout.textContent = `${clock(now, true)} · ${kmh}${source}${note}`;
    }

    /** Grows the travelled line up to fix i: only the stretch in progress redraws. */
    function drawTravelled(i, tip) {
      const stamp = performance.now();
      const throttled = playing && stamp - lastLineDraw < LINE_REDRAW_MS;
      segments.forEach(([a, b], k) => {
        const state = b <= i ? 'done' : a <= i ? 'current' : 'ahead';
        if (state === 'current') {
          if (throttled) return;
          doneLines[k]?.setLatLngs([...segmentLines[k].slice(0, i - a + 1), tip]);
          lastLineDraw = stamp;
        } else if (state !== lineStates[k]) {
          doneLines[k]?.setLatLngs(state === 'done' ? segmentLines[k] : []);
        }
        lineStates[k] = state;
      });
    }

    /** t, or the end of the gap it falls in: nothing happens there to watch. */
    function pastGap(t) {
      const i = indexAt(t);
      const next = points[i + 1];
      if (!next || next.t - points[i].t <= GAP_MS) return t;
      const seconds = Math.round((next.t - points[i].t) / 1000);
      const hours = Math.floor(seconds / 3600);
      const minutes = Math.floor((seconds % 3600) / 60);
      gapNote = ` · skipped ${hours ? `${hours} h ${minutes} min` : `${minutes} min ${seconds % 60} s`} with no GPS`;
      gapNoteUntil = performance.now() + GAP_NOTE_MS;
      return next.t;
    }

    function tick(stamp) {
      if (!playing) return;
      if (lastTick !== null) seek(pastGap(now + Math.min(stamp - lastTick, LONGEST_FRAME_MS) * speed));
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
