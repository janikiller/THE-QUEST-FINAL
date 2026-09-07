/** Persistent player state for THE QUEST FINAL. */
export class GameState {
  constructor({ skillsCatalog, itemsCatalog }) {
    this.skillsCatalog = skillsCatalog;
    this.itemsCatalog = itemsCatalog;
    this.reset();
  }

  reset() {
    this.name = "";
    this.loadout = {
      head: "cap_blue",
      uniform: "vest_blue",
      pants: "pants_blue",
      back: null,
      belt: ["holster", "handcuffs", "radio"],
      patch: "policia",
      preset: "patrol",
      example: "patrol",
    };
    this.skills = Object.fromEntries(
      this.skillsCatalog.skills.map((s) => [s.id, 1])
    );
    this.inventory = [];
    this.flags = new Set();
    this.prestige = 0;
    this.missionsDone = [];
    this.visitedNodes = new Set();
    this.campaignNode = "start";
    this.campaignDone = false;
    this.ending = null;
    this.hour = 21;
    this.minute = 10;
  }

  skill(id) {
    return this.skills[id] || 1;
  }

  addSkillXp(id, amount = 1) {
    if (!this.skills[id]) return;
    const max = this.skillsCatalog.maxLevel || 5;
    this.skills[id] = Math.min(max, this.skills[id] + amount);
  }

  hasItem(id) {
    return this.inventory.includes(id);
  }

  addItem(id) {
    if (!this.inventory.includes(id)) this.inventory.push(id);
  }

  setFlag(flag) {
    if (flag) this.flags.add(flag);
  }

  hasFlag(flag) {
    return this.flags.has(flag);
  }

  tickTime(minutes = 7) {
    this.minute += minutes;
    while (this.minute >= 60) {
      this.minute -= 60;
      this.hour = (this.hour + 1) % 24;
    }
  }

  timeLabel() {
    return `${String(this.hour).padStart(2, "0")}:${String(this.minute).padStart(2, "0")}`;
  }

  evidenceItems() {
    const map = Object.fromEntries(
      (this.itemsCatalog.evidence || []).map((i) => [i.id, i])
    );
    return this.inventory.map((id) => map[id]).filter(Boolean);
  }

  beltItems() {
    const map = Object.fromEntries(
      (this.itemsCatalog.belt || []).map((i) => [i.id, i])
    );
    return (this.loadout.belt || []).map((id) => map[id]).filter(Boolean);
  }

  snapshot() {
    return {
      name: this.name,
      loadout: this.loadout,
      skills: { ...this.skills },
      inventory: [...this.inventory],
      flags: [...this.flags],
      prestige: this.prestige,
      missionsDone: [...this.missionsDone],
      visitedNodes: [...this.visitedNodes],
      campaignNode: this.campaignNode,
      campaignDone: this.campaignDone,
      ending: this.ending,
      hour: this.hour,
      minute: this.minute,
    };
  }

  restore(data) {
    if (!data) return;
    this.name = data.name || "";
    this.loadout = data.loadout || this.loadout;
    this.skills = data.skills || this.skills;
    this.inventory = data.inventory || [];
    this.flags = new Set(data.flags || []);
    this.prestige = data.prestige || 0;
    this.missionsDone = data.missionsDone || [];
    this.visitedNodes = new Set(data.visitedNodes || []);
    this.campaignNode = data.campaignNode || "start";
    this.campaignDone = !!data.campaignDone;
    this.ending = data.ending || null;
    this.hour = data.hour ?? 21;
    this.minute = data.minute ?? 10;
  }
}
