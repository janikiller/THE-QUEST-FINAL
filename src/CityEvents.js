/** City event dispatcher for THE QUEST FINAL police RPG. */
export class CityEvents {
  /**
   * @param {object} options
   * @param {object} options.catalog - data/events.json
   * @param {object} options.categories - data/event_categories.json
   * @param {() => number} [options.rng]
   */
  constructor({ catalog, categories, rng = Math.random }) {
    this.catalog = catalog;
    this.categories = categories.categories || [];
    this.events = catalog.events || [];
    this.byId = Object.fromEntries(this.events.map((e) => [e.id, e]));
    this.byCategory = Object.fromEntries(
      this.categories.map((c) => [c.id, this.events.filter((e) => e.category === c.id)])
    );
    this.rng = rng;
    this.active = [];
    this.weather = this.byId.dia_soleado || null;
    this.nextInstanceId = 1;
  }

  listCategories() {
    return this.categories;
  }

  listEvents({ category = null, severity = null, dispatchableOnly = false } = {}) {
    return this.events.filter((e) => {
      if (category && e.category !== category) return false;
      if (severity && e.severity !== severity) return false;
      if (dispatchableOnly && !e.dispatchable) return false;
      return true;
    });
  }

  get(eventId) {
    return this.byId[eventId] || null;
  }

  /** Apply a weather event as the current city atmosphere. */
  setWeather(eventId) {
    const event = this.byId[eventId];
    if (!event || !event.weather) return null;
    this.weather = event;
    return event;
  }

  /**
   * Spawn / dispatch an event into the active mission queue.
   * @returns {object|null} active instance
   */
  dispatch(eventId, { location = null, note = "" } = {}) {
    const event = this.byId[eventId];
    if (!event) return null;
    if (event.weather) {
      this.setWeather(eventId);
      return {
        instanceId: `weather-${event.id}`,
        type: "weather",
        event,
        startedAt: Date.now(),
      };
    }
    const instance = {
      instanceId: `evt-${this.nextInstanceId++}`,
      type: "mission",
      event,
      status: "active",
      location: location || this._randomDistrict(),
      note,
      startedAt: Date.now(),
      endsAt: event.durationSec ? Date.now() + event.durationSec * 1000 : null,
      units: [...(event.units || [])],
      xp: event.xp,
    };
    this.active.push(instance);
    return instance;
  }

  /** Spawn a random dispatchable event, optionally limited to a category. */
  dispatchRandom({ category = null, severity = null } = {}) {
    const pool = this.listEvents({ category, severity, dispatchableOnly: true });
    if (!pool.length) return null;
    const pick = pool[Math.floor(this.rng() * pool.length)];
    return this.dispatch(pick.id);
  }

  /** Mark an active mission as resolved and award its XP. */
  resolve(instanceId, { success = true } = {}) {
    const idx = this.active.findIndex((a) => a.instanceId === instanceId);
    if (idx < 0) return null;
    const [instance] = this.active.splice(idx, 1);
    instance.status = success ? "resolved" : "failed";
    instance.resolvedAt = Date.now();
    instance.awardedXp = success ? instance.xp : Math.floor(instance.xp * 0.25);
    return instance;
  }

  activeMissions() {
    return this.active.filter((a) => a.type === "mission");
  }

  currentWeather() {
    return this.weather;
  }

  /** Snapshot for save games / UI. */
  snapshot() {
    return {
      weatherId: this.weather?.id || null,
      active: this.active.map((a) => ({
        instanceId: a.instanceId,
        eventId: a.event.id,
        status: a.status,
        location: a.location,
        startedAt: a.startedAt,
        endsAt: a.endsAt,
        units: a.units,
      })),
    };
  }

  _randomDistrict() {
    const districts = [
      "Centro",
      "Puerto",
      "Industrial",
      "Residencial Norte",
      "Residencial Sur",
      "Autopista",
      "Aeropuerto",
      "Casco Antiguo",
      "Universidad",
      "Estadio",
    ];
    return districts[Math.floor(this.rng() * districts.length)];
  }
}
