// Nyhetsknuten: port av Nyhetsknuten.swift (BrytareModell, omgång 9; underlag data/tg-knut-nyhet/report.md).
// Spelaren är knuten och vinner om det blir extraval. Dagarna rullar; när en nyhet kommer står tiden still och
// spelaren väljer en reaktion. Mätaren Uppgörelsen har tre spår (◀ Vänster, ● Mitten, ▶ Höger) från extraval
// till regering. Läckor läggs på dagar framåt. Rykten blir små notiser som inte stoppar tiden.

import { RumorMode, dateText, int, lampText, lastDay, maxBy } from "./gemensamt.js";

/** Spåren i Swifts ordning (Lane.allCases). */
export const lanes = ["left", "center", "right"];
export const laneLabel = { left: "◀ Vänster", center: "● Mitten", right: "▶ Höger" };
export const laneShort = { left: "Vänster", center: "Mitten", right: "Höger" };

/**
 * Kaptenens öppna frågor som inställningar (förval = rapportens rekommendation A).
 * @typedef {{ rumors: string, leakWhileRunning: boolean, anonymousSources: boolean, finale: boolean }} NewsKnotSettings
 */
export function defaultNewsSettings() {
  return { rumors: RumorMode.ownMovesOnly, leakWhileRunning: true, anonymousSources: true, finale: true };
}

/**
 * En nyhet i Nyhetsknuten: vad den gör med spåren och vilken torr rad reaktionen får.
 * @typedef {{ day: number, kind: "real" | "rumor" | "anonymous", title: string, source: string, gift: number,
 *   deltas: Partial<Record<string, number>>, target: string, quip: string, pause: number }} KnotNews
 */
function kn(day, kind, title, source, deltas, target, quip, { gift = 0, pause = 0 } = {}) {
  return Object.freeze({ day, kind, title, source, gift, deltas: Object.freeze(deltas), target, quip, pause });
}

