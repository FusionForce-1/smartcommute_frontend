// js/operator/routePicker.js
//
// Origin → Destination picker for "Create New Route": a map where the
// operator drops pin A (origin) and pin B (destination), drags them to
// adjust, or searches when they can't find the spot.
//
//  * Click the map: places the pin being set (A first, then B).
//  * Drag a pin: moves it; the place name is looked up again.
//  * Type in a box: matching stops appear instantly; Enter / Search looks
//    the place up on OpenStreetMap (Nominatim), inside the Philippines,
//    nearest the area on screen first.
//  * With both pins down, the road path between them is drawn (OSRM) and
//    can be saved as the route's line, so the route shows up on the
//    commuter map right away.
//
// Nominatim's usage policy: no search-as-you-type and at most one request
// a second — searches only run on Enter / Search, through a 1 s queue.

const RoutePicker = (() => {
  const esc = (s) => AdminUi.escapeHtml(String(s ?? ''));
  const NOMINATIM = 'https://nominatim.openstreetmap.org';
  const OSRM = 'https://router.project-osrm.org/route/v1/driving';
  const CEBU = [10.3157, 123.8854];
  const PH_BOUNDS = [[4.4, 116.9], [21.3, 127.0]];
  const MAX_LINE_POINTS = 5000;
  const SIDES = {
    a: { label: 'Origin', letter: 'A', color: '#1E8E5A', placeholder: 'Starting terminal — type to search, or click the map' },
    b: { label: 'Destination', letter: 'B', color: '#C8372D', placeholder: 'End terminal — type to search, or click the map' },
  };

  // ---------- Nominatim, one request a second ----------

  let lastCall = 0;
  async function nominatim(path, params) {
    const wait = lastCall + 1100 - Date.now();
    if (wait > 0) await new Promise((r) => setTimeout(r, wait));
    lastCall = Date.now();
    const url = `${NOMINATIM}/${path}?${new URLSearchParams({ format: 'jsonv2', 'accept-language': 'en', ...params })}`;
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!res.ok) throw new Error('Place search is busy — try again in a moment.');
    return res.json();
  }

  /** "Carbon Market, Cebu City" from a Nominatim result. */
  function placeLabel(r) {
    const a = r.address || {};
    const what = r.name || a.amenity || a.building || a.shop || a.tourism || a.road || a.neighbourhood;
    const where = a.suburb || a.village || a.quarter || a.city_district || a.neighbourhood || a.town || a.city;
    const city = a.city || a.town || a.municipality;
    const parts = [what, where, where !== city ? city : null].filter(Boolean);
    const unique = parts.filter((p, i) => parts.indexOf(p) === i);
    return (unique.length ? unique : String(r.display_name || '').split(',').slice(0, 2).map((s) => s.trim()))
      .join(', ').slice(0, 80);
  }

  function pinIcon(side) {
    const s = SIDES[side];
    return L.divIcon({
      className: '',
      html: `<div style="width:30px;height:30px;border-radius:50% 50% 50% 0;transform:rotate(-45deg);background:${s.color};
               border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;">
               <span style="transform:rotate(45deg);color:#fff;font-weight:700;font-size:13px;">${s.letter}</span></div>`,
      iconSize: [30, 30],
      iconAnchor: [15, 30],
    });
  }

  /**
   * Builds the picker inside `container`. `onChange()` fires whenever a pin,
   * a name or the path changes. Returns { value(), destroy() }.
   */
  function mount(container, { onChange = () => {} } = {}) {
    const state = {
      a: { name: '', latlng: null, auto: false, marker: null },
      b: { name: '', latlng: null, auto: false, marker: null },
      target: 'a',          // which pin a map click places
      path: null,           // [[lng, lat], ...]: by road, or the straight line if no road was found
      vias: [],             // points the route must pass through, in order: { latlng, marker }
    };
    let stops = [];
    let pathLine = null;    // the road path (solid blue)
    let straightLine = null; // A -> via points -> B (dashed): shown at once, follows drags live
    let pathTimer = null;
    let pathRequest = 0;

    container.innerHTML = `
      <div class="rp">
        ${['a', 'b'].map((side) => `
          <div class="rp-field" data-side="${side}">
            <label for="rp-${side}"><span class="rp-dot" style="background:${SIDES[side].color}">${SIDES[side].letter}</span>${SIDES[side].label}</label>
            <div class="rp-row">
              <input id="rp-${side}" maxlength="80" placeholder="${esc(SIDES[side].placeholder)}" autocomplete="off" />
              <button type="button" class="btn-sm" data-search="${side}">Search</button>
              <button type="button" class="btn-sm" data-pin="${side}" title="Click the map to place it">Pin on map</button>
            </div>
            <ul class="rp-suggest" id="rp-suggest-${side}" hidden></ul>
          </div>`).join('')}
        <div class="rp-bar">
          <span id="rp-hint" class="rp-hint"></span>
          <button type="button" class="btn-sm" id="rp-swap" title="Swap origin and destination">⇄ Swap</button>
        </div>
        <div id="rp-map" class="rp-map" role="region" aria-label="Map: click to place the origin and destination"></div>
        <label class="rp-path" id="rp-path" hidden>
          <input type="checkbox" id="rp-save-path" checked />
          <span><span id="rp-path-what">Save this road path as the route line</span> <span id="rp-path-info" class="op-card__sub"></span><br>
            <span class="op-card__sub">So commuters see the route on the map right away. You can refine it later.</span></span>
        </label>
      </div>`;

    const $ = (sel) => container.querySelector(sel);
    const map = L.map($('#rp-map'), { maxBounds: PH_BOUNDS, minZoom: 5 }).setView(CEBU, 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map);
    // The form slides in; let Leaflet measure its box once it's laid out.
    setTimeout(() => map.invalidateSize(), 0);

    ApiClient.get('/stops').then((list) => { stops = Array.isArray(list) ? list : []; }).catch(() => {});

    // ---------- Pins ----------

    function hint() {
      const missing = ['a', 'b'].filter((s) => !state[s].latlng);
      $('#rp-hint').innerHTML = missing.length
        ? `Click the map to place the <strong style="color:${SIDES[state.target].color}">${SIDES[state.target].label} (${SIDES[state.target].letter})</strong> — or search above.`
        : 'Drag a pin to adjust it. <strong>Click the blue line</strong> to add a point the route passes through, then drag it onto the right street (click it again to remove).';
      container.querySelectorAll('[data-pin]').forEach((b) => b.classList.toggle('btn-sm--teal', b.dataset.pin === state.target && missing.length > 0));
    }

    function setPoint(side, latlng, { name, auto = true, pan = false } = {}) {
      const s = state[side];
      s.latlng = L.latLng(latlng);
      if (!s.marker) {
        s.marker = L.marker(s.latlng, { icon: pinIcon(side), draggable: true, keyboard: true, title: SIDES[side].label }).addTo(map);
        s.marker.on('drag', () => {
          s.latlng = s.marker.getLatLng();
          drawStraight();                  // the line follows the pin while dragging
        });
        s.marker.on('dragend', () => {
          s.latlng = s.marker.getLatLng();
          lookUpName(side);
          planPath({ fit: true });
          onChange();
        });
      } else {
        s.marker.setLatLng(s.latlng);
      }
      if (name !== undefined) {
        s.name = name;
        s.auto = auto;
        $(`#rp-${side}`).value = name;
      } else {
        lookUpName(side);
      }
      if (pan) map.setView(s.latlng, Math.max(map.getZoom(), 16));
      // Next click places the other pin if it's still missing.
      const other = side === 'a' ? 'b' : 'a';
      state.target = state[other].latlng ? side : other;
      hint();
      planPath({ fit: true });
      onChange();
    }

    /** Fills the box with the place name at the pin, unless the operator typed their own. */
    async function lookUpName(side) {
      const s = state[side];
      if (s.name && !s.auto) return;
      const at = s.latlng;
      try {
        const r = await nominatim('reverse', { lat: at.lat, lon: at.lng, zoom: 17, addressdetails: 1 });
        if (!s.latlng || !s.latlng.equals(at)) return;   // moved again meanwhile
        if (s.name && !s.auto) return;
        s.name = placeLabel(r) || `${at.lat.toFixed(5)}, ${at.lng.toFixed(5)}`;
        s.auto = true;
        $(`#rp-${side}`).value = s.name;
        onChange();
      } catch {
        if (!s.name) {
          s.name = `${at.lat.toFixed(5)}, ${at.lng.toFixed(5)}`;
          s.auto = true;
          $(`#rp-${side}`).value = s.name;
          onChange();
        }
      }
    }

    map.on('click', (e) => setPoint(state.target, e.latlng));

    // ---------- The line from Origin to Destination ----------
    //
    // Dashed: straight from A through the via points to B, drawn the moment
    // both pins exist. Solid blue: the road path through the same points
    // (OSRM). If no road path is found, the dashed line is what's saved.

    const MAX_VIAS = 8;
    const chain = () => [state.a.latlng, ...state.vias.map((v) => v.latlng), state.b.latlng];

    function drawStraight() {
      if (!state.a.latlng || !state.b.latlng) {
        if (straightLine) { straightLine.remove(); straightLine = null; }
        return;
      }
      const points = chain();
      if (!straightLine) {
        straightLine = L.polyline(points, { color: '#5B6770', weight: 3, dashArray: '8 8', opacity: 0.9, interactive: false }).addTo(map);
      } else {
        straightLine.setLatLngs(points);
      }
      straightLine.setStyle({ opacity: pathLine ? 0.35 : 0.9 });
    }

    function clearPath() {
      state.path = null;
      if (pathLine) { pathLine.remove(); pathLine = null; }
      drawStraight();
      $('#rp-path').hidden = true;
    }

    function kmBetween(points) {
      let m = 0;
      for (let i = 1; i < points.length; i++) m += map.distance(points[i - 1], points[i]);
      return (m / 1000).toFixed(1);
    }

    /** No road path: the straight line (through the via points) is offered instead. */
    function useStraightLine(note) {
      if (pathLine) { pathLine.remove(); pathLine = null; }
      drawStraight();
      state.path = chain().map((p) => [p.lng, p.lat]);
      $('#rp-path-what').textContent = 'Save this straight line as the route line';
      $('#rp-path-info').textContent = `(≈ ${kmBetween(chain())} km — ${note})`;
      $('#rp-path').hidden = false;
    }

    function planPath({ fit = false } = {}) {
      clearTimeout(pathTimer);
      drawStraight();
      if (!state.a.latlng || !state.b.latlng) {
        clearPath();
        return;
      }
      pathTimer = setTimeout(async () => {
        const id = ++pathRequest;
        const points = chain();
        try {
          const coordList = points.map((p) => `${p.lng},${p.lat}`).join(';');
          const res = await fetch(`${OSRM}/${coordList}?overview=full&geometries=geojson`);
          const data = await res.json();
          if (id !== pathRequest) return;   // pins moved since
          const route = data.routes?.[0];
          if (!route) throw new Error('no road path');
          let coords = route.geometry.coordinates;
          if (coords.length > MAX_LINE_POINTS) {
            const step = Math.ceil(coords.length / MAX_LINE_POINTS);
            coords = coords.filter((_, i) => i % step === 0 || i === coords.length - 1);
          }
          state.path = coords;
          if (pathLine) pathLine.remove();
          pathLine = L.polyline(coords.map(([lng, lat]) => [lat, lng]), { color: '#2E86AB', weight: 6, opacity: 0.85 }).addTo(map);
          pathLine.on('click', (e) => { L.DomEvent.stop(e); addVia(e.latlng); });
          drawStraight();
          if (fit) map.fitBounds(pathLine.getBounds(), { padding: [30, 30], maxZoom: 16 });
          const km = (route.distance / 1000).toFixed(1);
          const min = Math.max(1, Math.round(route.duration / 60));
          const via = state.vias.length ? `, via ${state.vias.length} point${state.vias.length > 1 ? 's' : ''}` : '';
          $('#rp-path-what').textContent = 'Save this road path as the route line';
          $('#rp-path-info').textContent = `(≈ ${km} km · ${min} min by road${via})`;
          $('#rp-path').hidden = false;
        } catch {
          if (id !== pathRequest) return;
          useStraightLine('no road path found');
          if (fit) map.fitBounds(L.latLngBounds(chain()), { padding: [30, 30], maxZoom: 16 });
        }
        onChange();
      }, 400);
    }

    // ---------- Via points: reshape the path ----------

    function viaIcon() {
      return L.divIcon({
        className: '',
        html: '<div style="width:16px;height:16px;border-radius:50%;background:#fff;border:3px solid #2E86AB;box-shadow:0 1px 3px rgba(0,0,0,.4);"></div>',
        iconSize: [16, 16],
        iconAnchor: [8, 8],
      });
    }

    /** Inserts a via point into the stretch of A -> ... -> B it is closest to. */
    function addVia(latlng) {
      if (state.vias.length >= MAX_VIAS) {
        $('#rp-hint').textContent = `Up to ${MAX_VIAS} points — remove one (click it) to add another.`;
        return;
      }
      const pts = chain().map((p) => map.latLngToLayerPoint(p));
      const click = map.latLngToLayerPoint(latlng);
      let best = 0;
      let bestDist = Infinity;
      for (let i = 0; i < pts.length - 1; i++) {
        const d = L.LineUtil.pointToSegmentDistance(click, pts[i], pts[i + 1]);
        if (d < bestDist) { bestDist = d; best = i; }
      }
      const via = { latlng: L.latLng(latlng), marker: null };
      via.marker = L.marker(via.latlng, { icon: viaIcon(), draggable: true, zIndexOffset: 500, title: 'Drag to change streets · click to remove' }).addTo(map);
      via.marker.on('drag', () => { via.latlng = via.marker.getLatLng(); drawStraight(); });
      via.marker.on('dragend', () => { via.latlng = via.marker.getLatLng(); planPath(); onChange(); });
      via.marker.on('click', () => removeVia(via));
      state.vias.splice(best, 0, via);   // between chain points `best` and `best + 1`
      planPath();
      onChange();
    }

    function removeVia(via) {
      via.marker.remove();
      state.vias = state.vias.filter((v) => v !== via);
      planPath();
      onChange();
    }

    // ---------- Typing and searching ----------

    function showSuggestions(side, items, note = '') {
      const ul = $(`#rp-suggest-${side}`);
      ul.innerHTML = items.map((it, i) => `
        <li><button type="button" data-pick="${side}" data-i="${i}">
          <strong>${esc(it.label)}</strong>${it.detail ? `<span>${esc(it.detail)}</span>` : ''}</button></li>`).join('')
        + (note ? `<li class="rp-note">${esc(note)}</li>` : '');
      ul.hidden = !items.length && !note;
      ul._items = items;
    }

    function stopMatches(text) {
      const q = text.trim().toLowerCase();
      if (q.length < 2) return [];
      return stops
        .filter((s) => s.name?.toLowerCase().includes(q) && s.location?.coordinates)
        .slice(0, 5)
        .map((s) => ({ label: s.name, detail: 'Your stop', lat: s.location.coordinates[1], lng: s.location.coordinates[0] }));
    }

    async function searchPlaces(side) {
      const text = $(`#rp-${side}`).value.trim();
      if (text.length < 3) {
        showSuggestions(side, stopMatches(text), 'Type at least 3 letters, then press Search.');
        return;
      }
      showSuggestions(side, stopMatches(text), 'Searching places…');
      const b = map.getBounds();
      try {
        const results = await nominatim('search', {
          q: text, countrycodes: 'ph', limit: 6, addressdetails: 1,
          viewbox: [b.getWest(), b.getNorth(), b.getEast(), b.getSouth()].join(','), bounded: 0,
        });
        const places = results.map((r) => ({
          label: placeLabel(r), detail: String(r.display_name || '').split(',').slice(1, 4).join(',').trim(),
          lat: Number(r.lat), lng: Number(r.lon),
        }));
        // OSM often has several entries with one name (a district, its
        // boundary, a landmark): show each name once.
        const seen = new Set();
        const all = [...stopMatches(text), ...places].filter((p) => {
          const key = p.label.toLowerCase();
          if (seen.has(key)) return false;
          seen.add(key);
          return true;
        });
        showSuggestions(side, all, all.length ? '' : `Nothing found for “${text}”. Try a nearby landmark, or click the map.`);
      } catch (err) {
        showSuggestions(side, stopMatches(text), err.message);
      }
    }

    container.addEventListener('input', (e) => {
      const side = e.target.id === 'rp-a' ? 'a' : e.target.id === 'rp-b' ? 'b' : null;
      if (!side) return;
      state[side].name = e.target.value.trim();
      state[side].auto = false;                       // their own wording wins
      const matches = stopMatches(e.target.value);
      showSuggestions(side, matches, e.target.value.trim().length >= 3 ? 'Press Enter to search all places.' : '');
      onChange();
    });

    container.addEventListener('keydown', (e) => {
      const side = e.target.id === 'rp-a' ? 'a' : e.target.id === 'rp-b' ? 'b' : null;
      if (!side) return;
      if (e.key === 'Enter') {
        e.preventDefault();                           // don't submit the route form
        searchPlaces(side);
      } else if (e.key === 'Escape') {
        showSuggestions(side, []);
      }
    });

    container.addEventListener('click', (e) => {
      const btn = e.target.closest('button');
      if (!btn) return;
      if (btn.dataset.search) searchPlaces(btn.dataset.search);
      if (btn.dataset.pin) {
        state.target = btn.dataset.pin;
        $('#rp-hint').innerHTML = `Click the map to place the <strong style="color:${SIDES[state.target].color}">${SIDES[state.target].label} (${SIDES[state.target].letter})</strong>.`;
        container.querySelectorAll('[data-pin]').forEach((b) => b.classList.toggle('btn-sm--teal', b === btn));
        $('#rp-map').scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      }
      if (btn.dataset.pick) {
        const side = btn.dataset.pick;
        const it = $(`#rp-suggest-${side}`)._items[Number(btn.dataset.i)];
        showSuggestions(side, []);
        setPoint(side, [it.lat, it.lng], { name: it.label, auto: false, pan: true });
      }
      if (btn.id === 'rp-swap') {
        const { a, b } = state;
        [a.name, b.name] = [b.name, a.name];
        [a.auto, b.auto] = [b.auto, a.auto];
        [a.latlng, b.latlng] = [b.latlng, a.latlng];
        state.vias.reverse();
        for (const side of ['a', 'b']) {
          const s = state[side];
          $(`#rp-${side}`).value = s.name;
          if (s.latlng) {
            if (s.marker) s.marker.setLatLng(s.latlng);
            else setPoint(side, s.latlng, { name: s.name, auto: s.auto });
          } else if (s.marker) {
            s.marker.remove();
            s.marker = null;
          }
        }
        hint();
        planPath({ fit: true });
        onChange();
      }
    });

    // Close suggestion lists when clicking elsewhere.
    const closeLists = (e) => {
      if (!container.contains(e.target) || e.target.closest('.rp-map')) {
        showSuggestions('a', []);
        showSuggestions('b', []);
      }
    };
    document.addEventListener('mousedown', closeLists);

    hint();

    return {
      /** { origin, destination: {name, lng, lat}|null, path: [[lng,lat],...]|null } */
      value() {
        const point = (s) => (s.latlng ? { name: s.name, lng: s.latlng.lng, lat: s.latlng.lat } : null);
        return {
          origin: point(state.a) || (state.a.name ? { name: state.a.name } : null),
          destination: point(state.b) || (state.b.name ? { name: state.b.name } : null),
          path: state.path && $('#rp-save-path').checked ? state.path : null,
        };
      },
      destroy() {
        document.removeEventListener('mousedown', closeLists);
        clearTimeout(pathTimer);
        map.remove();
      },
    };
  }

  return { mount };
})();
