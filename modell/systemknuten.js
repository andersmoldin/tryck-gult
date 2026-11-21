// Systemknuten: port av Systemknuten.swift (BrytareModell, omgång 9), som i sin tur översätter simuleringen
// i data/tg-knut-system/report.md (Bilaga A och B). Partierna förhandlar av sig själva: trådar växer mot sina
// tak, tålamod brinner ner tills partier släpper mjuka krav, och Ribban visar hur många mandat som trycker ja
// eller gult för det ledande spåret. Spelaren är knuten och stoppar det med tre stämplar som laddas om.
//
// Ordningen i varje loop och varje flyttalsuttryck följer Swift-koden exakt, så att samma seed ger samma
// runda i båda implementationerna (test/spar.test.js jämför mot spår som Swift-modellen skrev).

import { allPairs, comparePairs, dateText, int, lampText, majority, maxBy, pairKey, pairParts, parties, seats } from "./gemensamt.js";

const MASK = (1n << 64n) - 1n;

/** Seedad slump (SplitMix64) så att en runda går att spela om och testa. */
export class SeededRandom {
  /** @param {bigint} seed ett 64-bitars heltal utan tecken */
  constructor(seed) {
    this.state = (BigInt.asUintN(64, seed) + 0x9E3779B97F4A7C15n) & MASK;
  }
  /** @returns {bigint} */
  next() {
    this.state = (this.state + 0x9E3779B97F4A7C15n) & MASK;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & MASK;
    return z ^ (z >> 31n);
  }
  /** Likformigt i [a, b]. */
  uniform(a, b) {
    return a + (b - a) * Number(this.next() >> 11n) / 2 ** 53;
  }
}

/** Siffrorna ur rapportens Bilaga A (Tuning.json). */
export const SystemTuning = Object.freeze({
  days: 68,
  tryckStart: 1.0, tryckEnd: 2.0,
  patienceDrain: 1.15,
  patienceAfterYield: 50.0, patienceAfterBreakingPoint: 30.0,
  driftK: 4.5, desperation: 25.0, overCeilDecay: 0.5,
  mediatorBonus: 1.4,
  handshakeDecay: 0.5,
  lockAt: 70.0, redAt: -30.0,
  demandCap: 0.6, ghostFrom: 0.8,
  graddfilDays: 3, graddfilSolid: 175.0, failedVoteTryck: 0.15, impFloor: 0.3, voteCooldownDays: 8, failedVoteHit: 15.0,
  leakHit: 40.0, freshLeakHit: 75.0, freshDays: 4, leakPatienceCost: 7.0,
  kravDays: 10, kravPatience: 15.0, burstPatience: 15.0,
  forhalaDays: 4, forhalaVotePush: 3, forhalaTryck: 0.1,
  patienceJitter: 12.0, driftNoise: 0.25,
});
const T = SystemTuning;

/** Stämplarna i Swifts ordning (Stamp.allCases), med (högst, dagar per laddning, upplåst dag). */
export const stamps = ["leak", "demand", "delay"];
const charging = { leak: { max: 2, per: 7, unlock: 0 }, demand: { max: 1, per: 9, unlock: 5 }, delay: { max: 1, per: 14, unlock: 19 } };

const startPatience = { S: 70, M: 70, SD: 92, V: 75, C: 72, KD: 65, MP: 60, L: 70 };

/** @type {[string, string, number][]} */
const startRel = [
  ["S", "MP", 75], ["S", "V", 55], ["S", "C", 10], ["S", "M", -20], ["S", "KD", -20],
  ["S", "L", -35], ["S", "SD", -100],
  ["M", "KD", 85], ["M", "L", 80], ["KD", "L", 75], ["M", "SD", 75], ["KD", "SD", 70],
  ["L", "SD", 55], ["M", "C", 20], ["KD", "C", 20], ["L", "C", 35],
  ["C", "MP", 20], ["C", "V", -40], ["C", "SD", -60],
  ["V", "M", -100], ["V", "SD", -100], ["V", "KD", -60], ["V", "L", -60], ["V", "MP", 60],
  ["MP", "M", -20], ["MP", "KD", -10], ["MP", "L", 0], ["MP", "SD", -70],
];

