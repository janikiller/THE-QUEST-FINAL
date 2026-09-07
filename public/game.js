import { GameState } from "../src/GameState.js";
import { StoryEngine } from "../src/StoryEngine.js";
import { CharacterRenderer } from "../src/CharacterRenderer.js";
import { PoliceCharacter } from "../src/PoliceCharacter.js";

const SAVE_KEY = "tqf_save_v1";
const ASSET = (p) => `../assets/${String(p).replace(/^assets\//, "")}`;

async function loadJSON(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(path);
  return res.json();
}

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => [...document.querySelectorAll(sel)];

function showScreen(id) {
  $$(".screen").forEach((el) => el.removeAttribute("data-active"));
  const screen = $(`#screen-${id}`);
  if (screen) screen.setAttribute("data-active", "true");
}

function openModal(name) {
  $(`#modal-${name}`)?.removeAttribute("hidden");
}
function closeModal(name) {
  $(`#modal-${name}`)?.setAttribute("hidden", "");
}

const data = {
  parts: null,
  animations: null,
  presets: null,
  skills: null,
  items: null,
  story: null,
  character: null,
};

let state;
let story;
let renderer;
let createPointsLeft = 5;
let createSkills = {};
let currentPartTab = "heads";
let pendingSide = null;
let last = performance.now();
let animating = true;

function save() {
  localStorage.setItem(SAVE_KEY, JSON.stringify(state.snapshot()));
}

function loadSave() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function prettyId(id) {
  return String(id || "")
    .replaceAll("_", " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function skillLabel(id) {
  return data.skills.skills.find((s) => s.id === id)?.name || id;
}

function chancePreview(skillId, diff = 1, risk) {
  const level = createSkills[skillId] || state?.skill(skillId) || 1;
  let chance = 0.35 + level * 0.18 - diff * 0.12;
  if (typeof risk === "number") chance = chance * 0.7 + (1 - risk / 100) * 0.3;
  return Math.round(Math.max(0.08, Math.min(0.92, chance)) * 100);
}

function updateHud() {
  const t = state.timeLabel();
  $("#hud-time").textContent = t;
  $("#mission-time").textContent = t;
  $("#hud-prestige").textContent = state.prestige;
  $("#mission-prestige").textContent = state.prestige;
  $("#hud-items").textContent = state.inventory.length;
  $("#city-agent-name").textContent = state.name || "Agente";
  $("#inv-name").textContent = state.name || "Agente";
  const preset = data.presets.presets.find((p) => p.id === state.loadout.preset);
  $("#city-agent-unit").textContent = preset?.name || "Patrulla";

  const mini = $("#mini-skills");
  mini.innerHTML = data.skills.skills
    .map((s) => {
      const lv = state.skill(s.id);
      const pct = (lv / data.skills.maxLevel) * 100;
      return `<div class="mini-skill"><span>${s.name}</span><span>${lv}</span><div class="mini-bar"><i style="width:${pct}%"></i></div></div>`;
    })
    .join("");
}

function renderPresets() {
  const row = $("#preset-row");
  row.innerHTML = "";
  data.presets.presets.forEach((p) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "preset" + (state.loadout.preset === p.id ? " selected" : "");
    const thumb = p.thumbnail
      ? ASSET(p.thumbnail)
      : ASSET(`character/examples/${p.example || "patrol"}.png`);
    btn.innerHTML = `<img src="${thumb}" alt="" /><span>${p.name}</span>`;
    btn.addEventListener("click", () => {
      state.loadout = {
        head: p.head,
        uniform: p.uniform,
        pants: p.pants,
        back: p.back,
        belt: [...(p.belt || [])],
        patch: p.patch,
        preset: p.id,
        example: p.example || null,
      };
      renderPresets();
      renderParts();
      paintCreate();
    });
    row.appendChild(btn);
  });
}

