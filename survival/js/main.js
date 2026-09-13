import { generateWorld } from "./world.js";
import {
  createGame,
  updateGame,
  dayPhase,
  inventorySlots,
  hotbarSlots,
  equipPanel,
  equipHotbarSlot,
  waveStatus,
  setToast,
} from "./game.js";
import { createRenderer } from "./render.js";

const boot = document.getElementById("boot");
const death = document.getElementById("death");
const gameRoot = document.getElementById("game");
const startBtn = document.getElementById("start-btn");
const retryBtn = document.getElementById("retry-btn");
const controlsBtn = document.getElementById("controls-btn");
const controlsPanel = document.getElementById("controls-panel");
const clockEl = document.getElementById("clock");
const toastEl = document.getElementById("toast");
const inventoryEl = document.getElementById("inventory");
const hotbarEl = document.getElementById("hotbar");
const equipEl = document.getElementById("equip-panel");
const deathReason = document.getElementById("death-reason");
const buildEl = document.getElementById("build-mode");
const killsEl = document.getElementById("kills");

const bars = {
  health: document.getElementById("bar-health"),
  hunger: document.getElementById("bar-hunger"),
  thirst: document.getElementById("bar-thirst"),
  stamina: document.getElementById("bar-stamina"),
};

let game = null;
let renderer = null;
let last = 0;
let raf = 0;

controlsBtn?.addEventListener("click", () => {
  const open = controlsPanel.hasAttribute("hidden");
  if (open) {
    controlsPanel.removeAttribute("hidden");
    controlsBtn.setAttribute("aria-expanded", "true");
  } else {
    controlsPanel.setAttribute("hidden", "");
    controlsBtn.setAttribute("aria-expanded", "false");
  }
});

function start() {
  const world = generateWorld(96);
  game = createGame(world);
  // Un bate al empezar para probar hotbar estilo PZ
  game.player.inv.bat = (game.player.inv.bat || 0) + 1;
  window.__crespo = game;
  boot.hidden = true;
  death.hidden = true;
  gameRoot.hidden = false;

  if (!renderer) {
    renderer = createRenderer(
      document.getElementById("world"),
      document.getElementById("minimap")
    );
  }

  bindKeys(game);
  bindHudClicks();
  last = performance.now();
  cancelAnimationFrame(raf);
  raf = requestAnimationFrame(loop);
}

function bindKeys(g) {
  const down = (e) => {
    const k = e.key.toLowerCase();
    if (
      [" ", "arrowup", "arrowdown", "arrowleft", "arrowright", "enter"].includes(k) ||
      k.length === 1
    ) {
      e.preventDefault();
    }
    if (!g.keys.has(k)) g.justPressed.add(k);
    g.keys.add(k);
  };
  const up = (e) => g.keys.delete(e.key.toLowerCase());
  window.onkeydown = down;
  window.onkeyup = up;
}

function bindHudClicks() {
  hotbarEl.onclick = (e) => {
    const btn = e.target.closest("[data-hot]");
    if (!btn || !game) return;
    equipHotbarSlot(game, Number(btn.dataset.hot));
  };
  equipEl.onclick = (e) => {
    const btn = e.target.closest("[data-equip]");
    if (!btn || !game) return;
    if (btn.dataset.equip === "hand" && game.player.equip.hand) {
      game.player.equip.hand = null;
      setToast(game, "Mano primaria libre.");
    }
  };
}

function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  if (!game) return;

  updateGame(game, dt);
  renderer.draw(game);
  syncHud(game);

  if (game.dead) {
    death.hidden = false;
    deathReason.textContent = game.deathReason;
  }

  raf = requestAnimationFrame(loop);
}

function syncHud(g) {
  const p = g.player;
  setBar(bars.health, p.health);
  setBar(bars.hunger, p.hunger);
  setBar(bars.thirst, p.thirst);
  setBar(bars.stamina, p.stamina);

  const phase = dayPhase(g);
  const seed = g.world.seed.toString(36).slice(0, 5);
  const weather = phase.weatherLabel ? ` · ${phase.weatherLabel}` : "";
  clockEl.textContent = `${phase.name}${weather} · Niebla Norte #${seed}`;
  if (killsEl) killsEl.textContent = `${g.kills} bajas · ${waveStatus(g)}`;

  if (buildEl) {
    if (g.buildMode) {
      buildEl.hidden = false;
      buildEl.textContent =
        g.buildMode === "wall"
          ? "Modo: BARRICADA (Enter)"
          : g.buildMode === "door"
            ? "Modo: PUERTA (Enter)"
            : "Modo: MARCAR BASE (Enter)";
    } else {
      buildEl.hidden = true;
    }
  }

  hotbarEl.innerHTML = hotbarSlots(g)
    .map(
      (s) => `<button type="button" class="hot-slot${s.active ? " active" : ""}${s.empty ? " empty" : ""}" data-hot="${s.index}">
        <span class="hot-key">${s.key}</span>
        <span class="hot-icon">${s.icon || "·"}</span>
        <span class="hot-label">${s.label || "—"}</span>
      </button>`
    )
    .join("");

  equipEl.innerHTML = equipPanel(g)
    .map(
      (s) => `<button type="button" class="equip-slot${s.empty ? " empty" : ""}${s.primary ? " primary" : ""}" data-equip="${s.slot}">
        <span class="slot-tag">${s.tag}</span>
        <span class="slot-icon">${s.icon}</span>
        <span class="slot-name">${s.label}</span>
        <span class="slot-stat">${s.stat || ""}</span>
      </button>`
    )
    .join("");

  inventoryEl.innerHTML = inventorySlots(g)
    .map((s) => `<div class="inv-slot inv-${s.kind}"><strong>${s.n}</strong>${s.label}</div>`)
    .join("");

  if (g.toastT > 0 && g.toast) {
    toastEl.hidden = false;
    toastEl.textContent = g.toast;
  } else {
    toastEl.hidden = true;
  }
}

function setBar(el, value) {
  if (!el) return;
  el.style.setProperty("--v", `${Math.max(0, Math.min(100, value))}%`);
}

startBtn.addEventListener("click", start);
retryBtn.addEventListener("click", start);

if (new URLSearchParams(location.search).has("auto")) start();