/** @type {Map<string, number>} */
const ceilings = new Map(/** @type {[string, string, number][]} */ ([
  ["S", "MP", 95], ["S", "V", 90], ["S", "C", 85], ["S", "L", 45], ["S", "KD", 30], ["S", "M", 55], ["S", "SD", -100],
  ["M", "KD", 100], ["M", "L", 95], ["M", "SD", 90], ["M", "C", 85], ["M", "MP", 30], ["M", "V", -100],
  ["SD", "KD", 90], ["SD", "L", 70], ["SD", "C", 10], ["SD", "MP", -50], ["SD", "V", -100],
  ["V", "MP", 90], ["V", "KD", 0], ["V", "L", 10], ["V", "C", 50],
  ["C", "L", 90], ["C", "KD", 80], ["C", "MP", 80], ["KD", "MP", 40], ["KD", "L", 95], ["MP", "L", 60],
]).map(([a, b, v]) => [pairKey(a, b), v]));
if (ceilings.size !== 28) throw new Error("ett tak per par");

const frozenStart = [pairKey("S", "SD"), pairKey("V", "M"), pairKey("V", "SD")];

/** Den hårda röda linje som ett krav motsvarar i nätet. */
const redLinePairs = { "C-inteV": pairKey("C", "V"), "V-aldrigKristersson": pairKey("V", "M"), "S-inteTidö2": pairKey("S", "M") };

const fiction = "Rubrikerna är verkliga. Ryktena och utgången är spelets påhitt – det hände inte i verkligheten.";

/** @typedef {{ name: string, leader: string, members: string[], active: boolean, cooldownUntil: number }} Track */
/** @typedef {{ id: string, party: string, kind: "red" | "demand", hard: boolean, applies: (t: Track) => boolean, until: number, player: boolean }} Constraint */

const track = (name, leader, members, active) => ({ name, leader, members, active, cooldownUntil: -1 });
const constraint = (id, party, kind, hard, applies, until = 999, player = false) => ({ id, party, kind, hard, applies, until, player });

/** Tupeljämförelse (x1, y1) < (x2, y2). */
const tupleLess = (x1, y1, x2, y2) => x1 < x2 || (x1 === x2 && y1 < y2);

export class SystemKnotGame {
  /**
   * @param {bigint} [seed] utelämnas bara av clone()
   * @param {boolean} [hardLinesCanFall] inställning B: även hårda röda linjer kan falla efter två eftergifter
   */
  constructor(seed, hardLinesCanFall = false) {
    if (seed === undefined) return; // används bara av clone()
    this.title = "Systemknuten";
    this.tips = [
      "Du är knuten. Åtta partier förhandlar av sig själva, och Ribban visar hur nära en regering det är: mandat som trycker ja eller gult för det ledande spåret.",
      "Når Ribbans fasta fyllnad 175 kallar talmannen till omröstning om tre dagar. Står den kvar då bildas en regering och du har förlorat. Faller den släcks en lampa.",
      "Tre stämplar laddas om med tiden: LÄCKA skadar en tråd, KRAV får ett parti att kräva något nytt av det ledande spåret, FÖRHALA stoppar allt några dagar. Varje drag gör partierna otåligare – och otåliga partier ger vika.",
      "Extraval 20 nov är vinst. Fyra släckta lampor före dess är fullträff. Allt simuleringen hittar på är märkt TÄNK OM.",
    ];
    this.hardLinesCanFall = hardLinesCanFall;
    this.day = 0;
    this.paused = null;
    this.effect = null;
    this.ending = null;
    this.notices = [];
    this.lamps = 4;
    this.charges = { leak: 0, demand: 0, delay: 0 };
    this.moves = 0;
    this.gifts = 0;
    /** @type {Map<string, number>} */
    this.rel = new Map();
    /** @type {Map<string, number>} */
    this.formed = new Map();
    /** @type {Record<string, number>} */
    this.patience = {};
    /** @type {Constraint[]} */
    this.constraints = [];
    /** @type {Record<string, Track>} */
    this.tracks = {};
    /** @type {{ day: number, track: string, real: boolean }[]} */
    this.votes = [];
    this.tryckBonus = 0.0;
    this.freezeUntil = -1;
    this.rottSurgeFrom = 999;
    this.recharged = { leak: 0, demand: 0, delay: 0 };
    /** @type {Map<string, number>} */
    this.noise = new Map();
    this.frozen = new Set(frozenStart);
    /** @type {Record<string, number>} */
    this.yields = {};
    /** @type {Map<string, string>} */
    this.previousKinds = new Map();
    /** @type {Map<string, number>} */
    this.kindsChangedOn = new Map();

    const rng = new SeededRandom(seed);
    for (const pair of allPairs()) this.rel.set(pair, 0);
    for (const [a, b, v] of startRel) this.rel.set(pairKey(a, b), v);
    for (const pair of [...this.rel.keys()].sort(comparePairs)) {
      this.noise.set(pair, 1 + rng.uniform(-T.driftNoise, T.driftNoise));
      if (this.rel.get(pair) >= T.lockAt) this.formed.set(pair, -99);
    }
    const j = T.patienceJitter;
    for (const p of ["S", "M", "SD", "V", "C", "KD", "MP", "L"]) {
      this.patience[p] = Math.max(10, Math.min(100, startPatience[p] + rng.uniform(-j, j)));
    }
    this.tracks = {
      "Rött": track("Rött", "S", ["S"], true),
      "Blått": track("Blått", "M", ["M", "KD", "L"], true),
      "Mitten": track("Mitten", "C", ["C"], false),
    };
    this.constraints = [
      constraint("C-inteV", "C", "red", true, (t) => t.members.includes("V")),
      constraint("V-iRegeringen", "V", "demand", false, (t) => !t.members.includes("V")),
      constraint("V-aldrigKristersson", "V", "red", true, (t) => t.leader === "M"),
      constraint("SD-ministrar", "SD", "demand", false, (t) => !t.members.includes("SD")),
      constraint("L-Kristersson", "L", "demand", false, (t) => t.leader !== "M"),
      constraint("KD-borgerligt", "KD", "demand", false, (t) => t.leader === "S"),
    ];
    this.previousKinds = new Map(this.shownRelations().map((r) => [r.pair, r.kind]));
    this.beginDay();
  }

