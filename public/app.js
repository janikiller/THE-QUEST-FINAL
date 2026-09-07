const ASSET = (path) => `../assets/${path.replace(/^assets\//, "")}`;

async function loadJSON(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`No se pudo cargar ${path}`);
  return res.json();
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`Imagen fallida: ${src}`));
    img.src = src;
  });
}

class PaperDollCharacter {
  constructor({ parts, animations, variants, presets, config }) {
    this.parts = parts;
    this.animations = animations;
    this.variants = variants;
    this.presets = presets.presets;
    this.config = config;
    this.loadout = { ...config.defaultLoadout, belt: [...(config.defaultLoadout.belt || [])] };
    this.direction = "front";
    this.action = "idle";
    this.frame = 0;
    this.acc = 0;
    this.cache = new Map();
    this.mode = "example"; // example | modular | animation
    this.exampleId = "patrol";
  }

  partById(group, id) {
    return (this.parts[group] || []).find((p) => p.id === id);
  }

  async getImage(file) {
    const key = file;
    if (this.cache.has(key)) return this.cache.get(key);
    const img = await loadImage(ASSET(file));
    this.cache.set(key, img);
    return img;
  }

  applyPreset(presetId) {
    const preset = this.presets.find((p) => p.id === presetId);
    if (!preset) return;
    this.loadout = {
      head: preset.head,
      uniform: preset.uniform,
      pants: preset.pants,
      back: preset.back,
      belt: [...(preset.belt || [])],
      patch: preset.patch,
    };
    this.exampleId = preset.example || null;
    this.mode = preset.example ? "example" : "modular";
  }

  setDirection(dir) {
    this.direction = dir;
    this.frame = 0;
  }

  setAction(action) {
    this.action = action;
    this.frame = 0;
    this.mode = "animation";
  }

  toggleBelt(id) {
    const set = new Set(this.loadout.belt || []);
    if (set.has(id)) set.delete(id);
    else set.add(id);
    this.loadout.belt = [...set];
    this.mode = "modular";
  }

  setPart(group, id) {
    if (group === "back" && this.loadout.back === id) this.loadout.back = null;
    else this.loadout[group] = id;
    this.mode = "modular";
  }

  currentAnimFrames() {
    const dir = this.animations.animations[this.direction];
    if (!dir) return [];
    return dir[this.action]?.frames || [];
  }

  update(dt) {
    const frames = this.currentAnimFrames();
    if (!frames.length) return;
    const fps = this.animations.animations[this.direction][this.action].fps || 6;
    this.acc += dt;
    const interval = 1 / fps;
    while (this.acc >= interval) {
      this.acc -= interval;
      this.frame = (this.frame + 1) % frames.length;
    }
  }

  async draw(ctx, w, h) {
    ctx.clearRect(0, 0, w, h);

    if (this.mode === "animation") {
      const frames = this.currentAnimFrames();
      if (!frames.length) return;
      const file = frames[this.frame % frames.length];
      const img = await this.getImage(file);
      this._blit(ctx, img, w, h, 2.1);
      return;
    }

    if (this.mode === "example" && this.exampleId) {
      const ex = (this.variants.examples || []).find((e) => e.id === this.exampleId);
      if (ex) {
        const img = await this.getImage(ex.file);
        this._blit(ctx, img, w, h, 1.05);
        return;
      }
    }

    // Modular stack: pants -> uniform -> belt icons hint -> back -> head
    const stack = [];
    const pants = this.partById("pants", this.loadout.pants);
    const uniform = this.partById("uniforms", this.loadout.uniform);
    const head = this.partById("heads", this.loadout.head);
    const back = this.loadout.back ? this.partById("back", this.loadout.back) : null;
    if (pants) stack.push({ file: pants.file, y: 0.22, scale: 0.95 });
    if (uniform) stack.push({ file: uniform.file, y: -0.08, scale: 1.05 });
    if (back) stack.push({ file: back.file, y: -0.02, scale: 0.7, x: 0.22 });
    if (head) stack.push({ file: head.file, y: -0.34, scale: 0.85 });

    for (const layer of stack) {
      const img = await this.getImage(layer.file);
      this._blit(ctx, img, w, h, layer.scale, layer.x || 0, layer.y || 0);
    }

    // Mini belt icons under feet
    const belt = this.loadout.belt || [];
    let i = 0;
    for (const id of belt) {
      const item = this.partById("belt", id);
      if (!item) continue;
      const img = await this.getImage(item.file);
      const size = 42;
      const x = w / 2 - ((belt.length - 1) * 48) / 2 + i * 48 - size / 2;
      const y = h - 58;
      ctx.drawImage(img, x, y, size, size);
      i += 1;
    }
  }

