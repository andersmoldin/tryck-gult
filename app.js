// Tryck gult! – webbversionen av provbänkens omgång 9 (Nyhetsknuten och Systemknuten).
// Visar spelmodellen i modell/ med samma zoner som ClockScreen.swift: resurser och dag → mätaren → notiser →
// huvudkortet (nyhet eller effekt) → handlingarna → bordet. Reglerna ligger helt i modell/; här finns bara visning,
// klockan och inställningarna.

import { NewsKnotGame, defaultNewsSettings } from "./modell/nyhetsknuten.js";
import { SystemKnotGame, randomSeed } from "./modell/systemknuten.js";
import { RumorMode, dateText, lastDay, partyInfo, parties } from "./modell/gemensamt.js";
import { GraphLayout, GraphMetrics, clusters, emojiPositions, relationEmoji } from "./modell/graf.js";

const app = document.getElementById("app");

// MARK: Inställningar (sparas i webbläsaren, samma nycklar som appens AppStorage)

const yesNo = [true, false];
const gameTitles = ["Nyhetsknuten", "Systemknuten"];

/** Varje inställning: förval och tillåtna värden. Ett lagrat värde utanför listan ger förvalet. */
const settingsSchema = {
  "rumorMode": { fallback: RumorMode.ownMovesOnly, allowed: Object.values(RumorMode) },
  "nk.leakWhileRunning": { fallback: true, allowed: yesNo },
  "nk.anonymousSources": { fallback: true, allowed: yesNo },
  "nk.finale": { fallback: true, allowed: yesNo },
  "sk.hardLinesCanFall": { fallback: false, allowed: yesNo },
  "clock.secondsPerDay": { fallback: 3.5, allowed: [5.0, 3.5, 2.0] },
  "clock.turnBased": { fallback: false, allowed: yesNo },
  ...Object.fromEntries(gameTitles.map((t) => [`tipsSeen.${t}`, { fallback: false, allowed: yesNo }])),
};

/**
 * localStorage kan saknas, vara spärrat eller fullt (privat läge). Det som inte gick att spara ligger då kvar
 * i minnet och läses före localStorage, så att inställningen gäller resten av besöket.
 */
const memory = new Map();
function load(key) {
  const { fallback, allowed } = settingsSchema[key];
  let raw = memory.get(key) ?? null;
  if (raw === null) { try { raw = localStorage.getItem(key); } catch { raw = null; } }
  if (raw === null) return fallback;
  let value;
  try { value = JSON.parse(raw); } catch { return fallback; }
  return allowed.includes(value) ? value : fallback;
}
function save(key, value) {
  const raw = JSON.stringify(value);
  try { localStorage.setItem(key, raw); memory.delete(key); } catch { memory.set(key, raw); }
}
const tipsKey = (title) => `tipsSeen.${title}`;
function tipsSeen(title) { return load(tipsKey(title)) === true; }
function clearTipsSeen() {
  for (const title of gameTitles) {
    memory.delete(tipsKey(title));
    try { localStorage.removeItem(tipsKey(title)); } catch { /* bara minnet fanns */ }
  }
}

function newsSettings() {
  return {
    ...defaultNewsSettings(),
    rumors: load("rumorMode"),
    leakWhileRunning: load("nk.leakWhileRunning"),
    anonymousSources: load("nk.anonymousSources"),
    finale: load("nk.finale"),
  };
}

// MARK: Små hjälpare

/** Bygger ett element. Text sätts alltid som text, aldrig som HTML. */
function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === null || v === undefined || v === false) continue;
    if (k === "class") el.className = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (k === "style") el.style.cssText = v;
    else el.setAttribute(k, v === true ? "" : v);
  }
  for (const c of children.flat(Infinity)) if (c !== null && c !== undefined && c !== false) el.append(c);
  return el;
}

