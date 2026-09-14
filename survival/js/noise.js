/** Generador de ruido valor 2D — isla inventada cada partida. */
export function createNoise(seed = 1) {
  let s = seed >>> 0;
  const rand = () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };

  const table = new Float32Array(256);
  for (let i = 0; i < 256; i++) table[i] = rand();

  const fade = (t) => t * t * (3 - 2 * t);
  const lerp = (a, b, t) => a + (b - a) * t;
  const hash = (x, y) => table[(x * 37 + y * 17 + seed) & 255];

  function noise2(x, y) {
    const x0 = Math.floor(x);
    const y0 = Math.floor(y);
    const xf = fade(x - x0);
    const yf = fade(y - y0);
    const v00 = hash(x0, y0);
    const v10 = hash(x0 + 1, y0);
    const v01 = hash(x0, y0 + 1);
    const v11 = hash(x0 + 1, y0 + 1);
    return lerp(lerp(v00, v10, xf), lerp(v01, v11, xf), yf);
  }

  function fbm(x, y, octaves = 4) {
    let amp = 0.5;
    let freq = 1;
    let sum = 0;
    let norm = 0;
    for (let i = 0; i < octaves; i++) {
      sum += noise2(x * freq, y * freq) * amp;
      norm += amp;
      amp *= 0.5;
      freq *= 2;
    }
    return sum / norm;
  }

  return { noise2, fbm, seed };
}