const knotNews = [
  kn(1, "real", "V kräver plats i en S-ledd regering. C släpper inte fram en regering där V ingår.", "Händelse #2, 14 sep",
    { left: -5 }, "left", "Påminn alla om att 176 bara är en siffra.", { gift: 2 }),
  kn(5, "real", "Andersson ringer alla partiledare utom Åkesson. L: ”behöver inte ringa mig”.", "Händelse #4, 18 sep",
    { left: -4 }, "left", "Fråga vem som ringde vem först.", { gift: 1 }),
  kn(15, "real", "V röstar på Norlén som talman. Andersson lämnar tillbaka sonderingsuppdraget.", "Händelse #5, 28 sep",
    { left: 4, right: 3 }, "right", "Påminn om att talmannen är M."),
  kn(19, "real", "Andersson får återuppta sonderingen, rapport senast 12 okt.", "Händelse #6, 2 okt",
    { left: 6 }, "left", "Fråga om rapporten har en bilaga."),
  kn(32, "real", "C öppnar för en S-regering utan egna ministrar, om politiken är förankrad i mitten.", "Händelse #9, 15 okt",
    { left: 8, center: 6 }, "center", "Fråga vad ”förankrad” betyder i kronor."),
  kn(43, "real", "C: ”Det finns idag en majoritet för mittenpolitik, men ingen majoritet för en mittenregering.”", "Händelse #11, 26 okt",
    { center: -6 }, "center", "Påminn om att majoritet och regering är olika saker.", { gift: 1 }),
  kn(46, "real", "Talmannen föreslår Thand Ringqvist (C) för en regering av C, S, KD, MP och L.", "Händelse #12, 29 okt",
    { center: 15 }, "center", "Räkna partierna högt i direktsändning."),
  kn(54, "real", "SD släpper kravet på ministerposter och tolererar Kristersson.", "Händelse #14, 6 nov",
    { right: 18 }, "right", "Fråga vad ”tolerera” kostar per år."),
  kn(54, "real", "C ber Andersson och Kristersson om var sitt ”totalpaket” till fredag.", "Händelse #15, 6 nov",
    { left: 5, right: 5 }, "right", "Påminn om att fredag är en dag som alla andra."),
  kn(56, "real", "S: full opposition mot Tidö 2 – och vill regera med MP och C, V utanför.", "Händelse #17, #19, 8 nov",
    { right: -10, left: 6 }, "right", "Fråga vem som skrev ”full”.", { gift: 2 }),
  kn(56, "real", "V: kravet på regeringsplats ”går inte att påverka”.", "Händelse #20, 8 nov",
    { left: -8 }, "left", "Påminn om kongressen. Igen.", { gift: 2 }),
  kn(58, "real", "MP: om det blir en stabil överenskommelse ”kommer vi att rösta ja”.", "Händelse #24, 10 nov",
    { left: 10 }, "left", "Fråga om någon frågade MP."),
  kn(59, "anonymous", "Uppgifter: S försökte locka V med sakpolitik. V ska ha avvisat det som ”ett januariavtal”.", "ENLIGT UPPGIFTER – händelse #29, 12 nov",
    { left: 6 }, "left", "Fråga vilken januari det gällde."),
  kn(60, "real", "V: ”Vårt kongressbeslut ligger ju fast.” ”Vi kommer ju aldrig att rösta på Ulf Kristersson.”", "Händelse #28, 12 nov",
    { right: -4 }, "right", "Påminn om att ”aldrig” är ett långt ord.", { gift: 2 }),
  kn(62, "anonymous", "Uppgifter: innehållet i S:s totalpaket läcker – 135 punkter.", "ENLIGT UPPGIFTER – händelse #31, 14–15 nov",
    { left: 4 }, "left", "Fråga om punkt 136."),
  kn(63, "real", "C väljer S:s totalpaket.", "Händelse #32, 15 nov",
    { left: 15, right: -10 }, "left", "Fråga om paketet går att lämna tillbaka."),
  kn(64, "real", "S och V möts i två timmar. V: ”samma besked som tidigare”.", "Händelse #34, 16 nov",
    { left: -6 }, "left", "Påminn om att två timmar är 120 minuter.", { gift: 1 }),
  kn(65, "real", "Talmannen ger alla partiledare en veckas anstånd.", "Händelse #35, 17 nov",
    {}, "left", "Fråga vad en vecka är i politiska dagar.", { pause: 3 }),
  kn(66, "real", "C: nej till V i regeringen – även för att undvika extraval.", "Händelse #37, 18 nov",
    { left: -12 }, "left", "Påminn om att extraval också är ett alternativ.", { gift: 3 }),
];

/** Rykten: A = föremål, processer och namnlösa källor; B lägger till påhittade möten mellan namngivna partier. */
const objectRumors = [
  kn(12, "rumor", "En kopiator i riksdagshuset har gått varm hela natten.", "", { center: 3 }, "center", "Fråga vad som kopierades."),
  kn(24, "rumor", "En anonym källa: ”Det finns en plan B.” Ingen vet vad plan A var.", "", { right: 4 }, "right", "Fråga efter plan C."),
  kn(39, "rumor", "Kaffeautomaten utanför talmannens rum är tom. Igen.", "", { left: 1, center: 1, right: 1 }, "center", "Påminn om att kaffe är förhandlingsbart."),
  kn(48, "rumor", "Ett mejl med ämnesraden ”Utkast 7” har skickats till fel person.", "", { left: 4 }, "left", "Fråga vad som stod i utkast 6."),
  kn(61, "rumor", "Någon har bokat riksdagens största sal i en vecka. Syftet är okänt.", "", { center: 5 }, "center", "Fråga vem som har nyckeln."),
];
const meetingRumors = [
  kn(18, "rumor", "C och S har setts äta lunch.", "", { left: 4 }, "left", "Fråga vem som betalade."),
  kn(36, "rumor", "M och C pratade länge i korridoren.", "", { right: 4 }, "right", "Fråga hur lång korridoren är."),
  kn(52, "rumor", "KD och C delade på en pizza efter voteringen.", "", { right: 3 }, "right", "Fråga om pizzan hade totalpaket."),
];

const SPALTMETER_CAP = 9;
const VOTE_LINE = 85.0;
const FINALE_DAYS = [70, 74];