/** Byter ett elements barn; listor plattas ut och tomma platser hoppas över, som i h(). */
function fill(el, ...children) {
  el.replaceChildren(...children.flat(Infinity).filter((c) => c !== null && c !== undefined && c !== false));
}

const img = (name, cls, alt = "") => h("img", { src: `bilder/${name}.svg`, class: cls, alt, draggable: "false" });

/** Haptik där telefonen har det (game-art-direction: minst två slags återkoppling per handling). */
function buzz(pattern) {
  try { navigator.vibrate?.(pattern); } catch { /* ingen vibration */ }
}

const reduceMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// MARK: Navigering (#nyhetsknuten och #systemknuten, så att telefonens bakåtknapp går till menyn)

const variants = {
  nyhetsknuten: { make: () => { const s = newsSettings(); return () => new NewsKnotGame(s); }, theme: "nyhet", themeColor: "#171717" },
  systemknuten: { make: () => { const seed = randomSeed(), hard = load("sk.hardLinesCanFall"); return () => new SystemKnotGame(seed, hard); }, theme: "system", themeColor: "#1c3629" },
};

let screen = null; // { stop() } för skärmen som visas
let cameFromMenu = false; // spelet öppnades från menyn, så "Till menyn" kan gå bakåt i historiken

function route() {
  screen?.stop();
  screen = null;
  const key = location.hash.slice(1);
  if (variants[key]) screen = startGame(variants[key]);
  else showMenu();
  window.scrollTo(0, 0);
}

/** Tillbaka till menyn utan att lägga en ny rad i historiken (telefonens bakåtknapp ska inte öppna spelet igen). */
function toMenu(ev) {
  ev.preventDefault();
  if (cameFromMenu) { cameFromMenu = false; history.back(); } else location.replace("#");
}
window.addEventListener("hashchange", route);

// MARK: Menyn

/** Sidans palett och webbläsarens färg på statusraden. */
function setTheme(theme, color) {
  if (theme) document.documentElement.setAttribute("data-theme", theme); else document.documentElement.removeAttribute("data-theme");
  document.querySelector('meta[name="theme-color"]').setAttribute("content", color);
}

function showMenu() {
  setTheme(null, "#000000");
  let helpReset = false;
  const foot = h("p", { class: "foot" });
  const setFoot = () => {
    foot.textContent = helpReset ? "Klart – hjälpen visas nästa gång du öppnar ett spel."
      : "Alla rubriker i spelet är verkliga. Vi hittade inte på dem. Vi hade inte behövt. Ryktena hittade vi på.";
  };
  setFoot();

  const select = (id, label, key, options) => h("div", { class: "row" },
    h("label", { for: id }, label),
    h("select", { id, onchange: (e) => save(key, options[e.target.selectedIndex][1]) },
      options.map(([text, value]) => h("option", { selected: load(key) === value }, text))));
  const toggle = (id, label, key) => h("div", { class: "row" },
    h("label", { for: id }, label),
    h("input", { id, type: "checkbox", checked: load(key), onchange: (e) => save(key, e.target.checked) }));
  const entry = (hash, picture, title, text) => h("a", { class: "entry", href: `#${hash}`, onclick: () => { cameFromMenu = true; } },
    picture, h("div", {}, h("strong", {}, title), h("span", {}, text)), h("span", { class: "chev", "aria-hidden": "true" }, "›"));

  fill(app, h("div", { class: "screen menu" },
    h("h1", {}, "Tryck gult!"),
    h("p", { class: "lead" }, "Provbänk, omgång 9. Du är knuten – låsningen i regeringsbildningen hösten 2026."),
    h("h2", { class: "section-head" }, "Omgång 8 – två knutar"),
    h("div", { class: "list" },
      entry("nyhetsknuten", img("knuten-neutral", ""), "Nyhetsknuten", "Du är knuten. Nyheterna stoppar tiden – reagera, läck i rätt tid, vinn på extraval."),
      entry("systemknuten", img("lampa-tand", ""), "Systemknuten", "Partierna förhandlar av sig själva. Stoppa Ribban med tre stämplar.")),
    h("h2", { class: "section-head" }, "Inställningar"),
    h("div", { class: "list" },
      select("s-dagar", "Dagar", "clock.turnBased", [["Rullar av sig själva", false], ["Tur för tur", true]]),
      select("s-fart", "Spelhastighet", "clock.secondsPerDay", [["Lugn (5 s/dag)", 5.0], ["Normal (3,5 s/dag)", 3.5], ["Snabb (2 s/dag)", 2.0]]),
      select("s-rykten", "Rykten", "rumorMode", [["Bara mina drag / föremål", RumorMode.ownMovesOnly], ["Även påhittade partimöten", RumorMode.alsoRealPartyMeetings]]),
      toggle("s-lacka", "Nyhetsknuten: läcka medan tiden går", "nk.leakWhileRunning"),
      toggle("s-anonyma", "Nyhetsknuten: ENLIGT UPPGIFTER-nyheter", "nk.anonymousSources"),
      toggle("s-slutspurt", "Nyhetsknuten: TÄNK OM-slutspurt efter 18 nov", "nk.finale"),
      toggle("s-harda", "Systemknuten: hårda röda linjer kan falla", "sk.hardLinesCanFall"),
      h("div", { class: "row" }, h("button", { class: "link", type: "button", onclick: () => { clearTipsSeen(); helpReset = true; setFoot(); } }, "Visa starthjälpen igen"))),
    foot));
}

