import { generateWorld, TILE, TILE_META, tileAt } from "./world.js";
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
  MAX_HEALTH,
  invCapacity,
  invUsed,
} from "./game.js";
import { createRenderer } from "./render.js";
import { createAudio } from "./audio.js";

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
const inventoryGridEl = document.getElementById("inventory-grid");
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
let audio = createAudio();
let last = 0;
let raf = 0;
let hudKey = "";

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
  const q = new URLSearchParams(location.search);
  const seedParam = Number(q.get("seed"));
  const seed = Number.isFinite(seedParam) && seedParam > 0 ? (seedParam | 0) : undefined;
  const world = generateWorld(96, seed);
  game = createGame(world);
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
  bindMouse(game);
  bindHudClicks();
  audio.unlock();
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

function bindMouse(g) {
  const canvas = document.getElementById("world");
  if (!canvas) return;
  canvas.style.cursor = "crosshair";

  const syncPos = (e) => {
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    g.mouse.x = x;
    g.mouse.y = y;
    g.mouse.viewW = rect.width;
    g.mouse.viewH = rect.height;
    // Cámara centrada en el jugador
    g.mouse.worldX = (g.camX ?? g.player.x) + (x - rect.width / 2) / 48;
    g.mouse.worldY = (g.camY ?? g.player.y) + (y - rect.height / 2) / 48;
  };

  canvas.onmousemove = (e) => syncPos(e);
  canvas.onmousedown = (e) => {
    if (e.button !== 0) return;
    e.preventDefault();
    syncPos(e);
    g.mouse.down = true;
    g.mouse.clicked = true;
  };
  window.onmouseup = (e) => {
    if (e.button === 0) g.mouse.down = false;
  };
  canvas.oncontextmenu = (e) => e.preventDefault();
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
    const slot = btn.dataset.equip;
    if (slot === "hand" && game.player.equip.hand) {
      game.player.equip.hand = null;
      setToast(game, "Mano primaria libre.");
    } else if (slot === "body" && game.player.equip.body) {
      setToast(game, `Te quitas ${game.player.equip.body}.`);
      // better label via toast after null
      const id = game.player.equip.body;
      game.player.equip.body = null;
      setToast(game, "Ropa guardada. T para cambiar.");
    } else if (slot === "bag" && game.player.equip.bag) {
      const prev = game.player.equip.bag;
      game.player.equip.bag = null;
      if (invUsed(game.player) > invCapacity(game.player)) {
        game.player.equip.bag = prev;
        setToast(game, "Vacía la mochila antes de quitártela.");
      } else {
        setToast(game, "Mochila guardada.");
      }
    } else if (slot === "light" && game.player.equip.light) {
      game.player.equip.light = null;
      setToast(game, "Luz guardada.");
    }
  };
}

function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  if (!game) return;

  const tile = tileAt(game.world, game.player.x, game.player.y);
  game._audioIndoor = Boolean(TILE_META[tile]?.indoor) || tile === TILE.DOOR;
  audio.update(game, dt);
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
  // Barras: baratas, cada frame
  setBar(bars.health, (p.health / (p.maxHealth || MAX_HEALTH)) * 100);
  setBar(bars.hunger, p.hunger);
  setBar(bars.thirst, p.thirst);
  setBar(bars.stamina, p.stamina);

  const phase = dayPhase(g);
  const seed = g.world.seed.toString(36).slice(0, 5);
  const weather = phase.weatherLabel ? ` · ${phase.weatherLabel}` : "";
  const wave = waveStatus(g);
  const toastOn = g.toastT > 0 && g.toast ? g.toast : "";
  const hot = hotbarSlots(g);
  const eq = equipPanel(g);
  const hotSig = hot.map((s) => `${s.icon}|${s.label}|${s.ammo ?? ""}|${s.active ? 1 : 0}`).join(";");
  const eqSig = eq.map((s) => `${s.slot}|${s.icon}|${s.label}|${s.stat || ""}`).join(";");
  const invSig = g.inventoryOpen ? inventorySlots(g).map((s) => `${s.kind}:${s.n}:${s.label}`).join(";") : "";
  const key = `${phase.name}|${weather}|${g.kills}|${wave}|${g.buildMode || ""}|${hotSig}|${eqSig}|${g.inventoryOpen ? 1 : 0}|${invSig}|${toastOn}|${seed}`;
  const clockKey = `${phase.clock}|${phase.name}|${weather}|${seed}`;

  // Reloj: barato, se actualiza al cambiar minuto/fase
  if (clockKey !== (syncHud._clockKey || "")) {
    syncHud._clockKey = clockKey;
    clockEl.textContent = `${phase.clock || ""} · ${phase.name}${weather} · Niebla Norte #${seed}`;
  }

  // Texto de bajas / paneles: solo si cambia la firma relevante
  if (key !== hudKey) {
    hudKey = key;
    if (killsEl) killsEl.textContent = `${g.kills} bajas · ${wave}`;

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

    hotbarEl.innerHTML = hot
      .map(
        (s) => `<button type="button" class="hot-slot${s.active ? " active" : ""}${s.empty ? " empty" : ""}${s.legendary ? " legendary" : ""}" data-hot="${s.index}">
        <span class="hot-key">${s.key}</span>
        <span class="hot-icon">${s.icon || "·"}</span>
        <span class="hot-label">${s.legendary ? "★ " : ""}${s.label || "—"}</span>
        ${s.ammo != null ? `<span class="hot-ammo">${s.ammo}</span>` : ""}
      </button>`
      )
      .join("");

    equipEl.innerHTML = eq
      .map(
        (s) => `<button type="button" class="equip-slot${s.empty ? " empty" : ""}${s.primary ? " primary" : ""}" data-equip="${s.slot}">
        <span class="slot-tag">${s.tag}</span>
        <span class="slot-icon">${s.icon}</span>
        <span class="slot-name">${s.label}</span>
        <span class="slot-stat">${s.stat || ""}</span>
      </button>`
      )
      .join("");

    if (inventoryEl) inventoryEl.hidden = !g.inventoryOpen;
    if (inventoryGridEl && g.inventoryOpen) {
      inventoryGridEl.innerHTML = inventorySlots(g)
        .map((s) => `<div class="inv-slot inv-${s.kind}"><strong>${s.n}</strong>${s.label}</div>`)
        .join("");
    }

    if (toastOn) {
      toastEl.hidden = false;
      toastEl.textContent = toastOn;
    } else {
      toastEl.hidden = true;
    }
  }
}

function setBar(el, value) {
  if (!el) return;
  const v = Math.max(0, Math.min(100, value));
  const rounded = (v * 4 + 0.5) | 0; // ~0.25% steps — evita layout thrash
  if (el._barV === rounded) return;
  el._barV = rounded;
  el.style.setProperty("--v", `${v}%`);
}

startBtn.addEventListener("click", start);
retryBtn.addEventListener("click", start);

if (new URLSearchParams(location.search).has("auto")) start();
