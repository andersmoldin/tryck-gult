// Bordets nätverk: port av GraphLayout, clusters och emojiPositions i Graf.swift (BrytareModell, omgång 9).
// Partierna är noder och trådarna är linjer. Layouten är en enkel kraftsimulering som appen stegar varje bildruta.
// Alla mått är i rutan [-1, 1] × [-1, 1].

import { leftToRight, pairKey, parties, seats } from "./gemensamt.js";

export const GraphMetrics = Object.freeze({
  nodeRadius: (p) => 0.085 + Math.sqrt(seats(p)) * 0.008,
  /** Radien på emojins bakgrundsskiva. */
  emojiRadius: 0.1,
  /** Minsta luft mellan två saker. */
  margin: 0.02,
  /**
   * Hur långt ut ritytan måste räcka. Noderna hålls inom ramen, men en emoji kan sitta 0,18 vid sidan av sin
   * linje: mitten högst 1 − 0,12 (minsta nodradien) + 0,18 = 1,06 från mitten, plus skivans radie 0,1.
   */
  extent: 1.16,
});

export const relationEmoji = { attraction: "🤝", negotiating: "💬", conflict: "✋" };

const dist = (p, q) => Math.sqrt((p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y));
const toward = (p, q, t) => ({ x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t });
const order = (p) => leftToRight.indexOf(p);

/**
 * Moln: grupper av partier som gärna samarbetar. Varje samarbete hör till minst ett moln, och inget moln
 * innehåller två partier med röd linje mellan sig. Ett parti kan sitta i två moln.
 * @param {{ a: string, b: string, kind: string }[]} relations
 * @returns {string[][]}
 */
export function clusters(relations) {
  const conflicts = new Set(relations.filter((r) => r.kind === "conflict").map((r) => pairKey(r.a, r.b)));
  const peaceful = (g) => {
    const list = [...g];
    for (let i = 0; i < list.length; i++) for (const b of list.slice(i + 1)) if (conflicts.has(pairKey(list[i], b))) return false;
    return true;
  };
  const groups = relations.filter((r) => r.kind === "attraction")
    .map((r) => [r.a, r.b])
    .sort((x, y) => { const [a1, b1] = [order(x[0]), order(x[1])], [a2, b2] = [order(y[0]), order(y[1])]; return a1 - a2 || b1 - b2; })
    .map((pair) => new Set(pair));
  let merged = true;
  while (merged) {
    merged = false;
    search: for (let i = 0; i < groups.length; i++) {
      for (let j = i + 1; j < groups.length; j++) {
        if (![...groups[i]].some((p) => groups[j].has(p))) continue;
        const union = new Set([...groups[i], ...groups[j]]);
        if (peaceful(union)) {
          groups[i] = union;
          groups.splice(j, 1);
          merged = true;
          break search;
        }
      }
    }
  }
  return groups.map((g) => [...g].sort((a, b) => order(a) - order(b))).sort((x, y) => order(x[0]) - order(y[0]));
}

const forces = Object.freeze({
  repulsion: 0.09, allyLength: 0.65, allyStrength: 5, negotiatingLength: 0.85, negotiatingStrength: 1.5,
  conflictLength: 1.2, conflictStrength: 2.5, gravity: 0.35,
  /** Knuffar partier bort från linjer de inte hör till, så att ingen nod ligger på en linje. */
  lineRepulsion: 0.05,
  /** Partier i samma block utan egen linje dras ändå mot varandra. */
  blockLength: 0.95, blockStrength: 2.0,
  /** Partier i olika block knuffas isär om de kommer närmare än så här. */
  acrossBlockLength: 1.4, acrossBlockStrength: 2.0,
  damping: 0.85,
});

export class GraphLayout {
  /** Partierna börjar i en båge från vänster till höger. */
  constructor() {
    /** @type {Record<string, {x: number, y: number}>} */
    this.positions = {};
    /** @type {Record<string, {x: number, y: number}>} */
    this.velocities = {};
    leftToRight.forEach((p, i) => {
      const angle = Math.PI - i * Math.PI / (leftToRight.length - 1);
      this.positions[p] = { x: 0.7 * Math.cos(angle), y: 0.2 - 0.7 * Math.sin(angle) };
      this.velocities[p] = { x: 0, y: 0 };
    });
  }

  distance(a, b) { return dist(this.positions[a], this.positions[b]); }

  /** En liten knuff utåt och runt, så att det syns att något ändrades. */
  nudge() {
    for (const p of parties) {
      const pos = this.positions[p], v = this.velocities[p];
      v.x += 0.04 * pos.x - 0.03 * pos.y;
      v.y += 0.04 * pos.y + 0.03 * pos.x;
    }
  }