// MARK: Spelskärmen

function startGame(variant) {
  const fresh = variant.make();
  let game = fresh();
  let running = true;
  let tipsOpen = false;
  let timer = 0; // 0 = klockan väntar inte på någon dag just nu
  const turnBased = load("clock.turnBased") === true;
  const secondsPerDay = Number(load("clock.secondsPerDay")) || 3.5;

  setTheme(variant.theme, variant.themeColor);

  const pauseBtn = h("button", { class: "icon-btn", type: "button", onclick: () => { running = !running; render(); } });
  const hud = h("section", { class: "hud" });
  const bars = h("section", { class: "bars", "aria-label": "Mätaren" });
  const notices = h("section", { class: "notices", "aria-label": "Notiser" });
  // Bara huvudkortet läses upp av skärmläsare; det byts bara när en ny nyhet eller effekt kommer.
  const main = h("section", { class: "main", "aria-live": "polite" });
  const actions = h("section", { class: "actions", "aria-label": "Handlingar" });
  const board = makeBoard(() => game.relations);
  const overlayHost = h("div");

  fill(app, h("div", { class: "screen" },
    h("header", { class: "bar" },
      h("a", { class: "icon-btn link-btn", href: "#", onclick: toMenu, "aria-label": "Till menyn" }, "‹ Meny"),
      h("h1", {}, game.title),
      turnBased ? null : pauseBtn,
      h("button", { class: "icon-btn", type: "button", "aria-label": "Så spelar du", onclick: () => openTips() }, "?")),
    hud, bars, notices, main, actions, board.el, overlayHost));

  // Vad som redan visas, så att kort och effekter bara animeras när de är nya.
  let shownMain = null;
  let shownNotices = [];

  function act(fn) {
    buzz(12);
    const wasPaused = game.paused;
    fn();
    if (!wasPaused && game.paused) buzz([30, 40, 30]);
    render();
  }

  function render() {
    syncClock();
    renderHud();
    renderBars();
    renderNotices();
    renderMain();
    renderActions();
    board.update();
    renderEnding();
    if (!turnBased) {
      pauseBtn.textContent = running ? "❚❚" : "▶";
      pauseBtn.setAttribute("aria-label", running ? "Pausa klockan" : "Starta klockan");
    }
  }

  function renderHud() {
    const meters = game.meters.map((m) => h("div", { class: "meter" },
      m.name === "Lampor"
        ? h("div", { class: "lamps", role: "img", "aria-label": `${[...m.value].filter((c) => c === "●").length} av 4 lampor tända` },
            [...m.value].map((c) => img(c === "●" ? "lampa-tand" : "lampa-slackt", "")))
        : h("b", {}, m.value),
      h("small", {}, m.name)));
    const captions = game.meters.filter((m) => m.caption).map((m) => h("p", { class: "caption" }, `${m.name}: ${m.caption}`));
    const hint = turnBased ? h("p", { class: "hint" }, "Tur för tur: dagen går först när du trycker Avsluta dagen.")
      : !running ? h("p", { class: "hint warn" }, "Klockan står still – tryck ▶ för att fortsätta.") : null;
    fill(hud,
      h("div", { class: "meters" }, game.figure ? img(game.figure, "figure") : null, meters),
      h("div", { class: "daybar", role: "progressbar", "aria-label": `Dag ${game.day}`, "aria-valuemin": "0", "aria-valuemax": String(Math.max(game.day, lastDay)), "aria-valuenow": String(game.day) },
        h("i", { style: `width:${(100 * game.day) / Math.max(game.day, lastDay)}%` })),
      captions, hint);
  }

  function renderBars() {
    const list = game.bars;
    // Raderna återanvänds så att staplarna glider till sitt nya värde.
    const rows = new Map([...bars.children].map((el) => [el.dataset.label, el]));
    const next = list.map((b) => {
      let row = rows.get(b.label);
      if (!row) {
        row = h("div", { class: "bar-row", "data-label": b.label },
          h("header", {}, h("span", { class: "name" }), h("span", { class: "val" })),
          h("div", { class: "track" }, h("div", { class: "ghost", style: "width:0" }), h("div", { class: "fill", style: "width:0" }),
            b.marks.map((m) => h("div", { class: `mark${m >= b.max * 0.8 || b.max > 100 ? " high" : ""}`, style: `left:${(100 * m) / b.max}%` }))));
      }
      row.classList.toggle("lead", b.isLeading);
      row.querySelector(".name").textContent = b.label + (b.isLeading ? "  · leder" : "");
      row.querySelector(".val").textContent = `${Math.trunc(b.value)}` + (b.max === 100 ? " %" : ` av ${Math.trunc(b.marks[0] ?? b.max)}`);
      const pct = (v) => `${(100 * Math.min(v, b.max)) / b.max}%`;
      requestAnimationFrame(() => {
        row.querySelector(".ghost").style.width = pct(b.ghost);
        row.querySelector(".fill").style.width = pct(b.value);
      });
      return row;
    });
    fill(bars, ...next);
    bars.hidden = list.length === 0;
  }

  function renderNotices() {
    const recent = game.notices.slice(-3);
    notices.hidden = recent.length === 0;
    const label = (k) => (k === "rumor" ? "RYKTE" : k === "whatIf" ? "TÄNK OM" : "NOTIS");
    fill(notices, ...recent.map((n, i) => h("div", {
      class: `notice${i === recent.length - 1 ? " newest" : ""}${shownNotices.includes(n) ? "" : " enter"}`,
    }, h("span", { class: `tag${n.kind === "info" ? " info" : ""}` }, label(n.kind)), h("span", {}, n.text))));
    shownNotices = [...game.notices];
  }

  function renderMain() {
    const n = game.paused;
    const key = n ? `news:${n.day}:${n.title}:${game.newsChoices.map((c) => c.id + c.preview).join()}` : game.effect;
    if (key === shownMain) return;
    shownMain = key;
    if (n) fill(main, newsCard(n));
    else if (game.effect) fill(main, effectBox(game.effect));
    else fill(main);
  }

  function newsCard(n) {
    const tag = n.kind === "real" ? (n.tag === "locks" ? "I VERKLIGHETEN · GÅVA" : "I VERKLIGHETEN") : n.kind === "anonymous" ? "ENLIGT UPPGIFTER" : "RYKTE · påhittat";
    const choices = game.newsChoices;
    return h("article", { class: "news", "aria-label": "Nyhet" },
      h("div", { class: "top" },
        h("span", { class: `tag ${n.kind}` }, tag),
        h("b", {}, dateText(n.day)),
        h("span", { class: "still" }, "❚❚ Tiden står still")),
      h("h2", {}, n.title),
      n.kind !== "rumor" ? h("p", { class: "source" }, "Källa: " + n.source) : null,
      h("div", { class: "choices" },
        choices.length === 0
          ? h("button", { class: "primary", type: "button", onclick: () => act(() => game.resume()) }, "Fortsätt")
          : choices.map((c) => choiceButton(c))));
  }

  function effectBox(e) {
    const step = reduceMotion() ? 0 : 0.28;
    return h("div", { class: `effect ${e.tone}`, role: "status" },
      h("h2", {}, e.title),
      h("div", { class: "chips" }, e.chips.map((c, i) => h("span", { class: "chip", style: `animation-delay:${0.05 + step * (i + 1)}s` }, c))),
      // Som EffectBox.swift: förklaringen kommer samtidigt som sista chipet.
    e.reason ? h("p", { style: `animation-delay:${0.05 + step * e.chips.length}s` }, e.reason) : null);
  }

  function choiceButton(c) {
    return h("button", { class: `choice${c.icon ? " stamp" : ""}`, type: "button", onclick: () => act(() => game.play(c.id)) },
      c.icon ? img(c.icon, "") : null,
      h("span", {},
        h("span", { class: "t" }, c.title),
        c.preview ? h("span", { class: "pv" }, c.preview) : null,
        h("span", { class: "q" }, c.quip)));
  }

  function renderActions() {
    if (game.paused || game.ending) { fill(actions); return; }
    const cards = game.cards;
    fill(actions,
      cards.map((c) => choiceButton(c)),
      cards.length === 0 ? h("p", { class: "empty" }, turnBased ? "Inget att göra i dag." : "Inget att göra just nu. Dagarna går.") : null,
      turnBased ? h("button", { class: "primary", type: "button", onclick: () => act(() => game.tick(1)) }, "Avsluta dagen") : null);
  }

  let shownEnding = null;
  function renderEnding() {
    const e = game.ending;
    if (e === shownEnding) return;
    shownEnding = e;
    if (!e) { fill(overlayHost); return; }
    buzz(e.isExtraval ? [40, 60, 40, 60, 120] : [200]);
    fill(overlayHost, h("div", { class: `overlay ending${e.isExtraval ? " extraval" : ""}`, role: "dialog", "aria-modal": "true", "aria-label": e.title },
      e.isExtraval && game.figure ? img("knuten-triumf", "") : null,
      h("h2", {}, e.title),
      h("p", {}, e.text),
      h("div", { class: "buttons" },
        h("button", { class: "primary", type: "button", onclick: () => { game = fresh(); running = true; shownMain = null; shownNotices = []; board.reset(); render(); window.scrollTo(0, 0); } }, "Spela igen"),
        h("a", { class: "secondary link-btn", href: "#", onclick: toMenu }, "Till menyn")),
      e.footnote ? h("p", { class: "foot" }, e.footnote) : null));
    overlayHost.querySelector("button").focus();
  }

  function openTips() {
    tipsOpen = true;
    const close = () => { tipsOpen = false; save(tipsKey(game.title), true); sheet.remove(); syncClock(); };
    const sheet = h("div", { class: "overlay sheet", role: "dialog", "aria-modal": "true", "aria-label": "Så spelar du", onclick: (ev) => { if (ev.target === sheet) close(); } },
      h("div", { class: "panel" },
        h("h2", {}, "Så spelar du"),
        h("ol", {}, game.tips.map((t) => h("li", {}, t))),
        h("p", { class: "note" }, "Varje knapp visar vad den gör innan du trycker. Rykten och TÄNK OM kommer som små notiser och stoppar inte tiden."),
        h("button", { class: "primary", type: "button", onclick: close }, "Uppfattat")));
    app.append(sheet);
    sheet.querySelector("button").focus();
    syncClock();
  }

  // Klockan: en dag i taget när ingen nyhet visas, spelet pågår, hjälpen är stängd, fliken syns och dagarna rullar.
  // Varje gång klockan börjar gå igen (efter en nyhet, paus, hjälpen eller en dold flik) får spelaren en hel dag.
  const clockRuns = () => !turnBased && running && !tipsOpen && document.visibilityState === "visible" && !game.paused && !game.ending;
  function syncClock() {
    if (clockRuns() && timer === 0) {
      timer = setTimeout(() => {
        timer = 0;
        if (!clockRuns()) return;
        game.tick(1);
        if (game.paused) buzz([30, 40, 30]);
        render();
      }, secondsPerDay * 1000);
    } else if (!clockRuns() && timer !== 0) {
      clearTimeout(timer);
      timer = 0;
    }
  }
  document.addEventListener("visibilitychange", syncClock);

  render();
  if (!tipsSeen(game.title)) openTips();

  return {
    stop() {
      document.removeEventListener("visibilitychange", syncClock);
      clearTimeout(timer);
      timer = 0;
      board.stop();
    },
  };
}

