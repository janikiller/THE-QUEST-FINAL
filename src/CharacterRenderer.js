/** Canvas helper: draw police paper-doll / example / animation. */
export class CharacterRenderer {
  constructor({ parts, animations, presets }) {
    this.parts = parts;
    this.animations = animations;
    this.presets = presets?.presets || [];
    this.cache = new Map();
    this.direction = "front";
    this.action = "idle";
    this.frame = 0;
    this.acc = 0;
  }

  asset(path) {
    return `../assets/${path.replace(/^assets\//, "")}`;
  }

  loadImage(src) {
    if (this.cache.has(src)) return this.cache.get(src);
    const p = new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error(src));
      img.src = src;
    });
    this.cache.set(src, p);
    return p;
  }

  async get(file) {
    return this.loadImage(this.asset(file));
  }

  tick(dt) {
    const frames =
      this.animations.animations?.[this.direction]?.[this.action]?.frames || [];
    if (!frames.length) return;
    const fps =
      this.animations.animations[this.direction][this.action].fps || 6;
    this.acc += dt;
    const step = 1 / fps;
    while (this.acc >= step) {
      this.acc -= step;
      this.frame = (this.frame + 1) % frames.length;
    }
  }

  async draw(ctx, loadout, { w, h, mode = "auto" } = {}) {
    ctx.clearRect(0, 0, w, h);
    const exampleId = loadout.example;
    const useExample =
      mode === "example" || (mode === "auto" && exampleId && this.action === "idle");

    if (useExample && exampleId) {
      try {
        const img = await this.get(`character/examples/${exampleId}.png`);
        this.fit(ctx, img, w, h, 0.86);
        return;
      } catch {
        /* fall through */
      }
    }

    if (this.action !== "idle" || mode === "animation") {
      const frames =
        this.animations.animations?.[this.direction]?.[this.action]?.frames ||
        [];
      const path = frames[this.frame];
      if (path) {
        try {
          const img = await this.get(path);
          this.fit(ctx, img, w, h, 0.9);
          return;
        } catch {
          /* fall through */
        }
      }
    }

    // modular layers
    const order = [
      ["pants", loadout.pants],
      ["uniforms", loadout.uniform],
      ["back", loadout.back],
      ["heads", loadout.head],
    ];
    const imgs = [];
    for (const [group, id] of order) {
      if (!id) continue;
      const part = (this.parts[group] || []).find((p) => p.id === id);
      if (!part) continue;
      try {
        imgs.push(await this.get(part.file));
      } catch {
        /* skip */
      }
    }
    // compose roughly centered
    for (const img of imgs) this.fit(ctx, img, w, h, 0.78);
  }

  fit(ctx, img, w, h, scale = 0.85) {
    const maxW = w * scale;
    const maxH = h * scale;
    const r = Math.min(maxW / img.width, maxH / img.height);
    const dw = img.width * r;
    const dh = img.height * r;
    ctx.drawImage(img, (w - dw) / 2, (h - dh) / 2 + h * 0.04, dw, dh);
  }
}