function renderParts() {
  const grid = $("#parts-grid");
  grid.innerHTML = "";
  const tab = currentPartTab;
  if (tab === "belt") {
    data.parts.belt.forEach((part) => {
      const on = state.loadout.belt.includes(part.id);
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "part" + (on ? " selected" : "");
      btn.innerHTML = `<img src="${ASSET(part.file)}" alt="" /><span>${prettyId(part.id)}</span>`;
      btn.addEventListener("click", () => {
        const set = new Set(state.loadout.belt);
        if (set.has(part.id)) set.delete(part.id);
        else set.add(part.id);
        state.loadout.belt = [...set];
        state.loadout.example = null;
        renderParts();
        paintCreate();
      });
      grid.appendChild(btn);
    });
    return;
  }

  const groupKey = tab;
  const loadoutKey =
    tab === "heads" ? "head" : tab === "uniforms" ? "uniform" : tab === "pants" ? "pants" : "back";
  (data.parts[groupKey] || []).forEach((part) => {
    const selected = state.loadout[loadoutKey] === part.id;
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "part" + (selected ? " selected" : "");
    btn.innerHTML = `<img src="${ASSET(part.file)}" alt="" /><span>${prettyId(part.id)}</span>`;
    btn.addEventListener("click", () => {
      if (loadoutKey === "back" && state.loadout.back === part.id) state.loadout.back = null;
      else state.loadout[loadoutKey] = part.id;
      state.loadout.example = null;
      renderParts();
      paintCreate();
    });
    grid.appendChild(btn);
  });
}

function renderSkillEditor() {
  const host = $("#skills-editor");
  host.innerHTML = "";
  $("#skill-points").textContent = `${createPointsLeft} puntos`;
  data.skills.skills.forEach((s) => {
    const row = document.createElement("div");
    row.className = "skill-row";
    row.innerHTML = `
      <div class="label">
        <strong style="color:${s.color}">${s.name}</strong>
        <small>${s.desc}</small>
      </div>
      <div class="skill-controls">
        <button type="button" data-act="-">−</button>
        <b>${createSkills[s.id]}</b>
        <button type="button" data-act="+">+</button>
      </div>`;
    row.querySelector('[data-act="-"]').addEventListener("click", () => {
      if (createSkills[s.id] > 1) {
        createSkills[s.id]--;
        createPointsLeft++;
        renderSkillEditor();
      }
    });
    row.querySelector('[data-act="+"]').addEventListener("click", () => {
      const max = data.skills.maxStart || 3;
      if (createPointsLeft > 0 && createSkills[s.id] < max) {
        createSkills[s.id]++;
        createPointsLeft--;
        renderSkillEditor();
      }
    });
    host.appendChild(row);
  });
}

async function paintCreate() {
  const canvas = $("#create-canvas");
  const ctx = canvas.getContext("2d");
  await renderer.draw(ctx, state.loadout, { w: canvas.width, h: canvas.height });
}

async function paintCity() {
  const canvas = $("#city-canvas");
  const ctx = canvas.getContext("2d");
  await renderer.draw(ctx, state.loadout, { w: canvas.width, h: canvas.height });
}

async function paintInv() {
  const canvas = $("#inv-canvas");
  const ctx = canvas.getContext("2d");
  await renderer.draw(ctx, state.loadout, { w: canvas.width, h: canvas.height });
}

