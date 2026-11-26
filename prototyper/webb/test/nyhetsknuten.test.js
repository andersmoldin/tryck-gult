// Port av NewsKnotTests.swift och Nyhetsknutens delar av Round9Tests.swift.
import { test } from "node:test";
import assert from "node:assert/strict";
import { NewsKnotGame, defaultNewsSettings } from "../modell/nyhetsknuten.js";
import { RumorMode, lastDay, parties } from "../modell/gemensamt.js";
import { newsRound } from "./bottar.js";

/** Gå fram till första verkliga nyheten som har reaktioner (inte en gåva). */
function toReactableNews(g) {
  for (let i = 0; i < 200; i++) {
    const n = g.paused;
    if (n) {
      if (n.tag !== "locks" && n.kind !== "rumor") return;
      g.play(g.newsChoices[0].id);
    }
    g.tick(1);
  }
}

const playLast = (g) => g.play(g.newsChoices[g.newsChoices.length - 1].id);

test("Tre spår från extraval till regering, och klockan stannar vid första nyheten", () => {
  const g = new NewsKnotGame(defaultNewsSettings());
  assert.deepEqual(g.bars.map((b) => b.label), ["◀ Vänster", "● Mitten", "▶ Höger"]);
  assert.ok(g.bars.every((b) => b.marks.join() === "60,85" && b.max === 100));
  g.tick(5);
  assert.equal(g.paused?.kind, "real"); // gåvan 14 sep stoppar klockan
  toReactableNews(g);
  assert.ok(g.newsChoices.length >= 2);
});

test("En reaktion på nyheten kostar spaltmeter, verkar på spåret och låter tiden gå igen", () => {
  const g = new NewsKnotGame(defaultNewsSettings());
  toReactableNews(g);
  const sp = g.spaltmeter;
  g.play(g.newsChoices.find((c) => c.id.startsWith("remind")).id);
  assert.equal(g.paused, null);
  assert.equal(g.spaltmeter, sp - 1);
  assert.notEqual(g.effect, null);
});

test("En gåva har en enda knapp och ger spaltmeter", () => {
  const g = new NewsKnotGame(defaultNewsSettings());
  while (g.paused?.tag !== "locks") { if (g.paused) playLast(g); g.tick(1); }
  assert.deepEqual(g.newsChoices.map((c) => c.title), ["TACK SÅ MYCKET"]);
  const sp = g.spaltmeter;
  g.play(g.newsChoices[0].id);
  assert.ok(g.spaltmeter > sp);
});

test("Läckan kan läggas på en känd deadline: omröstningen 15 okt är dag 32", () => {
  const g = new NewsKnotGame(defaultNewsSettings());
  while (g.day < 29) { if (g.paused) playLast(g); g.tick(1); }
  if (g.paused) playLast(g);
  assert.ok(g.cards.some((c) => c.id.startsWith("leak") && c.id.endsWith(".32")));
});

test("Ryktesinställningen: A har bara föremål och processer, B även namngivna partimöten", () => {
  const a = NewsKnotGame.rumors(RumorMode.ownMovesOnly), b = NewsKnotGame.rumors(RumorMode.alsoRealPartyMeetings);
  assert.ok(a.length > 0 && b.length > a.length);
  const named = b.filter((r) => !a.includes(r));
  assert.ok(named.every((r) => parties.some((p) => r.title.includes(p + " "))));
  assert.ok(a.every((r) => !parties.some((p) => r.title.includes(p + " "))));
});

test("Anonyma källor går att stänga av", () => {
  assert.ok(NewsKnotGame.news(true).some((n) => n.kind === "anonymous"));
  assert.ok(!NewsKnotGame.news(false).some((n) => n.kind === "anonymous"));
});

test("Utan slutspurt slutar spelet 18 nov med Fortsättning följer", () => {
  const g = newsRound({ ...defaultNewsSettings(), finale: false }, "active");
  assert.notEqual(g.ending, null);
  assert.ok(g.day <= lastDay);
});

test("Passiv spelare förlorar, aktiv vinner, och domen räknar gåvorna", () => {
  const passive = newsRound(defaultNewsSettings(), "passive");
  const active = newsRound(defaultNewsSettings(), "active");
  assert.equal(passive.ending?.isExtraval, false);
  assert.equal(active.ending?.isExtraval, true);
  assert.ok(active.ending.text.includes("Partiledarna gjorde"));
});

test("Rykten stoppar inte tiden utan blir aviseringar", () => {
  const g = new NewsKnotGame({ ...defaultNewsSettings(), rumors: RumorMode.alsoRealPartyMeetings });
  let pausedOnRumor = false;
  while (g.day < 40 && g.ending === null) {
    if (g.paused) { if (g.paused.kind === "rumor") pausedOnRumor = true; playLast(g); }
    g.tick(1);
  }
  assert.equal(pausedOnRumor, false);
  assert.ok(g.notices.some((n) => n.kind === "rumor" && n.text.includes("C och S har setts äta lunch")));
});

test("Varje knapp visar riktning, storlek och kostnad före valet", () => {
  const g = new NewsKnotGame(defaultNewsSettings());
  toReactableNews(g);
  assert.ok(g.newsChoices.every((c) => (c.preview ?? "") !== ""));
  const remind = g.newsChoices.find((c) => c.id.startsWith("remind"));
  assert.ok(remind.preview.includes("1 spaltmeter"));
  assert.ok(remind.preview.includes("▼") || remind.preview.includes("ingen effekt"));
  g.play(remind.id);
  assert.ok(g.effect?.reason);
  while (g.cards.length === 0 && g.ending === null) { if (g.paused) playLast(g); g.tick(1); }
  assert.ok(g.cards.every((c) => (c.preview ?? "") !== ""));
});

test("Tur för tur: flera drag samma dag, begränsade av spaltmetern", () => {
  const g = new NewsKnotGame(defaultNewsSettings());
  while (g.spaltmeter < 6 || g.paused) { if (g.paused) playLast(g); else g.tick(1); }
  const day = g.day, sp = g.spaltmeter;
  g.play(g.cards[0].id);
  g.play(g.cards[0].id);
  assert.equal(g.day, day);
  assert.equal(g.spaltmeter, sp - 4);
  while (g.cards.length > 0) g.play(g.cards[0].id);
  assert.ok(g.spaltmeter < 2);
  assert.equal(g.day, day);
});
