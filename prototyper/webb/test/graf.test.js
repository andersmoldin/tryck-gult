// Port av GraphTests.swift (grafens egenskaper), körd på bordet så som Systemknuten bygger det dag för dag.
import { test } from "node:test";
import assert from "node:assert/strict";
import { GraphLayout, GraphMetrics as M, clusters, emojiPositions } from "../modell/graf.js";
import { pairKey, parties } from "../modell/gemensamt.js";
import { systemRound } from "./bottar.js";
import { SystemKnotGame } from "../modell/systemknuten.js";

/** Bordets linjer varje dag i en runda, och layouten så som appen bygger den vidare med en knuff vid ändring. */
function replay(seed, bot, check) {
  const layout = new GraphLayout();
  let last = null;
  systemRound(seed, false, bot, (g) => {
    const lines = g.relations;
    const shape = JSON.stringify(lines.map((l) => [l.pair, l.kind]));
    if (last !== null && shape !== last) layout.nudge();
    last = shape;
    for (let i = 0; i < 900; i++) layout.step(lines);
    check(g.day, layout, lines);
  });
}

const rounds = [[0n, "passive"], [7n, "awake"], [42n, "varied"]];

test("Moln: samarbetsgrupper utan röd linje inuti, och varje samarbete ligger i ett moln", () => {
  for (const [seed, bot] of rounds) {
    systemRound(seed, false, bot, (g) => {
      const lines = g.relations;
      const groups = clusters(lines);
      const conflicts = new Set(lines.filter((l) => l.kind === "conflict").map((l) => l.pair));
      for (const grp of groups) {
        grp.forEach((a, i) => grp.slice(i + 1).forEach((b) => assert.ok(!conflicts.has(pairKey(a, b)), `dag ${g.day}`)));
      }
      for (const l of lines.filter((x) => x.kind === "attraction")) {
        assert.ok(groups.some((grp) => grp.includes(l.a) && grp.includes(l.b)), `dag ${g.day}: ${l.pair}`);
      }
    });
  }
});

test("Valnattens bord: S och MP i ett moln, Kristerssons sida med SD i ett annat", () => {
  const g = new SystemKnotGame(0n);
  assert.deepEqual(clusters(g.relations), [["S", "MP"], ["L", "KD", "M", "SD"]]);
});

test("Partierna ryms inom ramen, emojierna inom ritytan, och emojin sitter vid sin linje", () => {
  for (const [seed, bot] of rounds) {
    replay(seed, bot, (day, l, lines) => {
      for (const p of parties) {
        const pos = l.positions[p], r = M.nodeRadius(p);
        assert.ok(Math.abs(pos.x) + r <= 1 && Math.abs(pos.y) + r <= 1, `dag ${day}: ${p}`);
      }
      const spots = emojiPositions(l, lines);
      assert.equal(spots.size, lines.length);
      for (const line of lines) {
        const a = l.positions[line.a], b = l.positions[line.b], e = spots.get(line.pair);
        assert.ok(Math.abs(e.x) + M.emojiRadius <= M.extent && Math.abs(e.y) + M.emojiRadius <= M.extent, `dag ${day}`);
        const len = Math.hypot(b.x - a.x, b.y - a.y);
        const cross = Math.abs((b.x - a.x) * (a.y - e.y) - (a.x - e.x) * (b.y - a.y)) / len;
        assert.ok(cross <= 0.18 + 1e-9, `dag ${day}: ${line.pair}`);
      }
    });
  }
});

test("Partierna överlappar aldrig, med marginal", () => {
  for (const [seed, bot] of rounds) {
    replay(seed, bot, (day, l) => {
      parties.forEach((a, i) => parties.slice(i + 1).forEach((b) => {
        assert.ok(l.distance(a, b) >= M.nodeRadius(a) + M.nodeRadius(b) + M.margin, `seed ${seed} dag ${day}: ${a}–${b}`);
      }));
    });
  }
});

test("En knuff flyttar noderna mer än ett vanligt steg, och de lägger sig igen", () => {
  const lines = new SystemKnotGame(0n).relations;
  const still = new GraphLayout();
  for (let i = 0; i < 900; i++) still.step(lines);
  const copy = (src) => { const c = new GraphLayout(); c.positions = structuredClone(src.positions); c.velocities = structuredClone(src.velocities); return c; };
  const nudged = copy(still), plain = copy(still);
  nudged.nudge(); nudged.step(lines);
  plain.step(lines);
  assert.ok(parties.some((p) => Math.hypot(nudged.positions[p].x - plain.positions[p].x, nudged.positions[p].y - plain.positions[p].y) > 0.01));
  for (let i = 0; i < 900; i++) nudged.step(lines);
  const rested = structuredClone(nudged.positions);
  nudged.step(lines);
  for (const p of parties) assert.ok(Math.hypot(nudged.positions[p].x - rested[p].x, nudged.positions[p].y - rested[p].y) < 0.001);
});