/** "Samtalen fortsätter": hur mycket varje spår stiger per dag, akt för akt (till och med dag `upTo`). */
const rateTable = [
  { upTo: 18, rates: { left: 0.6, center: 0.3, right: 0.6 } },
  { upTo: 32, rates: { left: 1.2, center: 0.5, right: 0.8 } },
  { upTo: 51, rates: { left: 0.6, center: 1.3, right: 0.9 } },
  { upTo: 63, rates: { left: 2.0, center: 0.8, right: 1.5 } },
  { upTo: Infinity, rates: { left: 1.5, center: 1.2, right: 1.5 } },
];

export class NewsKnotGame {
  static news(anonymous) {
    return knotNews.filter((n) => anonymous || n.kind !== "anonymous");
  }

  static rumors(mode) {
    return [...objectRumors, ...(mode === RumorMode.alsoRealPartyMeetings ? meetingRumors : [])];
  }

  /** @param {NewsKnotSettings} settings */
  constructor(settings = defaultNewsSettings()) {
    this.title = "Nyhetsknuten";
    this.tips = [
      "Du är knuten. Du vinner om det blir extraval: alla fyra lampor släckta.",
      "Mätaren Uppgörelsen har tre spår – ◀ Vänster, ● Mitten, ▶ Höger – från extraval till regering. Samtalen fortsätter varje dag, så spåren kryper uppåt. Över 60 vässar talmannen pennan, över 85 blir en omröstning din förlust.",
      "När en nyhet kommer står tiden still. Välj en reaktion: Påminn, Följdfråga eller Inga kommentarer. Hur mycket den verkar ser du först efteråt. Gåvor – när partiledarna låser sig själva – ger spaltmeter.",
      "Mellan nyheterna kan du läcka till en dag framåt. Landar läckan på en deadline eller omröstningsdag slår den hårdare. Två läckor mot samma spår inom fem dagar dementeras.",
    ];
    this.settings = Object.freeze({ ...settings });
    this.day = 0;
    this.lanes = { left: 20, center: 10, right: 25 };
    this.spaltmeter = 3;
    this.lamps = 4;
    this.moves = 0;
    this.gifts = 0;
    this.effect = null;
    this.ending = null;
    this.notices = [];
    /** @type {KnotNews | null} */
    this.current = null;
    // Stabil sortering på dag: samma dag behåller listornas ordning (nyheter före rykten), som i Swift.
    this.queue = [...NewsKnotGame.news(settings.anonymousSources), ...NewsKnotGame.rumors(settings.rumors)].sort((a, b) => a.day - b.day);
    /** @type {Record<string, number>} */
    this.stillUntil = {};
    /** @type {{ day: number, lane: string }[]} */
    this.leaks = [];
    /** @type {Record<string, number>} */
    this.lastLeak = {};
    /** @type {{ day: number, lane: string | null, real: boolean }[]} */
    this.votes = [{ day: 32, lane: "left", real: true }, { day: 51, lane: "center", real: true }];
    if (settings.finale) this.votes.push(...FINALE_DAYS.map((day) => ({ day, lane: null, real: false })));
  }

  get endDay() { return this.settings.finale ? FINALE_DAYS[FINALE_DAYS.length - 1] : lastDay; }

  /** Dagar då en läcka slår hårdare: omröstningar som återstår och kända deadlines. */
  get deadlineDays() { return new Set([...this.votes.map((v) => v.day), 61, 65]); }

  get paused() {
    const n = this.current;
    return n && { day: n.day, kind: n.kind, title: n.title, source: n.source, tag: n.gift > 0 ? "locks" : "none" };
  }

  get relations() { return []; }
  get figure() { return "knuten-neutral"; }

  get leading() { return maxBy(lanes, (a, b) => this.lanes[a] < this.lanes[b]); }

  // MARK: Klockan

  tick(days) {
    for (let i = 0; i < days; i++) {
      if (this.ending !== null || this.current !== null) return;
      if (this.day >= this.endDay) { this.finish(); return; }
      this.day += 1;
      this.daily();
      if (this.ending !== null) return;
      this.landLeaks();
      this.runVotes();
      if (this.ending !== null) return;
      if (this.releaseNews()) return;
    }
  }

  resume() {
    this.current = null;
    this.releaseNews();
  }

  rate(lane) {
    return rateTable.find((row) => this.day <= row.upTo).rates[lane];
  }

