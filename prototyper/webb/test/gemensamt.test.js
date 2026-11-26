import { test } from "node:test";
import assert from "node:assert/strict";
import { dateText, lastDay } from "../modell/gemensamt.js";
import { SeededRandom } from "../modell/systemknuten.js";
import { facit } from "./facit.js";

test("dateText: valdagen, månadsskiften och sista dagen", () => {
  assert.equal(dateText(0), "13 sep");
  assert.equal(dateText(18), "1 okt");
  assert.equal(dateText(32), "15 okt");
  assert.equal(dateText(lastDay), "18 nov");
});

test("dateText stämmer med Swift för dag 0–80", () => {
  assert.deepEqual(Array.from({ length: 81 }, (_, d) => dateText(d)), facit.dates);
});

test("SeededRandom ger samma 64-bitarstal som Swift", () => {
  const rng = new SeededRandom(12345n);
  assert.deepEqual(Array.from({ length: 20 }, () => String(rng.next())), facit.random);
});