  /** En oberoende kopia (Swift-structens värdesemantik), för förhandsvisningar och testspelare. */
  clone() {
    const c = new SystemKnotGame();
    for (const [k, v] of Object.entries(this)) c[k] = v;
    c.notices = [...this.notices];
    c.charges = { ...this.charges };
    c.rel = new Map(this.rel);
    c.formed = new Map(this.formed);
    c.patience = { ...this.patience };
    c.constraints = this.constraints.map((x) => ({ ...x }));
    c.tracks = Object.fromEntries(Object.entries(this.tracks).map(([k, t]) => [k, { ...t, members: [...t.members] }]));
    c.votes = this.votes.map((v) => ({ ...v }));
    c.recharged = { ...this.recharged };
    c.noise = new Map(this.noise);
    c.frozen = new Set(this.frozen);
    c.yields = { ...this.yields };
    c.previousKinds = new Map(this.previousKinds);
    c.kindsChangedOn = new Map(this.kindsChangedOn);
    return c;
  }

  // MARK: Läsning

  f(r) { return Math.max(0, Math.min(1, (r + 30) / 100)); }

  /** Hur stor andel av X:s mandat som inte röstar nej till spåret. */
  support(x, t) {
    if (x === t.leader) return 1;
    let cap = 1.0;
    for (const c of this.constraints) {
      if (c.party === x && c.applies(t) && this.day <= c.until) cap = Math.min(cap, c.kind === "red" ? 0 : T.demandCap);
    }
    const others = t.members.filter((m) => m !== x);
    if (others.length === 0) return cap;
    return Math.min(cap, Math.min(...others.map((o) => this.f(this.rel.get(pairKey(x, o))))));
  }

  /** Fast och streckad fyllnad för ett spår. */
  meter(t) {
    let solid = 0.0, ghost = 0.0;
    for (const x of parties) {
      const s = this.support(x, t);
      if (s >= T.ghostFrom) ghost += seats(x) * s;
      if (s >= 1) solid += seats(x);
    }
    return { solid, ghost };
  }

  get leading() {
    const list = Object.values(this.tracks).filter((t) => t.active).sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
    return maxBy(list, (a, b) => { const x = this.meter(a), y = this.meter(b); return tupleLess(x.solid, x.ghost, y.solid, y.ghost); });
  }

  get tryck() {
    return T.tryckStart + (T.tryckEnd - T.tryckStart) * this.day / T.days + this.tryckBonus;
  }

  // MARK: Klockan

  tick(days) {
    for (let i = 0; i < days; i++) {
      if (this.ending !== null || this.paused !== null) return;
      this.endDay();
      if (this.ending !== null) return;
      if (this.day >= T.days) { this.finish(); return; }
      this.day += 1;
      this.beginDay();
    }
  }

  resume() { this.paused = null; }

  /** Början av dagen: laddning, verkliga händelser, spår, omröstningar. */
  beginDay() {
    this.recharge();
    this.applyEvents();
    this.reshapeTracks();
    this.runVotes();
    this.noteKindChanges();
  }