  daily() {
    if (this.day % 4 === 0) this.spaltmeter = Math.min(SPALTMETER_CAP, this.spaltmeter + 1);
    for (const lane of lanes) {
      if (this.day > (this.stillUntil[lane] ?? -1)) this.lanes[lane] = Math.min(100, this.lanes[lane] + this.rate(lane));
    }
    this.checkGraddfil();
  }

  move(lane, by) {
    this.lanes[lane] = Math.max(0, Math.min(100, this.lanes[lane] + by));
  }

  checkGraddfil() {
    const lane = lanes.find((l) => this.lanes[l] >= 100);
    if (lane) this.lose(lane, `${laneShort[lane]} nådde 100 % – talmannen tog gräddfilen`);
  }

  notify(kind, text) {
    this.notices.push({ day: this.day, kind, text });
    if (this.notices.length > 5) this.notices.splice(0, this.notices.length - 5);
  }

  deltaText(deltas) {
    return lanes.filter((l) => deltas[l] !== undefined)
      .map((l) => { const d = deltas[l]; return (d >= 0 ? "▲ " : "▼ ") + `${laneShort[l]} ${d >= 0 ? "+" : "−"}${int(Math.abs(d))}`; })
      .join(", ");
  }

  /** Släpper dagens nyheter. Rykten blir aviseringar (stoppar inte tiden); viktiga nyheter blir huvudkortet. */
  releaseNews() {
    while (this.current === null && this.queue.length > 0 && this.queue[0].day <= this.day) {
      const next = this.queue.shift();
      for (const lane of lanes) if (next.deltas[lane] !== undefined) this.move(lane, next.deltas[lane]);
      if (next.kind === "rumor") {
        this.notify("rumor", `RYKTE (påhittat): ${next.title} ` + this.deltaText(next.deltas));
        this.checkGraddfil();
        continue;
      }
      return this.show(next);
    }
    return false;
  }

  show(next) {
    if (next.pause > 0) for (const lane of lanes) this.stillUntil[lane] = this.day + next.pause;
    this.current = next;
    this.checkGraddfil();
    return true;
  }

  landLeaks() {
    for (const leak of this.leaks.filter((l) => l.day === this.day)) {
      const last = this.lastLeak[leak.lane];
      if (last !== undefined && this.day - last <= 5) {
        this.move(leak.lane, 5);
        this.notify("info", `Läckan om ${laneShort[leak.lane]} dementerades – ▲ +5. Två läckor inom fem dagar blir en dementi.`);
      } else {
        const hit = this.deadlineDays.has(this.day) ? 22.0 : 15.0;
        this.move(leak.lane, -hit);
        this.notify("info", `Din läcka landade: ▼ ${laneShort[leak.lane]} −${int(hit)}` + (hit > 15 ? " – på en deadline, därför hårdare." : "."));
      }
      this.lastLeak[leak.lane] = this.day;
    }
    this.leaks = this.leaks.filter((l) => l.day !== this.day);
  }

  runVotes() {
    for (const v of this.votes.filter((w) => w.day === this.day)) {
      const lane = v.lane ?? this.leading;
      if (this.lanes[lane] >= VOTE_LINE) {
        this.lose(lane, `Omröstningen om ${laneShort[lane]} gick igenom ${dateText(this.day)}`);
        return;
      }
      this.lamps -= 1;
      this.move(lane, -25);
      this.spaltmeter = Math.min(SPALTMETER_CAP, this.spaltmeter + 3);
      this.effect = {
        title: "OMRÖSTNINGEN FÖLL", tone: "good", chips: [`▼ ${laneLabel[lane]} −25`, "Lampa −1", "+3 spaltmeter"],
        reason: `${laneShort[lane]} stod under 85 % – det räckte inte för en regering.`,
      };
      this.notify(v.real ? "info" : "whatIf", v.real ? `I verkligheten föll omröstningen ${dateText(this.day)}.`
        : `TÄNK OM: talmannens omröstning om ${laneShort[lane]} föll ${dateText(this.day)}.`);
      if (this.lamps === 0) {
        this.ending = { title: "EXTRAVAL", text: this.verdict, isExtraval: true,
          footnote: "Rubrikerna är verkliga. Ryktena, slutspurten och utgången är spelets påhitt." };
        return;
      }
    }
    this.votes = this.votes.filter((w) => w.day !== this.day);
  }

