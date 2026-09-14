/**
 * Ambiente procedural de Niebla Norte (Web Audio).
 * Viento, lluvia, truenos y tormenta de arena — sin archivos externos.
 */

export function createAudio() {
  let ctx = null;
  let master = null;
  let windGain = null;
  let rainGain = null;
  let sandGain = null;
  let humGain = null;
  let started = false;
  let thunderCd = 0;
  let lastKind = "";

  function ensure() {
    if (started) return true;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.4;
    master.connect(ctx.destination);

    humGain = makeNoiseBed(ctx, master, {
      color: "brown",
      freq: 90,
      q: 0.55,
      gain: 0.035,
    });
    windGain = makeNoiseBed(ctx, master, {
      color: "pink",
      freq: 380,
      q: 0.7,
      gain: 0.0001,
      lfo: 0.1,
      lfoDepth: 140,
    });
    rainGain = makeNoiseBed(ctx, master, {
      color: "white",
      freq: 2600,
      q: 0.5,
      gain: 0.0001,
      bandpass: true,
    });
    sandGain = makeNoiseBed(ctx, master, {
      color: "pink",
      freq: 850,
      q: 1.15,
      gain: 0.0001,
      lfo: 0.2,
      lfoDepth: 280,
    });

    started = true;
    if (ctx.state === "suspended") ctx.resume().catch(() => {});
    return true;
  }

  function unlock() {
    if (!ensure()) return;
    if (ctx.state === "suspended") ctx.resume().catch(() => {});
  }

  function playThunder(intensity = 1) {
    if (!ensure()) return;
    const dur = 1.0 + Math.random() * 1.5;
    const buffer = ctx.createBuffer(1, Math.floor(ctx.sampleRate * dur), ctx.sampleRate);
    const data = buffer.getChannelData(0);
    let s = (Math.random() * 1e9) | 0;
    for (let i = 0; i < data.length; i++) {
      s = (s * 16807) % 2147483647;
      const n = (s / 2147483647) * 2 - 1;
      const t = i / ctx.sampleRate;
      const env = Math.exp(-t * (2.1 + Math.random() * 0.8)) * (0.5 + 0.5 * Math.exp(-t * 14));
      const rumble = Math.sin(t * (26 + Math.random() * 20)) * 0.5;
      data[i] = (n * 0.65 + rumble) * env * intensity;
    }
    const src = ctx.createBufferSource();
    src.buffer = buffer;
    const filter = ctx.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = 160 + Math.random() * 240;
    const g = ctx.createGain();
    g.gain.value = 0.58 * intensity;
    src.connect(filter);
    filter.connect(g);
    g.connect(master);
    src.start();
    src.stop(ctx.currentTime + dur + 0.05);
  }

  function lerpGain(node, target, dt, speed = 2.2) {
    if (!node) return;
    const cur = node.gain.value;
    node.gain.value = cur + (target - cur) * Math.min(1, dt * speed);
  }

  function update(game, dt) {
    if (!started || !ctx || ctx.state === "suspended") return;
    const w = game.weather;
    const indoor = Boolean(game._audioIndoor);
    const atten = indoor ? 0.32 : 1;
    const gust = w.gust || 0;
    const windAmt = Math.min(1.5, (w.wind || 0) + gust * 0.85);

    let windTarget = 0.028 + windAmt * 0.11;
    if (w.kind === "storm") windTarget = 0.1 + windAmt * 0.15;
    if (w.kind === "sandstorm") windTarget = 0.13 + windAmt * 0.2;
    if (w.kind === "fog") windTarget = 0.035 + windAmt * 0.045;
    if (w.kind === "wind") windTarget = 0.08 + windAmt * 0.12;
    lerpGain(windGain, windTarget * atten, dt, 1.5);

    const rainOn = w.kind === "rain" || w.kind === "storm";
    const rainTarget = rainOn
      ? (0.045 + w.intensity * 0.13) * (w.kind === "storm" ? 1.35 : 1) * atten
      : 0;
    lerpGain(rainGain, rainTarget, dt, 2);

    const sandOn = w.kind === "sandstorm";
    const sandTarget = sandOn ? (0.07 + w.intensity * 0.17 + gust * 0.08) * atten : 0;
    lerpGain(sandGain, sandTarget, dt, 1.7);

    lerpGain(humGain, (w.kind === "clear" ? 0.022 : 0.015) * atten, dt, 1);

    thunderCd = Math.max(0, thunderCd - dt);
    if (w.thunder > 0.12 && thunderCd <= 0 && (w.kind === "storm" || w.kind === "rain")) {
      playThunder(0.65 + w.thunder);
      thunderCd = 0.4;
    }

    if (w.kind !== lastKind) {
      lastKind = w.kind;
      if (w.kind === "storm") {
        setTimeout(() => playThunder(0.85), 350 + Math.random() * 900);
      }
    }
  }

  return {
    unlock,
    update,
    playThunder,
    get started() {
      return started;
    },
  };
}

function makeNoiseBed(ctx, dest, opts) {
  const seconds = 2.5;
  const buffer = ctx.createBuffer(1, Math.floor(ctx.sampleRate * seconds), ctx.sampleRate);
  const data = buffer.getChannelData(0);
  let last = 0;
  let s = (Math.random() * 1e9) | 0;
  for (let i = 0; i < data.length; i++) {
    s = (s * 16807) % 2147483647;
    const white = (s / 2147483647) * 2 - 1;
    if (opts.color === "brown") {
      last = (last + 0.02 * white) / 1.02;
      data[i] = last * 3.4;
    } else if (opts.color === "pink") {
      last = 0.97 * last + 0.03 * white;
      data[i] = white * 0.3 + last;
    } else {
      data[i] = white;
    }
  }

  const src = ctx.createBufferSource();
  src.buffer = buffer;
  src.loop = true;

  const filter = ctx.createBiquadFilter();
  filter.type = opts.bandpass ? "bandpass" : "lowpass";
  filter.frequency.value = opts.freq;
  filter.Q.value = opts.q || 0.7;

  const gain = ctx.createGain();
  gain.gain.value = opts.gain;

  src.connect(filter);
  filter.connect(gain);
  gain.connect(dest);
  src.start();

  if (opts.lfo) {
    const lfo = ctx.createOscillator();
    lfo.type = "sine";
    lfo.frequency.value = opts.lfo;
    const lfoGain = ctx.createGain();
    lfoGain.gain.value = opts.lfoDepth || 100;
    lfo.connect(lfoGain);
    lfoGain.connect(filter.frequency);
    lfo.start();
  }

  return gain;
}