  /** Slutet av dagen: trådarna driver, tålamodet brinner, talmannens gräddfil. */
  endDay() {
    this.drift();
    this.burnPatience();
    this.graddfil();
    this.noteKindChanges();
  }

  recharge() {
    for (const m of stamps) {
      const { max: mx, per, unlock } = charging[m];
      if (this.day < unlock) continue;
      if (this.day === unlock && this.charges[m] === 0 && this.recharged[m] === 0) {
        this.charges[m] = 1;
        this.recharged[m] = this.day;
        continue;
      }
      if (this.charges[m] < mx && this.day - this.recharged[m] >= per) {
        this.charges[m] += 1;
        this.recharged[m] = this.day;
      } else if (this.charges[m] >= mx) {
        this.recharged[m] = this.day;
      }
    }
  }

  gift(m) {
    this.charges[m] = Math.min(charging[m].max, this.charges[m] + 1);
    this.gifts += 1;
  }

  notify(kind, text) {
    this.notices.push({ day: this.day, kind, text });
    if (this.notices.length > 5) this.notices.splice(0, this.notices.length - 5);
  }

  dropConstraint(id) { this.constraints = this.constraints.filter((c) => c.id !== id); }

  addRel(a, b, by) { const k = pairKey(a, b); this.rel.set(k, this.rel.get(k) + by); }

  raise(a, b, by) { const k = pairKey(a, b); this.rel.set(k, Math.min(100, this.rel.get(k) + by)); }

  calm(p, by) { this.patience[p] = Math.min(100, this.patience[p] + by); }

  news(title, source) {
    this.paused = { day: this.day, kind: "real", title, source, tag: "none" };
  }

  applyEvents() {
    switch (this.day) {
      case 5:
        this.addRel("S", "L", -20);
        this.news("Andersson ringer alla partiledare utom Åkesson. L: ”behöver inte ringa mig”.", "Händelse #4, 18 sep");
        break;
      case 29:
        this.votes.push({ day: 32, track: "Rött", real: true });
        break;
      case 32:
        this.raise("C", "S", 20); this.calm("V", 10); this.gift("demand");
        this.news("C öppnar för en S-regering utan egna ministrar. V avvisar rollen som stödparti. Gåva: KRAV.", "Händelse #9, 15 okt");
        break;
      case 43:
        this.raise("C", "S", 10); this.calm("L", 15); this.gift("leak");
        this.news("C: ”Det finns idag en majoritet för mittenpolitik, men ingen majoritet för en mittenregering.” Gåva: LÄCKA.", "Händelse #11, 26 okt");
        break;
      case 46:
        this.tracks["Mitten"].members = ["C", "S", "KD", "MP", "L"];
        this.tracks["Mitten"].active = true;
        this.votes.push({ day: 51, track: "Mitten", real: true });
        this.news("Talmannen föreslår Thand Ringqvist (C) som statsminister för C, S, KD, MP och L.", "Händelse #12, 29 okt");
        break;
      case 52:
        this.tracks["Mitten"].active = false;
        break;
      case 54: {
        const hadDemand = this.constraints.some((c) => c.id === "SD-ministrar");
        this.dropConstraint("SD-ministrar");
        this.constraints.push(constraint("C-totalpaket", "C", "demand", false, (t) => t.leader !== "C", 62));
        this.news("SD släpper kravet på ministerposter. C kräver ett ”totalpaket” av Andersson och Kristersson.", "Händelse #14 och #15, 6 nov");
        if (!hadDemand) this.notify("whatIf", "TÄNK OM: SD hade redan gett vika i det här bordet.");
        break;
      }
      case 56:
        this.calm("S", 30);
        this.constraints.push(constraint("S-inteTidö2", "S", "red", true, (t) => t.leader === "M"));
        this.tracks["Rött"].members = ["S", "MP", "C"];
        this.addRel("S", "V", -15);
        this.calm("V", 10); this.gift("demand");
        this.news("S: full opposition mot Tidö 2, vill regera med MP och C. V: kravet ”går inte att påverka”. Gåva: KRAV.", "Händelse #17, #19, #20, 8 nov");
        break;
      case 57:
        this.tracks["Mitten"] = track("Mitten", "S", ["S", "M"], true);
        this.news("Thomas Bodström (S, f.d. minister) vill pröva S och M. I spelet blir det mittenspåret – TÄNK OM.", "Händelse #22, 9 nov");
        break;
      case 58:
        this.raise("MP", "S", 15); this.raise("MP", "C", 15);
        this.news("MP: om det blir en stabil överenskommelse ”kommer vi att rösta ja”.", "Händelse #24, 10 nov");
        break;
      case 60:
        this.calm("V", 10); this.gift("leak");
        this.news("V: ”Vårt kongressbeslut ligger ju fast.” Gåva: LÄCKA.", "Händelse #28, 12 nov");
        break;
      case 63:
        this.constraints.push(constraint("C-valdeS", "C", "demand", false, (t) => t.leader === "M"));
        this.raise("C", "S", 20);
        this.news("C väljer S:s totalpaket.", "Händelse #32, 15 nov");
        break;
      case 64:
        this.raise("S", "V", 10); this.calm("V", 5);
        this.news("S och V möts i två timmar. V: ”samma besked som tidigare”.", "Händelse #34, 16 nov");
        break;
      case 65:
        for (const v of this.votes) v.day += 7;
        this.rottSurgeFrom = 65;
        this.news("Talmannen ger alla partiledare en veckas anstånd. De rödgröna förhandlar intensivt.", "Händelse #35, 17 nov");
        break;
      case 66:
        this.calm("C", 20); this.gift("leak");
        this.news("C: nej till V i regeringen – även för att undvika extraval. Gåva: LÄCKA.", "Händelse #37, 18 nov");
        break;
      default:
        break;
    }
  }