  get verdict() { return `Du gjorde ${this.moves} drag. Partiledarna gjorde ${this.gifts} åt dig.`; }

  lose(lane, why) {
    if (this.ending !== null) return;
    this.ending = { title: `TÄNK OM: REGERING (${laneShort[lane].toUpperCase()})`, text: `${why}. ${this.verdict}`,
      isExtraval: false, footnote: "Det hände inte i verkligheten. Rubrikerna är verkliga, ryktena och utgången påhittade." };
  }

  finish() {
    if (this.ending !== null) return;
    this.ending = this.settings.finale
      ? { title: "EXTRAVAL", text: this.verdict, isExtraval: true, footnote: "Rubrikerna är verkliga. Ryktena och utgången är spelets påhitt." }
      : { title: "FORTSÄTTNING FÖLJER", text: `Det är 18 nov och ingen regering finns. ${this.verdict}`,
          isExtraval: false, footnote: "Rubrikerna är verkliga. Ryktena är spelets påhitt." };
  }

  // MARK: Reaktioner och kort

  remindPower(n) { return n.kind === "anonymous" ? 6 : 8; }

  hitPreview(lane, by) {
    return this.lanes[lane] < 25 ? `${laneShort[lane]}: ingen effekt (under 25 %)` : `▼ ${laneLabel[lane]} ca −${int(by)}`;
  }

  get newsChoices() {
    const n = this.current;
    if (n === null || this.ending !== null) return [];
    if (n.gift > 0) {
      return [{ id: "thanks", title: "TACK SÅ MYCKET", quip: "Partiledarna gjorde jobbet åt dig.", icon: null, preview: `+${n.gift} spaltmeter` }];
    }
    const list = [];
    if (this.spaltmeter >= 1) {
      list.push({ id: `remind.${n.target}`, title: `Påminn – ${laneLabel[n.target]}`, quip: n.quip, icon: null,
        preview: this.hitPreview(n.target, this.remindPower(n)) + " · 1 spaltmeter" });
      const second = maxBy(lanes.filter((l) => l !== n.target), (a, b) => this.lanes[a] < this.lanes[b]);
      list.push({ id: `follow.${n.target}.${second}`, title: `Följdfråga – ${laneShort[n.target]} och ${laneShort[second]}`,
        quip: "Svaret blir en ny fråga.", icon: null,
        preview: this.hitPreview(n.target, 4) + " och " + this.hitPreview(second, 4) + " · 1 spaltmeter" });
    }
    list.push({ id: "nocomment", title: "Inga kommentarer", quip: "Tystnad är också ett citat.", icon: null,
      preview: "+1 spaltmeter · mätaren står still" });
    return list;
  }

  get cards() {
    if (this.ending !== null || this.current !== null) return [];
    const list = [];
    const lane = this.leading;
    const deadlines = this.deadlineDays;
    const leakPreview = (landing) => {
      const hit = deadlines.has(landing) ? 22 : 15;
      const last = this.lastLeak[lane];
      const denial = last !== undefined ? landing - last <= 5 : false;
      return (denial ? `Risk: dementi ▲ ${laneShort[lane]} +5`
        : `▼ ${laneLabel[lane]} −${hit} den ${dateText(landing)}` + (hit > 15 ? " (deadline)" : "")) + " · 2 spaltmeter";
    };
    if (this.settings.leakWhileRunning && this.spaltmeter >= 2) {
      const tomorrow = this.day + 1;
      list.push({ id: `leak.${lane}.${tomorrow}`, title: `Läck om ${laneShort[lane]} till i morgon`,
        quip: "Kvällspressen tar allt.", icon: null, preview: leakPreview(tomorrow) });
      let target = this.day + 3;
      for (let d = this.day + 1; d <= this.day + 3; d++) if (deadlines.has(d) && d > this.day + 1) { target = d; break; }
      list.push({ id: `leak.${lane}.${target}`, title: `Läck om ${laneShort[lane]} till ${dateText(target)}`,
        quip: "Tajmingen är allt.", icon: null, preview: leakPreview(target) });
    }
    if (this.spaltmeter >= 3 && this.day > (this.stillUntil[lane] ?? -1)) {
      list.push({ id: "sega", title: `Sega – ${laneLabel[lane]}`, quip: "”Processen får ta tid.”", icon: null,
        preview: `${laneLabel[lane]} står still 4 dagar · 3 spaltmeter` });
    }
    return list;
  }

