// Port av SystemKnotTests.swift och Systemknutens delar av Round9Tests.swift.
import { test } from "node:test";
import assert from "node:assert/strict";
import { SystemKnotGame } from "../modell/systemknuten.js";
import { int, pairKey } from "../modell/gemensamt.js";
import { systemRound } from "./bottar.js";

const advance = (g, until) => { while (!until(g)) { if (g.paused) g.resume(); g.tick(1); } };

test("Aritmetiken: Blått M+KD+L är 111 på valnatten och Ribban startar under 175", () => {
  const g = new SystemKnotGame(1n);
  assert.equal(g.meter(g.tracks["Blått"]).solid, 111);
  assert.ok(g.bars.every((b) => b.value < 175));
  assert.equal(g.charges.leak, 1); // LÄCKA upplåst dag 0
});

test("Samma seed ger samma runda", () => {
  const a = systemRound(42n, false, "passive"), b = systemRound(42n, false, "passive");
  assert.deepEqual(a.ending, b.ending);
  assert.equal(a.day, b.day);
});

test("Klockan stannar vid verkliga nyheter", () => {
  const g = new SystemKnotGame(3n);
  advance(g, (x) => x.day >= 5);
  assert.equal(g.paused?.kind, "real");
  assert.ok(g.paused.source.includes("#4"));
});

test("Läckan sänker tråden med 40 när handslaget inte är färskt", () => {
  const g = new SystemKnotGame(5n);
  const before = g.rel.get(pairKey("S", "MP"));
  g.leak("S", "MP");
  assert.equal(g.rel.get(pairKey("S", "MP")), Math.max(-100, before - 40));
  assert.equal(g.moves, 1);
  assert.equal(g.charges.leak, 0);
});

test("Två krav på samma parti får det att spricka och släppa sina mjuka krav", () => {
  const g = new SystemKnotGame(6n);
  advance(g, (x) => x.day >= 14); // KRAV laddas igen dag 14
  g.demand("L");
  assert.ok(g.constraints.some((c) => c.player && c.party === "L"));
  advance(g, (x) => x.charges.demand > 0);
  g.demand("L");
  assert.ok(!g.constraints.some((c) => c.party === "L" && !c.hard));
});

test("Simuleringen: utan drag vinner man ibland, med vaken läsning oftast (rapportens spann)", () => {
  const n = 200;
  const wins = (bot) => Array.from({ length: n }, (_, s) => systemRound(BigInt(s), false, bot)).filter((g) => g.ending?.isExtraval).length;
  const passive = wins("passive"), awake = wins("awake");
  assert.ok(passive / n >= 0.10 && passive / n <= 0.45, `passiv ${passive}/${n}`);
  assert.ok(awake / n >= 0.70, `vaken ${awake}/${n}`);
  assert.ok(awake > passive);
});

test("Hårda röda linjer faller inte av tålamod i förvalet", () => {
  for (let seed = 0; seed < 30; seed++) {
    const g = systemRound(BigInt(seed), false, "passive");
    assert.ok(g.constraints.some((c) => c.id === "C-inteV"), `seed ${seed}`);
  }
});

test("Förhandsvisningen av en läcka stämmer med vad som händer", () => {
  const g = new SystemKnotGame(11n);
  advance(g, (x) => x.cards.some((c) => c.id.startsWith("leak")));
  const leak = g.cards.find((c) => c.id.startsWith("leak"));
  const lead = g.leading.name;
  const copy = g.clone();
  copy.play(leak.id);
  const after = int(copy.meter(copy.tracks[lead]).solid);
  assert.ok(leak.preview.includes(`Ribban ${lead}`));
  assert.ok(leak.preview.includes(`→ ${after}`));
  g.play(leak.id);
  assert.ok(g.effect?.reason);
});

test("Förhandsvisningen ändrar inte bordet", () => {
  const g = new SystemKnotGame(11n);
  advance(g, (x) => x.cards.length >= 2);
  const before = JSON.stringify([[...g.rel], g.patience, g.charges, g.constraints.map((c) => c.id), g.votes, g.moves]);
  void g.cards;
  assert.equal(JSON.stringify([[...g.rel], g.patience, g.charges, g.constraints.map((c) => c.id), g.votes, g.moves]), before);
});

test("Simuleringens påhitt blir aviseringar, inte nyhetskort", () => {
  const g = new SystemKnotGame(2n);
  for (let i = 0; i < 70 && g.ending === null; i++) {
    if (g.paused) { assert.equal(g.paused.kind, "real"); g.resume(); }
    g.tick(1);
  }
  assert.ok(g.notices.every((n) => n.kind !== "real"));
});