  reshapeTracks() {
    if (this.day < 56) return;
    const base = ["S", "MP", "C"];
    if (!this.constraints.some((c) => c.id === "C-inteV")) base.push("V");
    this.tracks["Rött"].members = base;
  }

  drift() {
    if (!(this.day > this.freezeUntil)) return;
    const tr = this.tryck;
    const rott = this.tracks["Rött"].members;
    for (const pair of [...this.rel.keys()].sort(comparePairs)) {
      if (this.frozen.has(pair)) continue;
      const r = this.rel.get(pair);
      const [a, b] = pairParts(pair);
      const restless = ((100 - this.patience[a]) + (100 - this.patience[b])) / 200;
      const imp = T.impFloor + (1 - T.impFloor) * restless;
      const mediated = a !== "MP" && b !== "MP" && this.rel.get(pairKey("MP", a)) >= 0 && this.rel.get(pairKey("MP", b)) >= 0;
      const med = mediated ? T.mediatorBonus : 1;
      const surge = this.day >= this.rottSurgeFrom && rott.includes(a) && [...rott, "V"].includes(b) ? 2.0 : 1.0;
      const ceil = ceilings.get(pair) + T.desperation * restless;
      let dr = r < ceil ? T.driftK * tr * imp * (ceil - r) / 100 * med * surge * this.noise.get(pair) : -T.overCeilDecay;
      if (r >= T.lockAt) dr -= T.handshakeDecay;
      const next = Math.max(-100, Math.min(100, r + dr));
      if (r < T.lockAt && T.lockAt <= next) this.formed.set(pair, this.day);
      this.rel.set(pair, next);
    }
  }

  burnPatience() {
    const tr = this.tryck;
    for (const x of parties) {
      if (this.day <= this.freezeUntil) continue;
      this.patience[x] -= T.patienceDrain * tr;
      if (!(this.patience[x] <= 0)) continue;
      // Bara mjuka krav ger vika av tålamod. Hårda röda linjer faller aldrig av sig själva (förval A).
      const soft = this.constraints.find((c) => c.party === x && !c.player && !c.hard);
      const hard = this.constraints.find((c) => c.party === x && !c.player && c.hard);
      if (soft) {
        this.dropConstraint(soft.id);
        this.yields[x] = (this.yields[x] ?? 0) + 1;
        this.notify("whatIf", `TÄNK OM: ${x} släpper ett krav (${soft.id}).`);
        this.patience[x] = T.patienceAfterYield;
      } else if (this.hardLinesCanFall && (this.yields[x] ?? 0) >= 2 && hard) {
        // Inställning B: efter två eftergifter kan även en hård linje falla.
        this.dropConstraint(hard.id);
        this.yields[x] = (this.yields[x] ?? 0) + 1;
        this.notify("whatIf", `TÄNK OM: ${x} släpper en röd linje (${hard.id}).`);
        this.patience[x] = T.patienceAfterYield;
      } else {
        this.patience[x] = T.patienceAfterBreakingPoint;
      }
    }
  }

