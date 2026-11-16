// js/operator/stopEditor.js
//
// "Edit stops" on a route card: the route's line and terminals on a map.
// Click the map to add a stop (named after the nearest landmark when one is
// close), drag a stop to move it, rename or remove it in the list. Saving
// (PUT /routes/{id}/stops) puts the stops in riding order along the line,
// and the trip planner can then board and drop commuters off at them.
//
// The line was drawn when the route was made (the road path between its
// terminals), so stops pinned where the jeepney really goes can end up far
// from it, and commuters' trips are then drawn and timed along the line, not
// past those stops. "Redraw line through stops" asks OSRM for the road path
// through the stops in riding order; it's saved with them. Each stop is sent
// with the direction of travel there (previous stop -> next stop): without
// it OSRM snaps some stops to the far side of a divided road and loops back
// (tried on 10H: 15 km of U-turn loops against 9.7 km with directions).
//
// A stop the line would loop round the block for is left out of the redraw:
// the stop for the other direction across the road (10M had two "Lorega"
// and two "G Mall" stops) or one out of riding order. It stays a stop,
// marked in the list, and the new line passes within PASS_BY_M of it; if it
// doesn't, the jeep really goes there and the line is routed through it after
// all (07B round Carbon). Only a stop with no road going the direction of
// travel loses that check, not every stop as before. Saving puts every stop
// in riding order along the new line. On 10M: 11.6 km with every stop within
// 36 m, against 16.9 km of loops; 07B and 10H kept every stop within 40 m.

