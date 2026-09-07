/** Character controller for THE QUEST FINAL police RPG paper-doll system. */
export class PoliceCharacter {
  /**
   * @param {object} options
   * @param {object} options.animations - data/character_animations.json
   * @param {object} options.parts - data/character_parts.json
   * @param {object} options.loadout - equipped parts
   */
  constructor({ animations, parts, loadout }) {
    this.animations = animations;
    this.parts = parts;
    this.loadout = loadout;
    this.direction = "front";
    this.action = "idle";
    this.frameIndex = 0;
    this.timer = 0;
  }

  setDirection(direction) {
    if (!this.animations.animations[direction]) return;
    this.direction = direction;
    this.frameIndex = 0;
  }

  play(action) {
    this.action = action;
    this.frameIndex = 0;
    this.timer = 0;
  }

  /** Advance animation; returns current frame path relative to assets/. */
  update(dt) {
    const anim = this.animations.animations[this.direction]?.[this.action];
    if (!anim) return null;
    this.timer += dt;
    const step = 1 / (anim.fps || 6);
    if (this.timer >= step) {
      this.timer -= step;
      this.frameIndex = (this.frameIndex + 1) % anim.frameCount;
    }
    return anim.frames[this.frameIndex];
  }

  /** Layered modular draw list for customization UI / paper-doll mode. */
  modularLayers() {
    const layers = [];
    const pants = this.parts.pants.find((p) => p.id === this.loadout.pants);
    const uniform = this.parts.uniforms.find((p) => p.id === this.loadout.uniform);
    const head = this.parts.heads.find((p) => p.id === this.loadout.head);
    const back = this.parts.back.find((p) => p.id === this.loadout.back);
    if (pants) layers.push({ z: 10, file: pants.file });
    if (uniform) layers.push({ z: 20, file: uniform.file });
    if (back) layers.push({ z: 40, file: back.file });
    if (head) layers.push({ z: 50, file: head.file });
    return layers.sort((a, b) => a.z - b.z);
  }
}
