// Webbversionen mot Swift-modellen: samma scenarier, steg för steg (spåren skrevs av test/spar/SparTests.swift).
import { test } from "node:test";
import assert from "node:assert/strict";
import { facit } from "./facit.js";
import { newsExtra, newsRound, snap, systemExtra, systemRound } from "./bottar.js";

function compare(name, expected, play) {
  const steps = [];
  play((g) => steps.push(JSON.parse(JSON.stringify(snap(g, g.title === "Systemknuten" ? systemExtra : newsExtra)))));
  assert.equal(steps.length, expected.length, `${name}: antal steg`);
  expected.forEach((want, i) => assert.deepEqual(steps[i], want, `${name}: steg ${i} (dag ${want.d})`));
}

for (const round of facit.rounds.filter((r) => r.game === "system")) {
  const name = `Systemknuten seed ${round.seed}, ${round.bot}${round.hard ? ", hårda linjer kan falla" : ""}`;
  test(name, () => compare(name, round.steps, (onStep) => systemRound(BigInt(round.seed), round.hard, round.bot, onStep)));
}

for (const round of facit.rounds.filter((r) => r.game === "news")) {
  const name = `Nyhetsknuten ${round.name}, ${round.bot}`;
  test(name, () => compare(name, round.steps, (onStep) => newsRound(round.settings, round.bot, onStep)));
}

for (const s of facit.summary) {
  test(`Systemknuten seed 0–199, ${s.bot}${s.hard ? ", hårda linjer kan falla" : ""}: samma utgång som Swift`, () => {
    const rows = s.rows.map((_, seed) => {
      const g = systemRound(BigInt(seed), s.hard, s.bot);
      return [g.ending?.title ?? null, g.day, g.lamps, g.moves, g.gifts];
    });
    assert.deepEqual(rows, s.rows);
  });
}