  _blit(ctx, img, w, h, scale = 1, ox = 0, oy = 0) {
    const maxH = h * 0.78 * scale;
    const ratio = img.width / img.height;
    const dh = maxH;
    const dw = dh * ratio;
    const x = w / 2 - dw / 2 + ox * w;
    const y = h / 2 - dh / 2 + oy * h;
    ctx.drawImage(img, x, y, dw, dh);
  }
}

function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  Object.entries(attrs).forEach(([k, v]) => {
    if (k === "class") node.className = v;
    else if (k === "html") node.innerHTML = v;
    else if (k.startsWith("on") && typeof v === "function") node.addEventListener(k.slice(2), v);
    else node.setAttribute(k, v);
  });
  for (const child of [].concat(children)) {
    if (child == null) continue;
    node.append(child.nodeType ? child : document.createTextNode(child));
  }
  return node;
}

function partButton(item, { selected, onClick, label }) {
  const btn = el("button", {
    class: `choice${selected ? " selected" : ""}`,
    type: "button",
    onclick: onClick,
  }, [
    el("img", { src: ASSET(item.file), alt: item.id }),
    el("span", {}, label || item.id.replace(/_/g, " ")),
  ]);
  return btn;
}

async function main() {
  const [config, parts, animations, variants, presets, vehicle] = await Promise.all([
    loadJSON("../data/character.json"),
    loadJSON("../data/character_parts.json"),
    loadJSON("../data/character_animations.json"),
    loadJSON("../data/character_variants.json"),
    loadJSON("../data/presets.json"),
    loadJSON("../data/vehicle.json"),
  ]);

  const character = new PaperDollCharacter({ parts, animations, variants, presets, config });
  character.applyPreset("patrol");

  const canvas = document.getElementById("preview");
  const ctx = canvas.getContext("2d");
  const title = document.getElementById("agent-title");
  const desc = document.getElementById("agent-desc");

  function refreshMeta() {
    const preset = character.presets.find((p) =>
      p.head === character.loadout.head &&
      p.uniform === character.loadout.uniform &&
      p.pants === character.loadout.pants
    );
    title.textContent = preset ? `Agente · ${preset.name}` : "Agente · Personalizado";
    const patch = (parts.patches || []).find((p) => p.id === character.loadout.patch);
    desc.textContent = `Unidad: ${patch?.label || "—"} · ${character.direction}/${character.action} · paper-doll RPG`;
  }

  function renderPickers() {
    const presetsEl = document.getElementById("presets");
    presetsEl.innerHTML = "";
    for (const p of character.presets) {
      const ex = variants.examples.find((e) => e.id === p.example);
      const btn = el("button", {
        class: `preset${character.exampleId === p.example && character.mode !== "modular" ? " selected" : ""}`,
        type: "button",
        onclick: () => {
          character.applyPreset(p.id);
          refreshAll();
        },
      }, [
        ex ? el("img", { src: ASSET(ex.file), alt: p.name }) : null,
        el("span", {}, p.name),
      ]);
      presetsEl.append(btn);
    }

    const map = [
      ["heads", "heads", false],
      ["uniforms", "uniforms", false],
      ["pants", "pants", false],
      ["back", "back", false],
      ["belt", "belt", true],
    ];
    for (const [domId, group, multi] of map) {
      const root = document.getElementById(domId);
      root.innerHTML = "";
      if (group === "back") {
        root.append(el("button", {
          class: `choice${!character.loadout.back ? " selected" : ""}`,
          type: "button",
          onclick: () => { character.loadout.back = null; character.mode = "modular"; refreshAll(); },
        }, [el("span", {}, "ninguno")]));
      }
      for (const item of parts[group] || []) {
        const selected = multi
          ? (character.loadout.belt || []).includes(item.id)
          : character.loadout[group === "uniforms" ? "uniform" : group === "heads" ? "head" : group] === item.id;
        root.append(partButton(item, {
          selected,
          onClick: () => {
            if (multi) character.toggleBelt(item.id);
            else if (group === "heads") character.setPart("head", item.id);
            else if (group === "uniforms") character.setPart("uniform", item.id);
            else character.setPart(group, item.id);
            refreshAll();
          },
        }));
      }
    }

    const patches = document.getElementById("patches");
    patches.innerHTML = "";
    for (const p of parts.patches || []) {
      patches.append(el("button", {
        class: `chip${character.loadout.patch === p.id ? " selected" : ""}`,
        type: "button",
        onclick: () => { character.loadout.patch = p.id; refreshMeta(); renderPickers(); },
      }, p.label));
    }
  }

  function renderAnimPanel() {
    const strip = document.getElementById("anim-strip");
    strip.innerHTML = "";
    for (const dir of animations.directions || Object.keys(animations.animations)) {
      for (const [action, data] of Object.entries(animations.animations[dir] || {})) {
        for (const file of data.frames) {
          strip.append(el("div", { class: "thumb" }, [
            el("img", { src: ASSET(file), alt: `${dir} ${action}` }),
            el("span", {}, `${dir} ${action}`),
          ]));
        }
      }
    }

    const examples = document.getElementById("examples");
    examples.innerHTML = "";
    for (const ex of variants.examples || []) {
      examples.append(el("button", {
        class: "thumb",
        type: "button",
        onclick: () => {
          character.exampleId = ex.id;
          character.mode = "example";
          const preset = character.presets.find((p) => p.example === ex.id);
          if (preset) character.applyPreset(preset.id);
          refreshAll();
        },
      }, [el("img", { src: ASSET(ex.file), alt: ex.id }), el("span", {}, ex.id)]));
    }

    const colors = document.getElementById("colors");
    colors.innerHTML = "";
    for (const c of variants.colors || []) {
      colors.append(el("div", { class: "thumb" }, [
        el("img", { src: ASSET(c.file), alt: c.id }),
        el("span", {}, c.id),
      ]));
    }
  }

  function renderVehicle() {
    const hero = document.getElementById("vehicle-hero");
    hero.innerHTML = "";
    if (vehicle.hero) hero.append(el("img", { src: ASSET(vehicle.hero), alt: "Patrulla" }));

    const vars = document.getElementById("vehicle-variants");
    vars.innerHTML = "";
    for (const v of vehicle.variants || []) {
      vars.append(el("div", { class: "thumb" }, [
        el("img", { src: ASSET(v.file), alt: v.id }),
        el("span", {}, v.id.replace(/_/g, " ")),
      ]));
    }

    const move = document.getElementById("vehicle-move");
    move.innerHTML = "";
    for (const [dir, frames] of Object.entries(vehicle.movement || {})) {
      for (const file of frames) {
        move.append(el("div", { class: "thumb" }, [
          el("img", { src: ASSET(file), alt: dir }),
          el("span", {}, dir),
        ]));
      }
    }
  }

  function refreshAll() {
    refreshMeta();
    renderPickers();
  }

  document.getElementById("direction").addEventListener("change", (e) => {
    character.setDirection(e.target.value);
    refreshMeta();
  });
  document.getElementById("action").addEventListener("change", (e) => {
    character.setAction(e.target.value);
    refreshMeta();
  });

  document.querySelectorAll(".tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      document.querySelectorAll(".tab").forEach((t) => t.classList.remove("active"));
      tab.classList.add("active");
      document.querySelectorAll(".panel").forEach((p) => p.classList.add("hidden"));
      document.getElementById(`panel-${tab.dataset.panel}`).classList.remove("hidden");
    });
  });

  renderPickers();
  renderAnimPanel();
  renderVehicle();
  refreshMeta();

  let last = performance.now();
  async function loop(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    character.update(dt);
    await character.draw(ctx, canvas.width, canvas.height);
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);
}

main().catch((err) => {
  console.error(err);
  document.body.innerHTML = `<pre style="padding:2rem;color:#b00020">${err.message}</pre>`;
});