// MARK: Bordet (partiernas trådar), port av GraphView.swift

function makeBoard(getLines) {
  const canvas = h("canvas", { role: "img", "aria-label": "Nätverk över partiernas relationer" });
  const legend = h("div", { class: "legend" },
    h("span", {}, "☁️ block"), h("span", {}, `${relationEmoji.attraction} samarbete`), h("span", {}, `${relationEmoji.negotiating} förhandlar`),
    h("span", {}, `${relationEmoji.conflict} röd linje`), h("span", { class: "dim" }, "tjock linje, orange skiva = nytt"),
    h("span", { class: "rumor" }, "lila ring = rykte"));
  const details = h("details", { class: "board" }, h("summary", {}, "Visa bordet (partiernas trådar)"), canvas, legend);

  let layout = new GraphLayout();
  let lastShape = null;
  let blocksChangedAt = -Infinity;
  let lastBlocks = null;
  let last = null;
  let carry = 0;
  let frame = 0;

  const shape = (lines) => JSON.stringify(lines.map((l) => [l.pair, l.kind, l.isNew]));

  function advance(now, lines) {
    const s = shape(lines);
    const blocks = JSON.stringify(clusters(lines));
    if (lastShape !== null && s !== lastShape) {
      // "Hoppa till": när linjerna ändras får noderna en knuff innan de lägger sig.
      layout.nudge();
      if (blocks !== lastBlocks) blocksChangedAt = now;
    }
    lastShape = s;
    lastBlocks = blocks;
    carry += Math.min((now - (last ?? now)) / 1000, 0.1);
    last = now;
    while (carry >= 1 / 60) { layout.step(lines); carry -= 1 / 60; }
  }

  function draw(now) {
    const lines = getLines();
    advance(now, lines);
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth, hgt = canvas.clientHeight;
    // Dold eller ännu inte utlagd: inget att rita (negativa radier skulle kasta fel).
    if (w <= 2 * 8 || hgt <= 2 * 8) return;
    if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(hgt * dpr)) {
      canvas.width = Math.round(w * dpr); canvas.height = Math.round(hgt * dpr);
    }
    const ctx = canvas.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, hgt);
    const pad = 8;
    const unit = (Math.min(w, hgt) - 2 * pad) / (2 * GraphMetrics.extent);
    const cx = w / 2, cy = hgt / 2;
    const pt = (p) => [cx + p.x * unit, cy + p.y * unit];
    const pos = layout.positions;
    const t = now / 1000;
    const bump = Math.max(0, 1 - (now - blocksChangedAt) / 900);

    // Molnen: en puff runt varje parti i blocket och puffar mellan grannarna, mjukt andande.
    ctx.fillStyle = "rgba(191, 217, 255, 0.16)";
    for (const block of clusters(lines)) {
      ctx.beginPath();
      block.forEach((p, i) => {
        const [x, y] = pt(pos[p]);
        const breathe = 1 + 0.03 * Math.sin(t * 1.6 + i) + 0.18 * bump;
        const r = (GraphMetrics.nodeRadius(p) + 0.16) * unit * breathe;
        ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, 2 * Math.PI);
        for (const q of block.slice(i + 1)) {
          const [mx, my] = pt({ x: (pos[p].x + pos[q].x) / 2, y: (pos[p].y + pos[q].y) / 2 });
          const rm = 0.17 * unit * breathe;
          ctx.moveTo(mx + rm, my); ctx.arc(mx, my, rm, 0, 2 * Math.PI);
        }
      });
      ctx.fill("nonzero");
    }
    for (const line of lines) {
      const [x1, y1] = pt(pos[line.a]), [x2, y2] = pt(pos[line.b]);
      ctx.strokeStyle = line.kind === "conflict" ? "rgba(255, 59, 48, 0.8)" : line.kind === "negotiating" ? "rgba(255, 214, 10, 0.8)" : "rgba(255, 255, 255, 0.8)";
      ctx.lineWidth = line.isNew ? 5 : 2.5;
      ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
    }
    const er = GraphMetrics.emojiRadius * unit;
    const spots = emojiPositions(layout, lines);
    ctx.textAlign = "center"; ctx.textBaseline = "middle";
    for (const line of lines) {
      const [x, y] = pt(spots.get(line.pair));
      ctx.fillStyle = line.isNew ? "rgba(255, 149, 0, 0.35)" : "#1f1f1f";
      ctx.beginPath(); ctx.arc(x, y, er, 0, 2 * Math.PI); ctx.fill();
      if (line.isRumor) {
        // Rykten är spelets påhitt: lila streckad ring skiljer dem från de verkliga rubrikernas linjer.
        ctx.save(); ctx.strokeStyle = "#af52de"; ctx.lineWidth = 2.5; ctx.setLineDash([4, 3]); ctx.stroke(); ctx.restore();
      }
      ctx.font = `${er * 1.25}px system-ui, sans-serif`;
      ctx.fillText(relationEmoji[line.kind], x, y + er * 0.05);
    }
    for (const p of parties) {
      const [x, y] = pt(pos[p]);
      const r = GraphMetrics.nodeRadius(p) * unit;
      ctx.fillStyle = partyInfo[p].color;
      ctx.beginPath(); ctx.arc(x, y, r, 0, 2 * Math.PI); ctx.fill();
      ctx.strokeStyle = "#000"; ctx.lineWidth = 1.5; ctx.stroke();
      ctx.fillStyle = partyInfo[p].textColor;
      ctx.font = `900 ${r * 0.62}px system-ui, sans-serif`;
      ctx.fillText(p, x, y + r * 0.04);
    }
  }

  function loop(now) {
    frame = 0;
    if (!details.open || document.visibilityState !== "visible") return;
    draw(now);
    frame = requestAnimationFrame(loop);
  }
  const start = () => { if (!frame && details.open) { last = null; frame = requestAnimationFrame(loop); } };
  details.addEventListener("toggle", start);
  document.addEventListener("visibilitychange", start);

  return {
    el: details,
    update() { details.hidden = getLines().length === 0; start(); },
    reset() { layout = new GraphLayout(); lastShape = null; lastBlocks = null; },
    stop() { cancelAnimationFrame(frame); frame = 0; details.open = false; document.removeEventListener("visibilitychange", start); },
  };
}

route();
