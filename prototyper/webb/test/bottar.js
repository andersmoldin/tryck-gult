// Testspelarna, porterade ur Swift-testerna (SystemKnotTests.swift, NewsKnotTests.swift och SparTests.swift),
// och ögonblicksbilden som spåren jämförs med. Bilden har samma form som `snap` i test/spar/SparTests.swift.
import { NewsKnotGame } from "../modell/nyhetsknuten.js";
import { SystemKnotGame, bySeatsThenRiskDesc, stamps } from "../modell/systemknuten.js";
import { parties } from "../modell/gemensamt.js";

const choices = (cs) => cs.map((c) => [c.id, c.title, c.quip, c.icon ?? null, c.preview ?? null]);

export function snap(g, extra) {
  const p = g.paused && [g.paused.day, g.paused.kind, g.paused.title, g.paused.source, g.paused.tag];
  return {
    d: g.day,
    p: p ?? null,
    m: g.meters.map((m) => [m.name, m.value, m.caption ?? null]),
    b: g.bars.map((b) => [b.label, b.value, b.ghost, b.max, b.marks, b.isLeading]),
    nc: choices(g.newsChoices),
    c: choices(g.cards),
    n: g.notices.map((n) => [n.day, n.kind, n.text]),
    e: g.effect && [g.effect.title, g.effect.tone, g.effect.chips, g.effect.reason ?? null],
    end: g.ending && [g.ending.title, g.ending.text, g.ending.isExtraval, g.ending.footnote ?? null],
    r: g.relations.map((r) => [r.a, r.b, r.kind, r.label, r.isNew, r.isRumor]),
    x: extra(g),
  };
}

export const newsExtra = (g) => [g.spaltmeter, g.lamps, g.moves, g.gifts];
export const systemExtra = (g) => [parties.map((p) => g.patience[p]), stamps.map((m) => g.charges[m]), g.lamps, g.moves, g.gifts];

/** Rapportens vakna testspelare (Bilaga B). */
export function awakeMove(g) {
  const active = Object.values(g.tracks).filter((t) => t.active).sort((a, b) => g.meter(b).solid - g.meter(a).solid);
  for (const t of active) {
    const { solid, soon } = g.wouldLockSoon(t);
    const voteSoon = g.votes.some((v) => v.track === t.name && v.day - g.day <= 1);
    if (!(solid >= 175 || soon >= 175)) continue;
    const opts = g.swingOptions(t).filter((o) => o.risk > 18).sort(bySeatsThenRiskDesc);
    if (opts[0] && g.charges.leak > 0) { g.leak(opts[0].x, opts[0].y); return; }
    if (voteSoon && g.charges.delay > 0) { g.delay(); return; }
    if (solid >= 175 && g.charges.delay > 0) { g.delay(); return; }
  }
  // Säkring: ett parti med nästan tom stubin vars eftergift skulle ge ett spår 175.
  for (const x of [...parties].sort((a, b) => g.patience[a] - g.patience[b])) {
    if (g.patience[x] > 14 || g.charges.demand === 0) break;
    const mine = g.constraints.filter((c) => c.party === x && !c.player).sort((c1, c2) => (!c1.hard && c2.hard ? -1 : !c2.hard && c1.hard ? 1 : 0));
    const first = mine[0];
    if (!first || g.constraints.some((c) => c.player && c.party === x && g.day <= c.until)) continue;
    const probe = g.clone();
    probe.constraints = probe.constraints.filter((c) => c.id !== first.id);
    if (Object.values(probe.tracks).filter((t) => t.active).some((t) => probe.wouldLockSoon(t).soon >= 175)) {
      g.demand(x); return;
    }
  }
}

/** En hel runda Systemknuten med en testspelare ("passive", "awake", "varied" eller "krav"); `onStep` får varje steg. */
export function systemRound(seed, hard, bot, onStep = () => {}) {
  const g = new SystemKnotGame(seed, hard);
  onStep(g);
  for (let k = 0; k < 200 && g.ending === null; k++) {
    if (g.paused !== null) g.resume();
    if (bot === "awake") awakeMove(g);
    if (bot === "varied" && k % 4 === 0 && g.cards.length > 0) g.play(g.cards[Math.floor(k / 4) % g.cards.length].id);
    // "krav": KRAV på L så fort stämpeln är laddad, så att två krav i rad får L att spricka.
    if (bot === "krav" && g.charges.demand > 0) g.demand("L");
    g.tick(1);
    onStep(g);
  }
  return g;
}

/** En hel runda Nyhetsknuten med en testspelare ("passive", "active" eller "varied"). */
export function newsRound(settings, bot, onStep = () => {}) {
  const g = new NewsKnotGame(settings);
  onStep(g);
  for (let k = 0; k < 400 && g.ending === null; k++) {
    if (g.paused !== null) {
      const c = g.newsChoices;
      const hit = c.find((x) => x.id.startsWith("remind"));
      if (bot === "active" && hit) g.play(hit.id);
      else if (bot === "varied" && c.length > 0) g.play(c[k % c.length].id);
      else if (c.length > 0) g.play(c[c.length - 1].id);
      else g.resume();
      onStep(g);
      continue;
    }
    const leak = g.cards.find((x) => x.id.startsWith("leak"));
    const sega = g.cards.find((x) => x.id === "sega");
    if (bot === "active" && leak) g.play(leak.id);
    else if (bot === "active" && sega) g.play(sega.id);
    else if (bot === "varied" && g.cards.length > 0 && k % 3 !== 2) g.play(g.cards[k % g.cards.length].id);
    g.tick(1);
    onStep(g);
  }
  return g;
}