  runVotes() {
    const due = [...this.votes]
      .sort((v, w) => (tupleLess(v.day, v.track, w.day, w.track) ? -1 : tupleLess(w.day, w.track, v.day, v.track) ? 1 : 0))
      .filter((v) => v.day === this.day);
    for (const v of due) {
      this.votes = this.votes.filter((w) => !(w.day === v.day && w.track === v.track && w.real === v.real));
      const t = this.tracks[v.track];
      const { solid } = this.meter(t);
      if (solid >= majority) {
        this.effect = { title: "GÅR IGENOM", tone: "bad", chips: [`${v.track}: ${int(solid)} av 175`], reason: null };
        this.ending = {
          title: "TÄNK OM: EN REGERING",
          text: `Den ${dateText(this.day)} gick spåret ${v.track} (${t.members.join(" + ")}) igenom: ${int(solid)} mandat tryckte inte nej. Du gjorde ${this.moves} drag. Partiledarna gjorde ${this.gifts} åt dig.`,
          isExtraval: false, footnote: "Det hände inte i verkligheten. " + fiction,
        };
        return;
      }
      this.lamps -= 1;
      this.effect = { title: "FÖLL", tone: "good", chips: [`${v.track}: ${int(solid)} av 175`, "Lampa −1"], reason: null };
      if (!v.real) this.notify("whatIf", `TÄNK OM: talmannens omröstning om ${v.track} föll.`);
      this.tracks[v.track].cooldownUntil = this.day + T.voteCooldownDays;
      this.tryckBonus += T.failedVoteTryck;
      for (const x of parties) {
        if (t.members.includes(x)) continue;
        for (const y of t.members) {
          const k = pairKey(x, y);
          if (!this.frozen.has(k)) this.rel.set(k, Math.max(-100, this.rel.get(k) - T.failedVoteHit));
        }
      }
      if (this.lamps === 0) {
        this.ending = {
          title: "EXTRAVAL – FULLTRÄFF",
          text: `Fyra förslag föll. Knuten höll. Du gjorde ${this.moves} drag. Partiledarna gjorde ${this.gifts} åt dig.`,
          isExtraval: true, footnote: fiction,
        };
        return;
      }
    }
  }

  get tracksByName() {
    return Object.values(this.tracks).sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  }

  graddfil() {
    if (this.votes.length > 0) return;
    for (const t of this.tracksByName) {
      if (!(t.active && this.day >= t.cooldownUntil)) continue;
      if (this.meter(t).solid >= T.graddfilSolid) {
        this.votes.push({ day: this.day + T.graddfilDays, track: t.name, real: false });
        this.notify("whatIf", `TÄNK OM: ${t.name} har 175. Talmannen kallar till omröstning ${dateText(this.day + T.graddfilDays)}.`);
        return;
      }
    }
  }

  finish() {
    if (this.ending !== null) return;
    const lost = this.tracksByName.find((t) => this.meter(t).solid >= majority);
    if (lost) {
      this.ending = {
        title: "TÄNK OM: EN REGERING",
        text: `Hösten tog slut med ${lost.name} på ${int(this.meter(lost).solid)}. Du gjorde ${this.moves} drag. Partiledarna gjorde ${this.gifts} åt dig.`,
        isExtraval: false, footnote: "Det hände inte i verkligheten. " + fiction,
      };
    } else {
      this.ending = {
        title: "EXTRAVAL",
        text: `20 nov och inget spår har 175. Du gjorde ${this.moves} drag. Partiledarna gjorde ${this.gifts} åt dig.`,
        isExtraval: true, footnote: fiction,
      };
    }
  }

  // MARK: Spelarens stämplar

  use(m) {
    this.charges[m] -= 1;
    if (this.charges[m] === charging[m].max - 1) this.recharged[m] = this.day;
    this.moves += 1;
  }

  isFresh(pair) {
    return this.rel.get(pair) >= T.lockAt && this.day - (this.formed.get(pair) ?? -99) <= T.freshDays;
  }

  leak(a, b) {
    if (!(this.charges.leak > 0)) return false;
    this.use("leak");
    const pair = pairKey(a, b);
    const fresh = this.isFresh(pair);
    const hit = fresh ? T.freshLeakHit : T.leakHit;
    this.rel.set(pair, Math.max(-100, this.rel.get(pair) - hit));
    for (const x of [a, b]) this.patience[x] = Math.max(1, this.patience[x] - T.leakPatienceCost);
    this.effect = {
      title: "LÄCKA", tone: "good",
      chips: [`${a}–${b} −${int(hit)}` + (fresh ? " (färskt handslag)" : ""), "Tålamod −7 för båda"],
      reason: `Tråden ${a}–${b} försvagades${fresh ? " hårt, eftersom handslaget var färskt" : ""}. Otåliga partier ger lättare vika senare.`,
    };
    this.notify("rumor", `RYKTE (påhittat): något om ${a} och ${b} har läckt.`);
    this.noteKindChanges();
    return true;
  }

