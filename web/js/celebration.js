// Mirrors Pictok/Views/Effects (Fireworks/Rain). Returns a Promise resolved when done.

const COLORS = ['#FFD60A', '#E63946', '#06D6A0', '#118AB2'];

export function celebrateWin() {
  playSound('sounds/win.wav');
  return runCanvas(fireworks, 1800);
}

export function celebrateFail() {
  playSound('sounds/fail.wav');
  return runCanvas(rain, 2800);
}

export function tickCorrect() { playSound('sounds/correct.wav', 0.25); }
export function tickWrong()   { playSound('sounds/wrong.wav', 0.4); }

function playSound(src, volume = 0.5) {
  try {
    const a = new Audio(src);
    a.volume = volume;
    a.play().catch(() => { /* user-gesture gated; ignore */ });
  } catch { /* ignore */ }
}

function runCanvas(drawFrame, totalMs) {
  return new Promise(resolve => {
    const canvas = document.createElement('canvas');
    canvas.className = 'celebration';
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    document.body.appendChild(canvas);
    const ctx = canvas.getContext('2d');
    const start = performance.now();
    let raf;
    const tick = (now) => {
      const t = (now - start) / totalMs;
      if (t >= 1) {
        cancelAnimationFrame(raf);
        canvas.remove();
        resolve();
        return;
      }
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      drawFrame(ctx, t, canvas.width, canvas.height);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
  });
}

// Fireworks: 6 bursts, each ~30 particles, gravity-arcing.
function fireworks(ctx, t, W, H) {
  const burstCount = 6;
  for (let b = 0; b < burstCount; b++) {
    const delay = b * 0.12;
    const local = t - delay;
    if (local < 0 || local > 0.6) continue;
    const cx = (W / (burstCount + 1)) * (b + 1) + ((b % 2) ? 30 : -30);
    const cy = H * (0.3 + 0.15 * Math.sin(b));
    const color = COLORS[b % COLORS.length];
    drawBurst(ctx, cx, cy, local / 0.6, color);
  }
}

function drawBurst(ctx, cx, cy, p, color) {
  const N = 30;
  for (let i = 0; i < N; i++) {
    const angle = (i / N) * Math.PI * 2;
    const speed = 180 * p;
    const x = cx + Math.cos(angle) * speed;
    const y = cy + Math.sin(angle) * speed + (p * p * 90);  // gravity
    const alpha = Math.max(0, 1 - p);
    ctx.fillStyle = color;
    ctx.globalAlpha = alpha;
    ctx.beginPath();
    ctx.arc(x, y, 3, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
}

// Rain: 40 blue drops streaming down.
function rain(ctx, t, W, H) {
  const N = 40;
  for (let i = 0; i < N; i++) {
    const x = ((i * 53) % W);
    const speed = 600 + ((i * 31) % 200);
    const y = ((t * speed + i * 47) % (H + 40)) - 20;
    const alpha = Math.max(0, 1 - t * 0.6);
    ctx.strokeStyle = '#118AB2';
    ctx.globalAlpha = alpha;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x - 4, y + 14);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}