function renderCity() {
  updateHud();
  paintCity();

  const node = story.node();
  $("#campaign-art").src = ASSET(
    state.campaignDone
      ? "events/tiles/civiles/persona_desaparecida.png"
      : node?.image || data.story.nodes.start.image
  );
  $("#campaign-title").textContent = state.campaignDone
    ? "Caso cerrado"
    : data.story.title;
  $("#campaign-blurb").textContent = state.campaignDone
    ? endingBlurb(state.ending)
    : node?.text?.slice(0, 140) + "…" || data.story.intro;
  $("#btn-campaign").textContent = state.campaignDone
    ? "Releer desenlace"
    : state.campaignNode === "start"
      ? "Abrir caso Portal 3"
      : "Continuar caso";

  const grid = $("#mission-grid");
  grid.innerHTML = "";
  data.story.sideMissions.forEach((m) => {
    if (m.requireCampaign && !state.campaignDone && !state.hasFlag("wider_case")) {
      /* still show but softer */
    }
    const done = state.missionsDone.includes(m.id);
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "mission-card" + (done ? " done" : "");
    btn.innerHTML = `
      <img src="${ASSET(m.image)}" alt="" />
      <div class="body">
        <em>${skillLabel(m.skill)}</em>
        <strong>${m.title}</strong>
        <span>${m.blurb}</span>
      </div>`;
    btn.addEventListener("click", () => openSide(m));
    grid.appendChild(btn);
  });
}

function endingBlurb(ending) {
  const map = {
    best: "Azotea. Esposas. Marina a salvo. La noche te debe una.",
    good: "Marina vive. El barrio respira. Quedan hilos sueltos.",
    mixed: "Salvaste lo importante. El informe no será limpio.",
    bad: "La tarjeta sigue manchada. La noche no ha terminado.",
  };
  return map[ending] || data.story.intro;
}

function openSide(mission) {
  pendingSide = mission;
  $("#side-art").src = ASSET(mission.image);
  $("#side-title").textContent = mission.title;
  $("#side-blurb").textContent = mission.blurb;
  const pct = chancePreview(mission.skill, mission.diff || 1);
  $("#side-check").textContent = `Chequeo de ${skillLabel(mission.skill)} · ~${pct}%`;
  $("#side-result").hidden = true;
  $("#btn-side-go").hidden = false;
  openModal("side");
}

function renderInventory() {
  updateHud();
  paintInv();
  const belt = $("#belt-slots");
  belt.innerHTML = "";
  state.beltItems().forEach((item) => {
    const b = document.createElement("button");
    b.type = "button";
    b.title = item.name;
    b.innerHTML = `<img src="${ASSET(item.file)}" alt="${item.name}" />`;
    belt.appendChild(b);
  });

  const evidence = $("#evidence-list");
  const items = state.evidenceItems();
  evidence.innerHTML = items.length
    ? items
        .map(
          (it) => `
      <div class="item-row">
        <img src="${ASSET(it.icon)}" alt="" />
        <div>
          <div class="kind">${it.kind}</div>
          <strong>${it.name}</strong>
          <small>${it.desc}</small>
        </div>
      </div>`
        )
        .join("")
    : `<p class="micro">Sin evidencia todavía. Las misiones dejan marcas aquí.</p>`;

  const gear = $("#gear-list");
  gear.innerHTML = data.items.belt
    .map((it) => {
      const on = state.loadout.belt.includes(it.id);
      return `
      <button type="button" class="item-row" data-belt="${it.id}">
        <img src="${ASSET(it.file)}" alt="" />
        <div>
          <strong>${it.name}${on ? " · cinturón" : ""}</strong>
          <small>${it.desc}</small>
        </div>
      </button>`;
    })
    .join("");
  gear.querySelectorAll("[data-belt]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = btn.getAttribute("data-belt");
      const set = new Set(state.loadout.belt);
      if (set.has(id)) set.delete(id);
      else set.add(id);
      state.loadout.belt = [...set];
      state.loadout.example = null;
      save();
      renderInventory();
      paintCity();
      paintCreate();
    });
  });
}

function renderSkillsModal() {
  const host = $("#skills-view");
  host.innerHTML = data.skills.skills
    .map((s) => {
      const lv = state.skill(s.id);
      const pct = (lv / data.skills.maxLevel) * 100;
      return `
      <div class="skill-card">
        <div>
          <strong style="color:${s.color}">${s.name}</strong>
          <div class="micro" style="margin:0.2rem 0 0">${s.desc}</div>
        </div>
        <b>${lv}/${data.skills.maxLevel}</b>
        <div class="bar"><i style="width:${pct}%;background:${s.color}"></i></div>
      </div>`;
    })
    .join("");
}