  play(id) {
    const parts = id.split(".");
    const n = this.current;
    if (n !== null) {
      if (!this.newsChoices.some((c) => c.id === id)) return;
      switch (parts[0]) {
        case "thanks":
          this.spaltmeter = Math.min(SPALTMETER_CAP, this.spaltmeter + n.gift);
          this.gifts += 1;
          this.effect = { title: "GÅVA", tone: "good", chips: [`+${n.gift} spaltmeter`], reason: "Partiledarna låste sig själva." };
          break;
        case "remind":
          this.spaltmeter -= 1; this.moves += 1;
          this.hit(parts[1], this.remindPower(n), "PÅMINT");
          break;
        case "follow": {
          this.spaltmeter -= 1; this.moves += 1;
          const chips = [parts[1], parts[2]].map((lane) => {
            if (!(this.lanes[lane] >= 25)) return `${laneShort[lane]}: ingen bryr sig`;
            this.move(lane, -4);
            return `${laneLabel[lane]} −4`;
          });
          this.effect = { title: "FÖLJDFRÅGA", tone: "good", chips: ["−1 spaltmeter", ...chips],
            reason: "Två spår fick var sin fråga. Under 25 % bryr sig ingen." };
          break;
        }
        case "nocomment":
          this.spaltmeter = Math.min(SPALTMETER_CAP, this.spaltmeter + 1);
          this.effect = { title: "INGA KOMMENTARER", tone: "neutral", chips: ["+1 spaltmeter"], reason: "Tystnad kostar inget och ger lite." };
          break;
        default:
          return;
      }
      this.resume();
      return;
    }
    if (!this.cards.some((c) => c.id === id)) return;
    switch (parts[0]) {
      case "leak": {
        this.spaltmeter -= 2; this.moves += 1;
        const lane = parts[1], landing = Number(parts[2]);
        this.leaks.push({ day: landing, lane });
        this.effect = { title: "LÄCKA LAGD", tone: "neutral", chips: ["−2 spaltmeter", `${laneLabel[lane]} ${dateText(landing)}`],
          reason: `Läckan landar ${dateText(landing)}. På en deadline eller omröstningsdag slår den hårdare.` };
        break;
      }
      case "sega": {
        this.spaltmeter -= 3; this.moves += 1;
        this.stillUntil[this.leading] = this.day + 4;
        this.effect = { title: "SEGA", tone: "good", chips: ["−3 spaltmeter", `${laneLabel[this.leading]} står still 4 dagar`],
          reason: "Det ledande spåret står still medan processen får ta tid." };
        break;
      }
      default:
        return;
    }
  }

  hit(lane, by, label) {
    if (this.lanes[lane] < 25) {
      this.effect = { title: "INGEN BRYR SIG", tone: "neutral", chips: ["−1 spaltmeter", `${laneShort[lane]} under 25 %`],
        reason: "Ett spår under 25 % är inte en nyhet. Sikta på det som leder." };
      return;
    }
    const before = this.lanes[lane];
    this.move(lane, -by);
    this.effect = { title: label, tone: "good", chips: ["−1 spaltmeter", `▼ ${laneLabel[lane]} −${int(by)}`],
      reason: `${laneShort[lane]} låg på ${int(before)} % – påminnelsen bet.` };
  }

  // MARK: Visning

  get meters() {
    return [
      { name: "Datum", value: dateText(this.day), caption: null },
      { name: "Spaltmeter", value: `${this.spaltmeter}`, caption: null },
      { name: "Lampor", value: lampText(this.lamps), caption: null },
    ];
  }

  get bars() {
    const lead = this.leading;
    return lanes.map((l) => ({ label: laneLabel[l], value: this.lanes[l], ghost: this.lanes[l], max: 100, marks: [60, 85], isLeading: l === lead }));
  }
}
