import { CityEvents } from "../src/CityEvents.js";

const ASSET = (path) => `../assets/${path.replace(/^assets\//, "")}`;

async function loadJSON(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`No se pudo cargar ${path}`);
  return res.json();
}

const severityLabel = {
  low: "Baja",
  medium: "Media",
  high: "Alta",
  critical: "Crítica",
};

const unitLabel = {
  policia: "Policía",
  trafico: "Tráfico",
  swat: "SWAT",
  bomberos: "Bomberos",
  samur: "SAMUR",
  upr: "UPR",
  k9: "K9",
};

let city;
let selectedId = null;
let filterCategory = "all";
let categoryColor = {};

const els = {
  filters: document.getElementById("filters"),
  grid: document.getElementById("event-grid"),
  selectedArt: document.getElementById("selected-art"),
  selectedTitle: document.getElementById("selected-title"),
  selectedMeta: document.getElementById("selected-meta"),
  selectedStats: document.getElementById("selected-stats"),
  btnDispatch: document.getElementById("btn-dispatch"),
  btnWeather: document.getElementById("btn-weather"),
  btnRandom: document.getElementById("btn-random"),
  btnClear: document.getElementById("btn-clear"),
  activeList: document.getElementById("active-list"),
  activeCount: document.getElementById("active-count"),
  weatherLine: document.getElementById("weather-line"),
};

function renderFilters() {
  const chips = [
    { id: "all", name: "Todos", color: "#2f8cff" },
    ...city.listCategories().map((c) => ({ id: c.id, name: c.name, color: c.color })),
  ];
  categoryColor = Object.fromEntries(chips.map((c) => [c.id, c.color]));
  els.filters.innerHTML = "";
  for (const chip of chips) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `filter${filterCategory === chip.id ? " active" : ""}`;
    btn.style.setProperty("--cat", chip.color);
    btn.textContent = chip.name;
    btn.addEventListener("click", () => {
      filterCategory = chip.id;
      renderFilters();
      renderGrid();
    });
    els.filters.appendChild(btn);
  }
}

function renderGrid() {
  const events =
    filterCategory === "all"
      ? city.listEvents()
      : city.listEvents({ category: filterCategory });
  els.grid.innerHTML = "";
  events.forEach((event, i) => {
    const cat = city.listCategories().find((c) => c.id === event.category);
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `tile${selectedId === event.id ? " selected" : ""}`;
    btn.style.setProperty("--cat", cat?.color || "#2f8cff");
    btn.style.animationDelay = `${Math.min(i, 24) * 12}ms`;
    btn.innerHTML = `
      <span class="sev ${event.severity}" title="${severityLabel[event.severity]}"></span>
      <img src="${ASSET(event.file)}" alt="${event.name}" loading="lazy" />
      <span class="label">${event.name}</span>
    `;
    btn.addEventListener("click", () => selectEvent(event.id));
    els.grid.appendChild(btn);
  });
}

function selectEvent(id) {
  selectedId = id;
  const event = city.get(id);
  const cat = city.listCategories().find((c) => c.id === event.category);
  els.selectedArt.innerHTML = `<img src="${ASSET(event.file)}" alt="${event.name}" />`;
  els.selectedTitle.textContent = event.name;
  els.selectedMeta.textContent = `${cat?.name || event.category} · ${cat?.tagline || ""}`;
  els.selectedStats.innerHTML = `
    <div><dt>Severidad</dt><dd>${severityLabel[event.severity]}</dd></div>
    <div><dt>XP</dt><dd>${event.xp}</dd></div>
    <div><dt>Duración</dt><dd>${event.durationSec ? `${event.durationSec}s` : "Continuo"}</dd></div>
    <div><dt>Unidades</dt><dd>${
      event.units.length
        ? event.units.map((u) => unitLabel[u] || u).join(", ")
        : "—"
    }</dd></div>
  `;
  els.btnDispatch.disabled = !event.dispatchable;
  els.btnWeather.disabled = !event.weather;
  renderGrid();
}

function renderActive() {
  const missions = city.activeMissions();
  els.activeCount.textContent = String(missions.length);
  const weather = city.currentWeather();
  els.weatherLine.textContent = `Clima: ${weather?.name || "—"}`;

  if (!missions.length) {
    els.activeList.innerHTML = `<p class="empty">Sin misiones activas. Despacha un evento para empezar.</p>`;
    return;
  }

  els.activeList.innerHTML = "";
  for (const mission of missions) {
    const li = document.createElement("li");
    li.innerHTML = `
      <img src="${ASSET(mission.event.file)}" alt="" />
      <div>
        <strong>${mission.event.name}</strong>
        <span>${mission.location} · ${mission.units.map((u) => unitLabel[u] || u).join(", ") || "sin unidades"}</span>
      </div>
      <button type="button" data-id="${mission.instanceId}">Resolver</button>
    `;
    li.querySelector("button").addEventListener("click", () => {
      city.resolve(mission.instanceId, { success: true });
      renderActive();
    });
    els.activeList.appendChild(li);
  }
}

els.btnDispatch.addEventListener("click", () => {
  if (!selectedId) return;
  city.dispatch(selectedId);
  renderActive();
});

els.btnWeather.addEventListener("click", () => {
  if (!selectedId) return;
  city.setWeather(selectedId);
  renderActive();
});

els.btnRandom.addEventListener("click", () => {
  const category = filterCategory === "all" ? null : filterCategory;
  const instance = city.dispatchRandom({ category });
  if (instance?.event) selectEvent(instance.event.id);
  renderActive();
});

els.btnClear.addEventListener("click", () => {
  for (const mission of [...city.activeMissions()]) {
    city.resolve(mission.instanceId, { success: false });
  }
  renderActive();
});

async function boot() {
  const [catalog, categories] = await Promise.all([
    loadJSON("../data/events.json"),
    loadJSON("../data/event_categories.json"),
  ]);
  city = new CityEvents({ catalog, categories });
  renderFilters();
  renderGrid();
  renderActive();
  selectEvent("atraco_a_banco");
}

boot().catch((err) => {
  console.error(err);
  document.body.insertAdjacentHTML(
    "beforeend",
    `<p style="padding:1rem;color:#ff8a8a">Error: ${err.message}. Sirve el repo con un servidor HTTP estático.</p>`
  );
});