function renderMission() {
  const node = story.node();
  if (!node) return;
  $("#mission-art").src = ASSET(node.image);
  $("#mission-kicker").textContent = data.story.subtitle;
  $("#mission-title").textContent = node.title;
  $("#mission-text").textContent = node.text;
  updateHud();

  const toast = $("#check-toast");
  toast.hidden = true;

  const host = $("#mission-choices");
  host.innerHTML = "";
  const choices = story.availableChoices(node);

  if (node.ending || !choices.length) {
    $("#btn-mission-leave").hidden = false;
    if (node.ending) showEnding(node);
  } else {
    $("#btn-mission-leave").hidden = true;
  }

  choices.forEach((c) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "choice";
    let meta = "";
    if (c.skill) {
      const pct = chancePreview(c.skill, c.diff || 1, c.risk);
      const riskTxt =
        typeof c.risk === "number" ? ` · ${c.risk}% arriesgada` : "";
      meta = `<span class="meta${typeof c.risk === "number" ? " risk" : ""}">${skillLabel(c.skill)} · ~${pct}%${riskTxt}</span>`;
    }
    btn.innerHTML = `${c.label}${meta}`;
    btn.addEventListener("click", () => {
      const { node: next, check } = story.choose(c);
      if (check) {
        toast.hidden = false;
        toast.className = "check-toast " + (check.ok ? "ok" : "fail");
        toast.textContent = check.ok
          ? `✓ ${skillLabel(check.skillId)} ${check.level} · ${check.chance}%`
          : `✗ Fallaste ${skillLabel(check.skillId)} · ${check.chance}%`;
      }
      save();
      setTimeout(() => {
        if (next?.ending) {
          renderMission();
        } else {
          renderMission();
        }
      }, check ? 420 : 0);
    });
    host.appendChild(btn);
  });
}

function showEnding(node) {
  const titles = {
    best: "Desenlace limpio",
    good: "La noche cede",
    mixed: "Victoria imperfecta",
    bad: "Se te escapa",
  };
  $("#ending-title").textContent = titles[node.ending] || "Fin";
  $("#ending-text").textContent = node.text;
  openModal("ending");
}

function startDuty() {
  const name = ($("#agent-name").value || "").trim() || "Reyes";
  if (createPointsLeft > 0) {
    // auto-dump remaining into observation then tactics
    const order = ["observation", "tactics", "persuasion", "search", "intimidation"];
    for (const id of order) {
      while (createPointsLeft > 0 && createSkills[id] < (data.skills.maxStart || 3)) {
        createSkills[id]++;
        createPointsLeft--;
      }
    }
  }
  state.name = name;
  state.skills = { ...createSkills };
  state.campaignNode = "start";
  state.campaignDone = false;
  state.ending = null;
  state.inventory = [];
  state.flags = new Set();
  state.visitedNodes = new Set();
  state.prestige = 0;
  state.missionsDone = [];
  state.hour = 21;
  state.minute = 10;
  save();
  showScreen("city");
  renderCity();
}

function continueCampaign() {
  if (!state.visitedNodes.has(state.campaignNode)) {
    story.enter(state.campaignNode);
  }
  showScreen("mission");
  renderMission();
  const node = story.node();
  if (node?.ending) showEnding(node);
}