  /** Ett steg i simuleringen. */
  step(relations, dt = 1 / 60) {
    const f = forces;
    const kinds = new Map(relations.map((r) => [pairKey(r.a, r.b), r.kind]));
    const groups = clusters(relations).map((g) => new Set(g));
    const grouped = new Set(groups.flatMap((g) => [...g]));
    const force = Object.fromEntries(parties.map((p) => [p, { x: 0, y: 0 }]));
    const push = (p, fx, fy) => { force[p].x += fx; force[p].y += fy; };
    for (let i = 0; i < parties.length; i++) {
      for (let j = i + 1; j < parties.length; j++) {
        const a = parties[i], b = parties[j];
        const pa = this.positions[a], pb = this.positions[b];
        let dx = pb.x - pa.x, dy = pb.y - pa.y;
        let d = Math.sqrt(dx * dx + dy * dy);
        if (d < 0.01) { dx = 0.01; dy = 0; d = 0.01; }
        let pull = -f.repulsion / (d * d); // positivt = dras ihop
        switch (kinds.get(pairKey(a, b))) {
          case "attraction": pull += f.allyStrength * (d - f.allyLength); break;
          case "negotiating": pull += f.negotiatingStrength * (d - f.negotiatingLength); break;
          case "conflict": pull += f.conflictStrength * Math.min(0, d - f.conflictLength); break;
          default:
            if (groups.some((g) => g.has(a) && g.has(b))) pull += f.blockStrength * (d - f.blockLength);
            else if (grouped.has(a) && grouped.has(b)) pull += f.acrossBlockStrength * Math.min(0, d - f.acrossBlockLength);
        }
        push(a, pull * dx / d, pull * dy / d);
        push(b, -pull * dx / d, -pull * dy / d);
      }
    }
    for (const line of relations) {
      const a = this.positions[line.a], b = this.positions[line.b];
      const abx = b.x - a.x, aby = b.y - a.y;
      const len2 = Math.max(abx * abx + aby * aby, 1e-6);
      for (const p of parties) {
        if (p === line.a || p === line.b) continue;
        const pos = this.positions[p];
        // Närmaste punkt på linjen.
        const t = Math.min(1, Math.max(0, ((pos.x - a.x) * abx + (pos.y - a.y) * aby) / len2));
        const q = toward(a, b, t);
        let dx = pos.x - q.x, dy = pos.y - q.y;
        let d = Math.sqrt(dx * dx + dy * dy);
        if (d < 0.01) { dx = -aby; dy = abx; d = Math.max(Math.sqrt(dx * dx + dy * dy), 1e-6); }
        const away = f.lineRepulsion / Math.max(d * d, 0.0025);
        push(p, away * dx / d, away * dy / d);
        // Linjens ändar får motkraften i proportion till var på linjen trycket sitter.
        push(line.a, -away * dx / d * (1 - t), -away * dy / d * (1 - t));
        push(line.b, -away * dx / d * t, -away * dy / d * t);
      }
    }
    for (const p of parties) {
      const v = this.velocities[p], pos = this.positions[p];
      v.x = (v.x + (force[p].x - f.gravity * pos.x) * dt) * f.damping;
      v.y = (v.y + (force[p].y - f.gravity * pos.y) * dt) * f.damping;
      // Håll hela noden (med radie) inom ramen, inte bara mittpunkten.
      const limit = 1 - GraphMetrics.nodeRadius(p);
      pos.x = Math.min(limit, Math.max(-limit, pos.x + v.x));
      pos.y = Math.min(limit, Math.max(-limit, pos.y + v.y));
    }
  }
}

/**
 * Var emojin på varje linje ska sitta: så nära mitten som möjligt, men flyttad längs linjen – och vid behov
 * en bit åt sidan (högst 0,18) – om den annars skulle krocka med ett parti eller en annan emoji.
 * @returns {Map<string, {x: number, y: number}>} parnyckel → punkt
 */
export function emojiPositions(layout, lines) {
  const M = GraphMetrics;
  // Mitten först, sedan växelvis utåt mot ändarna.
  const candidates = [0.5];
  for (let i = 1; i <= 12; i++) candidates.push(0.5 - 0.03 * i, 0.5 + 0.03 * i);
  const placed = new Map();
  const clearance = (e) => Math.min(
    ...parties.map((p) => dist(e, layout.positions[p]) - M.nodeRadius(p) - M.emojiRadius),
    ...[...placed.values()].map((q) => dist(e, q) - 2 * M.emojiRadius),
  );
  // Korta linjer har minst utrymme att flytta emojin på, så de får välja först.
  const sorted = [...lines].sort((l1, l2) => layout.distance(l1.a, l1.b) - layout.distance(l2.a, l2.b));
  for (const line of sorted) {
    const a = layout.positions[line.a], b = layout.positions[line.b];
    const len = Math.max(dist(a, b), 1e-6);
    const normal = { x: -(b.y - a.y) / len, y: (b.x - a.x) / len };
    const spots = [0.0, 0.09, -0.09, 0.18, -0.18].flatMap((off) => candidates.map((t) => {
      const q = toward(a, b, t);
      return { x: q.x + normal.x * off, y: q.y + normal.y * off };
    }));
    let best = spots.find((s) => clearance(s) >= M.margin);
    if (!best) best = spots.reduce((m, s) => (clearance(s) > clearance(m) ? s : m));
    placed.set(pairKey(line.a, line.b), best);
  }
  return placed;
}
