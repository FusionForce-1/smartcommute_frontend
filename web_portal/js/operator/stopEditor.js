// js/operator/stopEditor.js
//
// "Edit stops" on a route card: the route's line and terminals on a map.
// Click the map to add a stop (named after the nearest landmark when one is
// close), drag a stop to move it, rename or remove it in the list. Saving
// (PUT /routes/{id}/stops) puts the stops in riding order along the line,
// and the trip planner can then board and drop commuters off at them.

const StopEditor = (() => {
  const esc = (s) => AdminUi.escapeHtml(String(s ?? ''));
  const OFF_ROUTE_WARN_M = 100;      // a stop this far from the line is probably misplaced
  const LANDMARK_NAME_M = 120;       // name a new stop after a landmark this close

  // ---------- Geometry (metres, local flat projection) ----------

  const M_PER_DEG = 111320;
  function project(line, p) {
    // -> { along, off } of point p ({lat,lng}) on line [[lat,lng], ...]
    if (line.length < 2) return { along: 0, off: null };
    const kx = M_PER_DEG * Math.cos((p.lat * Math.PI) / 180);
    const xy = ([lat, lng]) => [(lng - p.lng) * kx, (lat - p.lat) * M_PER_DEG];
    let best = { along: 0, off: Infinity };
    let walked = 0;
    for (let i = 0; i < line.length - 1; i++) {
      const [ax, ay] = xy(line[i]);
      const [bx, by] = xy(line[i + 1]);
      const dx = bx - ax, dy = by - ay;
      const len2 = dx * dx + dy * dy;
      const t = len2 ? Math.max(0, Math.min(1, (-ax * dx - ay * dy) / len2)) : 0;
      const off = Math.hypot(ax + t * dx, ay + t * dy);
      const len = Math.sqrt(len2);
      if (off < best.off) best = { along: walked + t * len, off };
      walked += len;
    }
    return best;
  }

  function metresBetween(a, b) {
    const kx = M_PER_DEG * Math.cos((a.lat * Math.PI) / 180);
    return Math.hypot((b.lng - a.lng) * kx, (b.lat - a.lat) * M_PER_DEG);
  }

  // ---------- Editor ----------

  function open(route, { onSaved = () => {} } = {}) {
    let map = null;
    let line = [];           // [[lat, lng], ...]
    let stops = [];          // { key, id?, name, landmark, lat, lng, marker }
    let nextKey = 1;
    let dirty = false;
    let landmarks = [];
    RoutePicker.loadLandmarks().then((list) => { landmarks = list; });

    const modal = AdminModal.open({
      title: `Stops — ${route.code} ${route.name}`,
      size: 'wide',
      body: `
        <p class="op-card__sub" style="margin:0 0 8px;">
          Click the map to add a stop, drag a stop to move it. Stops are saved in riding order along the route line.
        </p>
        <div class="op-map" id="se-map" style="height:380px;" role="region" aria-label="Route stops map"></div>
        <div class="se-toolbar" style="display:flex;gap:8px;flex-wrap:wrap;margin:10px 0;">
          <button type="button" class="btn-sm" id="se-terminals">Add stops at both terminals</button>
          <span id="se-count" class="op-card__sub" style="margin:auto 0;"></span>
        </div>
        <div id="se-list">${AdminUi.stateMessage('Loading…')}</div>`,
      actions: [
        { label: 'Cancel', variant: 'ghost', onClick: () => AdminModal.close() },
        { label: 'Save Stops', variant: 'primary', onClick: save },
      ],
      onClose: () => { if (map) map.remove(); },
    });

    const listEl = modal.querySelector('#se-list');
    const countEl = modal.querySelector('#se-count');

    if (window.L) {
      map = L.map(modal.querySelector('#se-map')).setView([10.3157, 123.8854], 13);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19, attribution: '&copy; OpenStreetMap contributors',
      }).addTo(map);
      map.on('click', (e) => {
        addStop(e.latlng.lat, e.latlng.lng);
        render();
      });
    } else {
      modal.querySelector('#se-map').innerHTML = AdminUi.stateMessage('The map could not load. Check your internet connection.', { error: true });
    }

    function stopIcon(n, warn) {
      return L.divIcon({
        className: '',
        html: `<div style="width:26px;height:26px;border-radius:50%;background:${warn ? '#F5A623' : '#2E86AB'};color:#fff;
          font:600 12px/26px Poppins,sans-serif;text-align:center;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.35);">${n}</div>`,
        iconSize: [26, 26], iconAnchor: [13, 13],
      });
    }

    function terminalIcon(color, label) {
      return L.divIcon({
        className: '',
        html: `<div title="${esc(label)}" style="width:16px;height:16px;border-radius:50%;background:${color};border:3px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.35);"></div>`,
        iconSize: [16, 16], iconAnchor: [8, 8],
      });
    }

    function nearestLandmark(lat, lng) {
      let best = null;
      let bestM = LANDMARK_NAME_M;
      for (const p of landmarks) {
        if (Math.abs(p.lat - lat) > 0.002 || Math.abs(p.lng - lng) > 0.002) continue;
        const m = metresBetween({ lat, lng }, p);
        if (m < bestM) { bestM = m; best = p; }
      }
      return best;
    }

    function addStop(lat, lng, { id, name, landmark } = {}) {
      const near = name ? null : nearestLandmark(lat, lng);
      const stop = {
        key: nextKey++, id, lat, lng,
        name: name || (near ? near.name : `Stop ${stops.length + 1}`),
        landmark: landmark ?? '',
        marker: null,
      };
      if (map) {
        stop.marker = L.marker([lat, lng], { draggable: true, icon: stopIcon('+') }).addTo(map);
        stop.marker.on('dragend', () => {
          const p = stop.marker.getLatLng();
          stop.lat = p.lat;
          stop.lng = p.lng;
          dirty = true;
          render();
        });
      }
      stops.push(stop);
      if (!id) dirty = true;
      return stop;
    }

    function removeStop(key) {
      const stop = stops.find((s) => s.key === key);
      if (!stop) return;
      if (stop.marker) stop.marker.remove();
      stops = stops.filter((s) => s.key !== key);
      dirty = true;
      render();
    }

    /** Riding order along the line (as placed, without a line), plus distance from it. */
    function ordered() {
      return stops
        .map((s, i) => ({ s, i, ...project(line, s) }))
        .sort((a, b) => (line.length >= 2 ? a.along - b.along : 0) || a.i - b.i);
    }

    function render() {
      const rows = ordered();
      rows.forEach((r, n) => {
        const warn = r.off != null && r.off > OFF_ROUTE_WARN_M;
        if (r.s.marker) {
          r.s.marker.setIcon(stopIcon(n + 1, warn));
          r.s.marker.bindTooltip(esc(r.s.name), { direction: 'top', offset: [0, -12] });
        }
      });
      countEl.textContent = `${stops.length} ${stops.length === 1 ? 'stop' : 'stops'}${dirty ? ' · not saved yet' : ''}`;
      if (!rows.length) {
        listEl.innerHTML = AdminUi.stateMessage('No stops yet. Click the map where jeepneys pick up and drop off passengers.');
        return;
      }
      listEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>#</th><th>Stop name</th><th>Landmark (optional)</th><th></th><th></th></tr></thead>
            <tbody>
              ${rows.map((r, n) => {
                const warn = r.off != null && r.off > OFF_ROUTE_WARN_M;
                return `
                  <tr data-key="${r.s.key}">
                    <td>${n + 1}</td>
                    <td><input class="se-name" data-key="${r.s.key}" maxlength="80" value="${esc(r.s.name)}" aria-label="Stop ${n + 1} name" style="width:100%;"></td>
                    <td><input class="se-landmark" data-key="${r.s.key}" maxlength="120" value="${esc(r.s.landmark)}" placeholder="e.g. across the church" aria-label="Stop ${n + 1} landmark" style="width:100%;"></td>
                    <td>${warn ? OperatorUi.chip(`${Math.round(r.off)} m off the route`, 'amber') : ''}</td>
                    <td style="white-space:nowrap;">
                      <button type="button" class="btn-sm" data-se="focus" data-key="${r.s.key}">Show</button>
                      <button type="button" class="btn-sm" data-se="remove" data-key="${r.s.key}" aria-label="Remove stop ${n + 1}">Remove</button>
                    </td>
                  </tr>`;
              }).join('')}
            </tbody>
          </table>
        </div>`;
    }

    listEl.addEventListener('input', (e) => {
      const key = Number(e.target.dataset.key);
      const stop = stops.find((s) => s.key === key);
      if (!stop) return;
      if (e.target.classList.contains('se-name')) stop.name = e.target.value;
      if (e.target.classList.contains('se-landmark')) stop.landmark = e.target.value;
      dirty = true;
      countEl.textContent = `${stops.length} ${stops.length === 1 ? 'stop' : 'stops'} · not saved yet`;
      stop.marker?.setTooltipContent?.(esc(stop.name));
    });

    listEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-se]');
      if (!btn) return;
      const key = Number(btn.dataset.key);
      if (btn.dataset.se === 'remove') removeStop(key);
      if (btn.dataset.se === 'focus') {
        const stop = stops.find((s) => s.key === key);
        if (stop && map) map.setView([stop.lat, stop.lng], 17);
      }
    });

    modal.querySelector('#se-terminals').addEventListener('click', () => {
      const ends = [
        [route.terminal_a, data?.terminal_a_location?.coordinates, line[0]],
        [route.terminal_b, data?.terminal_b_location?.coordinates, line[line.length - 1]],
      ];
      let added = 0;
      for (const [name, pin, end] of ends) {
        const at = pin ? { lat: pin[1], lng: pin[0] } : end ? { lat: end[0], lng: end[1] } : null;
        if (!at) continue;
        if (stops.some((s) => metresBetween(s, at) < 30)) continue;
        addStop(at.lat, at.lng, { name: name || undefined });
        added++;
      }
      if (!added) AdminUi.toast(line.length ? 'Both terminals already have a stop.' : 'This route has no line or terminal pins yet.');
      render();
    });

    async function save() {
      const rows = ordered();
      const empty = rows.findIndex((r) => !r.s.name.trim());
      if (empty >= 0) throw new Error(`Stop ${empty + 1} needs a name.`);
      const payload = rows.map(({ s }) => ({
        ...(s.id ? { id: s.id } : {}),
        name: s.name.trim(),
        landmark: s.landmark.trim() || null,
        location: { type: 'Point', coordinates: [s.lng, s.lat] },
      }));
      const saved = await OperatorApi.setRouteStops(route.id, payload);   // errors show in the modal
      AdminUi.toast(`${route.code}: ${saved.stops.length} ${saved.stops.length === 1 ? 'stop' : 'stops'} saved.`);
      dirty = false;
      AdminModal.close();
      onSaved(saved);
    }

    // ---------- Load ----------

    let data = null;
    OperatorApi.routeStops(route.id).then((d) => {
      data = d;
      line = (d.geometry?.coordinates || []).map(([lng, lat]) => [lat, lng]);
      const bounds = [];
      if (map && line.length >= 2) {
        L.polyline(line, { color: '#2E86AB', weight: 5, opacity: 0.6, interactive: false }).addTo(map);
        bounds.push(...line);
      }
      const pins = [
        [d.terminal_a_location?.coordinates, '#27AE60', d.terminal_a || 'Terminal A'],
        [d.terminal_b_location?.coordinates, '#D72F33', d.terminal_b || 'Terminal B'],
      ];
      for (const [c, color, label] of pins) {
        if (!c || !map) continue;
        L.marker([c[1], c[0]], { icon: terminalIcon(color, label), interactive: false, keyboard: false }).addTo(map);
        bounds.push([c[1], c[0]]);
      }
      d.stops.forEach((s) => {
        const [lng, lat] = s.location.coordinates;
        addStop(lat, lng, { id: s.id, name: s.name, landmark: s.landmark || '' });
        bounds.push([lat, lng]);
      });
      dirty = false;
      if (map && bounds.length) map.fitBounds(L.latLngBounds(bounds), { padding: [30, 30], maxZoom: 16 });
      render();
    }).catch((err) => {
      listEl.innerHTML = AdminUi.stateMessage(err.message || 'Could not load this route\'s stops.', { error: true });
    });
  }

  return { open };
})();