function bind() {
  $("#btn-new").addEventListener("click", () => {
    state.reset();
    createPointsLeft = data.skills.pointBudget;
    createSkills = Object.fromEntries(data.skills.skills.map((s) => [s.id, 1]));
    $("#agent-name").value = "";
    renderPresets();
    renderParts();
    renderSkillEditor();
    paintCreate();
    showScreen("create");
  });

  $("#btn-continue").addEventListener("click", () => {
    showScreen("city");
    renderCity();
  });

  $("#btn-create-back").addEventListener("click", () => showScreen("title"));
  $("#btn-start-duty").addEventListener("click", startDuty);

  $$("#parts-tabs .chip").forEach((chip) => {
    chip.addEventListener("click", () => {
      $$("#parts-tabs .chip").forEach((c) => c.classList.remove("active"));
      chip.classList.add("active");
      currentPartTab = chip.dataset.part;
      renderParts();
    });
  });

  $("#btn-campaign").addEventListener("click", continueCampaign);
  $("#btn-inventory").addEventListener("click", () => {
    renderInventory();
    openModal("inventory");
  });
  $("#btn-skills").addEventListener("click", () => {
    renderSkillsModal();
    openModal("skills");
  });
  $("#btn-mission-inv").addEventListener("click", () => {
    renderInventory();
    openModal("inventory");
  });
  $("#btn-mission-leave").addEventListener("click", () => {
    showScreen("city");
    renderCity();
  });

  $$("[data-close]").forEach((btn) => {
    btn.addEventListener("click", () => closeModal(btn.dataset.close));
  });

  $("#btn-side-go").addEventListener("click", () => {
    if (!pendingSide) return;
    const check = story.sideMissionResult(pendingSide);
    const el = $("#side-result");
    el.hidden = false;
    el.className = "side-result " + (check.ok ? "ok" : "fail");
    el.textContent = check.ok
      ? `Intervención limpia · ${skillLabel(check.skillId)} +1`
      : `La escena se tuerce · fallaste ${skillLabel(check.skillId)} (${check.chance}%)`;
    $("#btn-side-go").hidden = true;
    save();
    updateHud();
    renderCity();
  });

  $("#btn-ending-city").addEventListener("click", () => {
    closeModal("ending");
    showScreen("city");
    renderCity();
  });
  $("#btn-ending-new").addEventListener("click", () => {
    closeModal("ending");
    localStorage.removeItem(SAVE_KEY);
    $("#btn-new").click();
  });

  window.addEventListener("keydown", (e) => {
    if (e.key === "i" || e.key === "I") {
      if ($("#screen-city").dataset.active === "true" || $("#screen-mission").dataset.active === "true") {
        renderInventory();
        openModal("inventory");
      }
    }
    if (e.key === "Escape") {
      closeModal("inventory");
      closeModal("skills");
      closeModal("side");
    }
  });
}

function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  if (animating) {
    renderer.tick(dt);
    const active = document.querySelector('.screen[data-active="true"]')?.id;
    if (active === "screen-create") paintCreate();
    else if (active === "screen-city") paintCity();
    if (!$("#modal-inventory").hidden) paintInv();
  }
  requestAnimationFrame(loop);
}

async function boot() {
  const [parts, animations, presets, skills, items, storyData, character] =
    await Promise.all([
      loadJSON("../data/character_parts.json"),
      loadJSON("../data/character_animations.json"),
      loadJSON("../data/presets.json"),
      loadJSON("../data/skills.json"),
      loadJSON("../data/items.json"),
      loadJSON("../data/story.json"),
      loadJSON("../data/character.json"),
    ]);

  Object.assign(data, {
    parts,
    animations,
    presets,
    skills,
    items,
    story: storyData,
    character,
  });

  state = new GameState({ skillsCatalog: skills, itemsCatalog: items });
  story = new StoryEngine(storyData, state);
  renderer = new CharacterRenderer({ parts, animations, presets });
  // keep PoliceCharacter imported for engine reuse / future map
  void PoliceCharacter;

  const saved = loadSave();
  if (saved?.name) {
    state.restore(saved);
    $("#btn-continue").hidden = false;
  }

  createPointsLeft = skills.pointBudget;
  createSkills = Object.fromEntries(skills.skills.map((s) => [s.id, 1]));

  bind();
  showScreen("title");
  requestAnimationFrame(loop);
}

boot().catch((err) => {
  console.error(err);
  document.body.innerHTML = `<pre style="color:#f2ebe0;padding:2rem;font:16px monospace">Error cargando THE QUEST FINAL:\n${err}</pre>`;
});