  demand(x) {
    if (!(this.charges.demand > 0)) return false;
    this.use("demand");
    if (this.constraints.some((c) => c.player && c.party === x && this.day <= c.until)) {
      this.constraints = this.constraints.filter((c) => !(c.party === x && (c.player || !c.hard)));
      this.patience[x] = T.burstPatience;
      this.effect = {
        title: `${x} SPRICKER`, tone: "bad", chips: ["Alla mjuka krav släppta"],
        reason: `Två krav i rad var för mycket. ${x} gav upp sina mjuka krav.`,
      };
      return true;
    }
    const target = this.leading.name;
    this.constraints.push(constraint(`spelare-${x}-${this.day}`, x, "demand", false, (t) => t.name === target, this.day + T.kravDays, true));
    this.patience[x] = Math.min(100, this.patience[x] + T.kravPatience);
    this.effect = {
      title: "KRAV", tone: "good", chips: [`${x} kräver något av ${target}`, `${T.kravDays} dagar`],
      reason: `${x} stöder nu ${target} till högst 60 % i ${T.kravDays} dagar.`,
    };
    return true;
  }

  delay() {
    if (!(this.charges.delay > 0)) return false;
    this.use("delay");
    this.freezeUntil = this.day + T.forhalaDays - 1;
    for (const v of this.votes) if (!v.real) v.day += T.forhalaVotePush;
    this.tryckBonus += T.forhalaTryck;
    this.effect = {
      title: "FÖRHALA", tone: "good", chips: [`Allt står still ${T.forhalaDays} dagar`, "Trycket +0,1"],
      reason: "Talmannen väntar. Spelets omröstningar skjuts fram, men partierna blir otåligare.",
    };
    return true;
  }

  /** Läckor som skulle sänka spårets fasta stöd: { seats, risk, x, y }. */
  swingOptions(t) {
    const opts = [];
    for (const x of parties) {
      if (x === t.leader || !(this.support(x, t) >= 0.8)) continue;
      for (const y of t.members) {
        const k = pairKey(x, y);
        if (y === x || this.frozen.has(k)) continue;
        const r = this.rel.get(k);
        const hit = this.isFresh(k) ? T.freshLeakHit : T.leakHit;
        if (r - hit < T.lockAt - 10) opts.push({ seats: seats(x), risk: Math.min(this.patience[x], this.patience[y]), x, y });
      }
    }
    return opts;
  }

  wouldLockSoon(t) {
    const solid = this.meter(t).solid;
    const near = parties.filter((p) => { const s = this.support(p, t); return s >= 0.8 && s < 1; }).reduce((sum, p) => sum + seats(p), 0);
    return { solid, soon: solid + near };
  }

  /** Förslag: den läcka som tar flest mandat från det ledande spåret. */
  get leakSuggestion() {
    const t = this.leading;
    const o = this.swingOptions(t).sort(bySeatsThenRiskDesc)[0];
    if (o) return [o.x, o.y];
    const locked = [...this.rel.keys()].sort(comparePairs)
      .filter((k) => !this.frozen.has(k) && this.rel.get(k) >= T.lockAt)
      .sort((k1, k2) => this.rel.get(k2) - this.rel.get(k1));
    return locked.length > 0 ? pairParts(locked[0]) : null;
  }

  /** Förslag: kravet läggs på det största partiet som nästan stöder det ledande spåret. */
  get demandSuggestion() {
    const t = this.leading;
    return maxBy(parties.filter((p) => p !== t.leader && this.support(p, t) >= 0.8), (a, b) => seats(a) < seats(b)) ?? null;
  }

  get newsChoices() { return []; }

  get cards() {
    if (this.ending !== null || this.paused !== null) return [];
    const list = [];
    const leak = this.charges.leak > 0 ? this.leakSuggestion : null;
    if (leak) {
      const [a, b] = leak, id = `leak.${a}.${b}`;
      list.push({ id, title: `LÄCKA: ${a}–${b}`, quip: "Tråden får sig en törn. Båda blir otåligare.", icon: "stampel-lacka",
        preview: this.preview(id) + " · tråden −40 (−75 om färskt), båda −7 tålamod" });
    }
    const x = this.charges.demand > 0 ? this.demandSuggestion : null;
    if (x) {
      const id = `demand.${x}`;
      list.push({ id, title: `KRAV: ${x}`, quip: "Två krav i rad får det att spricka.", icon: "stampel-krav",
        preview: this.preview(id) + ` · ${x} högst 60 % i ${T.kravDays} dagar` });
    }
    if (this.charges.delay > 0) {
      list.push({ id: "delay", title: "FÖRHALA", quip: "Trycket stiger.", icon: "stampel-forhala",
        preview: `Allt står still ${T.forhalaDays} dagar · spelets omröstning +${T.forhalaVotePush} dagar · trycket +0,1` });
    }
    return list;
  }