const StopEditor = (() => {
  const esc = (s) => AdminUi.escapeHtml(String(s ?? ''));
  const OFF_ROUTE_WARN_M = 100;      // a stop this far from the line is probably misplaced
  const LANDMARK_NAME_M = 120;       // name a new stop after a landmark this close
  const OSRM = 'https://router.project-osrm.org/route/v1/driving';   // as in RoutePicker
  const MAX_LINE_POINTS = 5000;      // MAX_LINE_POINTS on the server
  const END_KEEP_M = 50;             // keep the line's ends when they're this far past the end stops
  // The road a stop snaps to must run within ±60° of the direction of travel
  // and lie within 50 m of it; the loose settings are a last resort.
  const STRICT = { range: 60, radius: 50 };
  const LOOSE = { range: 90, radius: null };
  // A leg between two stops this much longer than the straight hop, and this
  // many times it, loops back to reach a stop.
  const LOOP_EXTRA_M = 300;
  const LOOP_RATIO = 2.5;
  const DIRECT_GUESS = 1.3;          // a direct hop by road is about this much longer than straight
  // A left-out stop the new line passes this close is still served; further
  // away, the jeep really goes there (e.g. round Carbon's one-way streets on
  // 07B), so it's routed through after all.
  const PASS_BY_M = 60;
  const MAX_REDRAW_ROUNDS = 8;
  const MAX_REDRAW_CALLS = 16;       // OSRM requests per redraw (the public server is shared)

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

  /** Degrees from north going from a to b ({lat, lng}). */
  function bearing(a, b) {
    const dx = (b.lng - a.lng) * Math.cos((a.lat * Math.PI) / 180);
    return ((Math.atan2(dx, b.lat - a.lat) * 180) / Math.PI + 360) % 360;
  }

  /**
   * One OSRM route through points ({lat, lng}) with the direction of travel
   * at each (none where noDirection[i]): { route } (OSRM's, with legs),
   * { noSegment: i } when point i has no road going that way close by, or null.
   */
  async function osrmRoute(points, { range, radius }, noDirection = []) {
    const coords = points.map((p) => `${p.lng},${p.lat}`).join(';');
    const heads = points.map((p, i) => {
      const from = points[Math.max(0, i - 1)];
      const to = points[Math.min(points.length - 1, i + 1)];
      return noDirection[i] || metresBetween(from, to) < 5 ? null : Math.round(bearing(from, to));
    });
    const params = new URLSearchParams({ overview: 'full', geometries: 'geojson' });
    params.set('bearings', heads.map((h) => (h == null ? '' : `${h},${range}`)).join(';'));
    if (radius) params.set('radiuses', points.map(() => radius).join(';'));
    try {
      const res = await fetch(`${OSRM}/${coords}?${params}`);
      const body = await res.json().catch(() => null);
      const route = body?.routes?.[0];
      if (res.ok && route?.geometry?.coordinates?.length >= 2) return { route };
      const at = body?.code === 'NoSegment' && /coordinate (\d+)/.exec(body.message || '');
      return at ? { noSegment: Number(at[1]) } : null;
    } catch {
      return null;
    }
  }

  /**
   * The road path through points ({lat, lng}, in riding order), as
   * { path: [[lng, lat], ...], skipped: [indexes into points] }, or null.
   *
   * A point with no road going the direction of travel within 50 m is passed
   * either way; with no road there at all it's left out. A point the line
   * loops back for is left out too, unless the new line then doesn't pass
   * within PASS_BY_M of it: then it's routed through for good. The first
   * and last points are never left out.
   */
  async function roadPathThrough(points) {
    let keep = points.map((_, i) => i);
    const anyWay = new Set();    // no road going the direction of travel close by
    const looped = new Set();    // left out: the line looped back for them
    const offRoad = new Set();   // left out: no road within 50 m at all
    const needed = new Set();    // the line has to go to them
    let best = null;
    let calls = 0;
    let rounds = 0;
    const done = (route) => {
      best = { path: route.geometry.coordinates, skipped: [...looped, ...offRoad] };
    };
    while (calls < MAX_REDRAW_CALLS) {
      const at = keep.map((i) => points[i]);
      calls++;
      let found = await osrmRoute(at, STRICT, keep.map((i) => anyWay.has(i)));
      const k = found?.noSegment;
      if (k != null && !anyWay.has(keep[k])) {
        anyWay.add(keep[k]);
        continue;
      }
      if (k != null && k > 0 && k < keep.length - 1) {
        offRoad.add(keep[k]);                  // one point fewer each time, so this ends
        keep = keep.filter((_, j) => j !== k);
        continue;
      }
      if (!found?.route) {
        found = await osrmRoute(at, LOOSE);    // last resort: every stop, any nearby road
        if (found?.route) done(found.route);
        break;
      }

      const line = found.route.geometry.coordinates.map(([lng, lat]) => [lat, lng]);
      const far = [...looped].filter((i) => project(line, points[i]).off > PASS_BY_M);
      if (far.length) {
        far.forEach((i) => { looped.delete(i); needed.add(i); });
        keep = [...keep, ...far].sort((a, b) => a - b);
        continue;
      }
      done(found.route);

      // Legs that loop back: leave out whichever end saves the most.
      const hop = (a, b) => metresBetween(points[keep[a]], points[keep[b]]);
      const legs = found.route.legs.map((l) => l.distance);
      const extra = (j) => {
        const straight = hop(j, j + 1);
        const more = legs[j] - straight;
        return more > LOOP_EXTRA_M && legs[j] > LOOP_RATIO * straight ? more : 0;
      };
      const saving = (c) => legs[c - 1] + legs[c] - DIRECT_GUESS * hop(c - 1, c + 1);
      const loops = legs.map((_, j) => j).filter((j) => extra(j) > 0).sort((a, b) => extra(b) - extra(a));
      const drop = new Set();
      for (const j of loops) {
        const ends = [j + 1, j].filter((c) => c > 0 && c < keep.length - 1 && !needed.has(keep[c])
          && !drop.has(c - 1) && !drop.has(c) && !drop.has(c + 1));
        if (!ends.length) continue;
        const c = ends.reduce((a, b) => (saving(b) > saving(a) ? b : a));
        if (saving(c) >= LOOP_EXTRA_M) drop.add(c);
      }
      if (!drop.size || ++rounds >= MAX_REDRAW_ROUNDS) break;
      drop.forEach((c) => looped.add(keep[c]));
      keep = keep.filter((_, j) => !drop.has(j));
    }
    return best;
  }

  // ---------- Editor ----------

  function open(route, { onSaved = () => {} } = {}) {
    let map = null;
    let line = [];           // [[lat, lng], ...]
    let lineLayer = null;    // the line on the map
    let lineChanged = false; // redrawn through the stops: saved with them
    let leftOut = new Set(); // keys of stops the last redraw didn't route through
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
          <button type="button" class="btn-sm btn-sm--teal" id="se-usual">Add usual stops along the route</button>
          <button type="button" class="btn-sm" id="se-terminals">Add stops at both terminals</button>
          <button type="button" class="btn-sm" id="se-redraw" title="Draw the road path through the stops in riding order">Redraw line through stops</button>
          <span id="se-count" class="op-card__sub" style="margin:auto 0;"></span>
        </div>
        <p id="se-offhint" class="op-card__sub" style="margin:0 0 8px;color:#B7791F;" hidden></p>
        <div id="se-list">${AdminUi.stateMessage('Loading…')}</div>`,
      actions: [
        { label: 'Cancel', variant: 'ghost', onClick: () => AdminModal.close() },
        { label: 'Save Stops', variant: 'primary', onClick: save },
      ],
      onClose: () => { if (map) map.remove(); },
    });

    const listEl = modal.querySelector('#se-list');
    const countEl = modal.querySelector('#se-count');
    const offHintEl = modal.querySelector('#se-offhint');

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

    function addStop(lat, lng, { id, name, landmark, shared = false } = {}) {
      const near = name ? null : nearestLandmark(lat, lng);
      const stop = {
        key: nextKey++, id, lat, lng,
        name: name || (near ? near.name : `Stop ${stops.length + 1}`),
        landmark: landmark ?? '',
        shared,
        marker: null,
      };
      if (map) {
        // A stop other routes use keeps its place: not draggable here.
        stop.marker = L.marker([lat, lng], { draggable: !shared, icon: stopIcon('+') }).addTo(map);
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
      const off = rows.filter((r) => r.off != null && r.off > OFF_ROUTE_WARN_M).length;
      offHintEl.hidden = !off;
      offHintEl.textContent = off
        ? `${off} ${off === 1 ? 'stop is' : 'stops are'} more than ${OFF_ROUTE_WARN_M} m from the route line, so commuters' trips are drawn and timed along the line, not past ${off === 1 ? 'it' : 'them'}. If the stops are where the jeepney really goes, click "Redraw line through stops".`
        : '';
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
                    <td><input class="se-name" data-key="${r.s.key}" maxlength="80" value="${esc(r.s.name)}" aria-label="Stop ${n + 1} name" style="width:100%;" ${r.s.shared ? 'readonly' : ''}></td>
                    <td><input class="se-landmark" data-key="${r.s.key}" maxlength="120" value="${esc(r.s.landmark)}" placeholder="e.g. across the church" aria-label="Stop ${n + 1} landmark" style="width:100%;" ${r.s.shared ? 'readonly' : ''}></td>
                    <td>${r.s.shared ? OperatorUi.chip('Shared with other routes', 'blue') : ''}${warn ? OperatorUi.chip(`${Math.round(r.off)} m off the route`, 'amber') : ''}${leftOut.has(r.s.key) ? `<span title="The line would have looped back to pass this stop going this way. It may be the stop for the other direction across the road, or out of order. Remove it if the jeep doesn't stop here.">${OperatorUi.chip('Left out of the line', 'amber')}</span>` : ''}</td>
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

    // The usual stops along the line (terminals, other routes' stops,
    // OpenStreetMap's jeepney stops), skipping any already placed nearby.
    modal.querySelector('#se-usual').addEventListener('click', async (e) => {
      const btn = e.currentTarget;
      btn.disabled = true;
      btn.textContent = 'Finding stops…';
      try {
        const suggested = await OperatorApi.stopSuggestions(route.id);
        let added = 0;
        for (const s of suggested) {
          const [lng, lat] = s.location.coordinates;
          if (s.id && stops.some((x) => x.id === s.id)) continue;
          if (stops.some((x) => metresBetween(x, { lat, lng }) < 60)) continue;
          addStop(lat, lng, { id: s.id, name: s.name, landmark: s.landmark || '', shared: s.source === 'existing' });
          added++;
        }
        render();
        AdminUi.toast(added
          ? `Added ${added} usual ${added === 1 ? 'stop' : 'stops'}. Remove any this route doesn't serve, then save.`
          : suggested.length ? 'The usual stops along this route are already on it.' : 'No known stops along this route yet. Click the map to add them.');
      } catch (err) {
        AdminUi.toast(err.message || 'Could not look up stops.', { error: true });
      } finally {
        btn.disabled = false;
        btn.textContent = 'Add usual stops along the route';
      }
    });

    // The road path through the stops in riding order (plus the line's ends
    // when they run past the first and last stop), replacing the line.
    modal.querySelector('#se-redraw').addEventListener('click', async (e) => {
      const btn = e.currentTarget;
      const rows = ordered();
      if (rows.length < 2) {
        AdminUi.toast('Place at least two stops first.');
        return;
      }
      const points = rows.map(({ s }) => ({ lat: s.lat, lng: s.lng }));
      const pointStop = rows.map(({ s }) => s);    // which stop each point is (null: a line end)
      if (line.length >= 2) {
        const start = { lat: line[0][0], lng: line[0][1] };
        const end = { lat: line[line.length - 1][0], lng: line[line.length - 1][1] };
        if (metresBetween(start, points[0]) > END_KEEP_M) { points.unshift(start); pointStop.unshift(null); }
        if (metresBetween(end, points[points.length - 1]) > END_KEEP_M) { points.push(end); pointStop.push(null); }
      }
      btn.disabled = true;
      btn.textContent = 'Drawing…';
      try {
        const drawn = await roadPathThrough(points);
        if (!drawn) throw new Error('no road path');
        let { path } = drawn;
        const skippedStops = drawn.skipped.map((i) => pointStop[i]).filter(Boolean);
        leftOut = new Set(skippedStops.map((s) => s.key));
        if (path.length > MAX_LINE_POINTS) {
          const step = Math.ceil(path.length / MAX_LINE_POINTS);
          path = path.filter((_, i) => i % step === 0 || i === path.length - 1);
        }
        line = path.map(([lng, lat]) => [lat, lng]);
        if (map) {
          if (lineLayer) lineLayer.setLatLngs(line);
          else lineLayer = L.polyline(line, { weight: 5, interactive: false }).addTo(map);
          lineLayer.setStyle({ color: '#27AE60', opacity: 0.8 });   // green: not saved yet
          map.fitBounds(lineLayer.getBounds(), { padding: [30, 30], maxZoom: 16 });
        }
        lineChanged = true;
        dirty = true;
        render();
        AdminUi.toast(skippedStops.length
          ? `Line redrawn. ${skippedStops.length} ${skippedStops.length === 1 ? 'stop' : 'stops'} left out so it doesn't loop back for them (marked below). Check the line, then save.`
          : `Line redrawn through ${rows.length} stops. Check it follows the jeepney's streets, then save.`);
      } catch {
        AdminUi.toast('Could not find a road path through the stops. Move any stop that is off the road, then try again.', { error: true });
      } finally {
        btn.disabled = false;
        btn.textContent = 'Redraw line through stops';
      }
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
      const geometry = lineChanged ? { type: 'LineString', coordinates: line.map(([lat, lng]) => [lng, lat]) } : null;
      const saved = await OperatorApi.setRouteStops(route.id, payload, geometry);   // errors show in the modal
      AdminUi.toast(`${route.code}: ${saved.stops.length} ${saved.stops.length === 1 ? 'stop' : 'stops'}${lineChanged ? ' and the new line' : ''} saved.`);
      dirty = false;
      lineChanged = false;
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
        lineLayer = L.polyline(line, { color: '#2E86AB', weight: 5, opacity: 0.6, interactive: false }).addTo(map);
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
        addStop(lat, lng, { id: s.id, name: s.name, landmark: s.landmark || '', shared: s.shared });
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
