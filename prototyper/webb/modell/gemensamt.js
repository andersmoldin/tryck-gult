// Gemensamt för knutarna: datum, partier och par. Port av World.swift, Parti.swift och Perspektiv.swift
// i BrytareModell (grenen fm/tg-proto-brytare, omgång 9). Ingen DOM här, så att reglerna går att testa i Node.

/** Sista dagen: 18 nov (dag 0 är valdagen 13 sep). */
export const lastDay = 66;

/** "13 sep", "1 okt" … för dag n efter valdagen. */
export function dateText(day) {
  const months = [{ name: "sep", length: 30 }, { name: "okt", length: 31 }, { name: "nov", length: 30 }];
  let d = 13 + day;
  for (const { name, length } of months) {
    if (d <= length) return `${d} ${name}`;
    d -= length;
  }
  return `${d} dec`;
}

/** Vad rykten får handla om (inställning). */
export const RumorMode = Object.freeze({
  /** Bara föremål, processer och namnlösa källor. */
  ownMovesOnly: "ownMovesOnly",
  /** Också påhittade möten mellan verkliga partier. */
  alsoRealPartyMeetings: "alsoRealPartyMeetings",
});

/** Partierna i Swifts deklarationsordning (P.allCases). */
export const parties = ["V", "S", "MP", "C", "L", "KD", "M", "SD"];

/** Namn, mandat och färger. */
export const partyInfo = {
  S: { name: "Socialdemokraterna", seats: 99, color: "#E8112D", textColor: "#FFFFFF" },
  M: { name: "Moderaterna", seats: 70, color: "#52BDEC", textColor: "#000000" },
  SD: { name: "Sverigedemokraterna", seats: 62, color: "#DDDD00", textColor: "#000000" },
  V: { name: "Vänsterpartiet", seats: 30, color: "#AF0000", textColor: "#FFFFFF" },
  C: { name: "Centerpartiet", seats: 25, color: "#009933", textColor: "#FFFFFF" },
  KD: { name: "Kristdemokraterna", seats: 22, color: "#231977", textColor: "#FFFFFF" },
  MP: { name: "Miljöpartiet", seats: 22, color: "#83CF39", textColor: "#000000" },
  L: { name: "Liberalerna", seats: 19, color: "#006AB3", textColor: "#FFFFFF" },
};

export const seats = (p) => partyInfo[p].seats;

/** Så många nej fäller en statsministerkandidat (negativ parlamentarism). */
export const majority = 175;

/** Ordningen från vänster till höger. */
export const leftToRight = ["V", "S", "MP", "C", "L", "KD", "M", "SD"];

/**
 * Två partier som en nyckel ("C|S"). Ordningen spelar ingen roll: den minsta förkortningen först,
 * jämfört som strängar precis som Pair i Swift.
 */
export function pairKey(x, y) {
  return x < y ? `${x}|${y}` : `${y}|${x}`;
}

/** [a, b] ur en parnyckel. */
export function pairParts(key) {
  return key.split("|");
}

/** Jämför två parnycklar som Swift sorterar par: (a, b) i strängordning. */
export function comparePairs(k1, k2) {
  const [a1, b1] = pairParts(k1), [a2, b2] = pairParts(k2);
  return a1 < a2 ? -1 : a1 > a2 ? 1 : b1 < b2 ? -1 : b1 > b2 ? 1 : 0;
}

/** Alla 28 par i Swifts ordning: för (i, a) i allCases, för b efter a. */
export function allPairs() {
  const out = [];
  parties.forEach((a, i) => { for (const b of parties.slice(i + 1)) out.push(pairKey(a, b)); });
  return out;
}

/** Talmannens lampor som text, "●●○○". */
export function lampText(lamps) {
  return "●".repeat(lamps) + "○".repeat(4 - lamps);
}

/** Första största elementet, som Swifts `max(by:)`. */
export function maxBy(list, less) {
  let best;
  let first = true;
  for (const e of list) {
    if (first) { best = e; first = false; } else if (less(best, e)) best = e;
  }
  return best;
}

/** Swifts Int(x) för ett flyttal: trunkerar mot noll. */
export const int = (x) => Math.trunc(x);