  /** "Ribban Rött 168 → 146": räknat på en kopia av bordet. */
  preview(id) {
    const lead = this.leading.name;
    const before = int(this.meter(this.tracks[lead]).solid);
    const copy = this.clone();
    copy.apply(id);
    const after = int(copy.meter(copy.tracks[lead]).solid);
    return `Ribban ${lead} ${before} → ${after}`;
  }

  apply(id) {
    const parts = id.split(".");
    const isParty = (p) => parties.includes(p);
    switch (parts[0]) {
      case "leak": if (isParty(parts[1]) && isParty(parts[2])) this.leak(parts[1], parts[2]); break;
      case "demand": if (isParty(parts[1])) this.demand(parts[1]); break;
      case "delay": this.delay(); break;
      default: break;
    }
  }

  play(id) {
    if (!this.cards.some((c) => c.id === id)) return;
    this.apply(id);
  }

  // MARK: Visning

  get meters() {
    const t = this.leading, m = this.meter(t);
    let caption = `Mandat som trycker ja eller gult för ${t.name} (${t.members.join("+")}). 175 = regering.`;
    const v = this.votes.filter((w) => !w.real).reduce((best, w) => (best === null || w.day < best.day ? w : best), null);
    if (v) caption += ` Talmannen kallar till omröstning om ${v.track} ${dateText(v.day)}.`;
    return [
      { name: "Datum", value: dateText(this.day), caption: null },
      { name: "Ribban", value: `${t.name} ${int(m.solid)}`, caption },
      { name: "Lampor", value: lampText(this.lamps), caption: null },
      { name: "Stämplar", value: `L${this.charges.leak} K${this.charges.demand} F${this.charges.delay}`, caption: null },
    ];
  }

  get bars() {
    const lead = this.leading.name;
    return this.tracksByName.filter((t) => t.active).map((t) => {
      const m = this.meter(t);
      return { label: `${t.name} (${t.members.join("+")})`, value: m.solid, ghost: m.ghost, max: 349, marks: [majority], isLeading: t.name === lead };
    });
  }

  get figure() { return null; }

  /** Bordets trådar som linjer: handslag (🤝), nära samtal (💬) och hårda röda linjer (✋). */
  shownRelations() {
    const out = [];
    for (const pair of [...this.rel.keys()].sort(comparePairs)) {
      const r = this.rel.get(pair);
      const [a, b] = pairParts(pair);
      let kind;
      if (this.frozen.has(pair) || this.constraints.some((c) => c.hard && c.kind === "red" && (c.party === a || c.party === b) && redLinePairs[c.id] === pair)) {
        kind = "conflict";
      } else if (r >= T.lockAt) {
        kind = "attraction";
      } else if (r >= 50) {
        kind = "negotiating";
      } else {
        continue;
      }
      const label = kind === "attraction" ? "Handslag" : kind === "negotiating" ? "Samtal" : "Röd linje";
      out.push({ pair, a, b, kind, label, isNew: this.kindsChangedOn.get(pair) === this.day && this.day > 0, isRumor: false });
    }
    return out;
  }

  get relations() { return this.shownRelations(); }

  noteKindChanges() {
    const now = new Map(this.shownRelations().map((r) => [r.pair, r.kind]));
    for (const pair of new Set([...now.keys(), ...this.previousKinds.keys()])) {
      if (now.get(pair) !== this.previousKinds.get(pair)) this.kindsChangedOn.set(pair, this.day);
    }
    this.previousKinds = now;
  }
}

/** Swifts `sorted { ($0.seats, $0.risk) > ($1.seats, $1.risk) }` (stabil, störst först). */
export function bySeatsThenRiskDesc(o1, o2) {
  if (tupleLess(o2.seats, o2.risk, o1.seats, o1.risk)) return -1;
  if (tupleLess(o1.seats, o1.risk, o2.seats, o2.risk)) return 1;
  return 0;
}

/** Ett slumpat 64-bitars seed (som UInt64.random i appen). */
export function randomSeed() {
  const words = crypto.getRandomValues(new Uint32Array(2));
  return (BigInt(words[0]) << 32n) | BigInt(words[1]);
}
