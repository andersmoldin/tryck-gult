# Provbänken på webben – Nyhetsknuten och Systemknuten

Webbversionen av provbänkens omgång 9, så att spelet går att prova i mobilens webbläsare (till exempel Chrome på Android). Den har samma två varianter som iOS-appen på grenen `fm/tg-proto-brytare`:

- **Nyhetsknuten:** du är knuten och vinner på extraval. Nyheterna stoppar tiden, och du reagerar, läcker i rätt tid och segar.
- **Systemknuten:** partierna förhandlar av sig själva, och du stoppar Ribban med tre stämplar (LÄCKA, KRAV, FÖRHALA).

Inställningarna i menyn är desamma som i appen: Dagar (rullar eller tur för tur), Spelhastighet, Rykten, Nyhetsknutens tre frågor och Systemknutens hårda röda linjer. De sparas i webbläsaren.

## Köra lokalt

Det behövs ingen byggsteg och ingen server-kod, bara en statisk webbserver. Modulerna laddas inte från `file://`, så öppna inte `index.html` direkt.

```sh
cd prototyper/webb
python3 -m http.server 8000
```

Öppna sedan <http://localhost:8000/>. Vill du prova från en telefon i samma nät startar du servern med `--bind 0.0.0.0` och öppnar datorns adress.

Allt spelet behöver finns i mappen: `index.html`, `style.css`, `app.js`, `modell/` och `bilder/`. Inget hämtas från nätet. Därför går mappen att lägga på vilken statisk värd som helst, till exempel GitHub Pages.

## Testa reglerna

```sh
cd prototyper/webb
npm test        # samma som: node --test 'test/*.test.js'
```

Det kräver Node 22 eller senare och inga paket.

- `test/nyhetsknuten.test.js`, `test/systemknuten.test.js` och `test/graf.test.js` är Swift-paketets regeltester (`NewsKnotTests`, `SystemKnotTests`, `Round9Tests`, `GraphTests`), porterade.
- `test/spar.test.js` jämför webbversionen med Swift-modellen steg för steg. `test/spar/spar.json.gz` är skrivet av Swift-modellen och innehåller 39 spelade rundor med testspelare och alla inställningar, plus utgången för Systemknuten med seed 0–199. Varje steg jämförs exakt: datum, mätare, staplar, knappar med förhandsvisning, notiser, effekter, slut och bordets trådar.

Ändras reglerna i Swift måste spåren skrivas om. Lägg då `test/spar/SparTests.swift` i en kopia av `BrytareModell/Tests/BrytareModellTests/` och kör:

```sh
SPAR_UT=/tmp/spar.json swift test --filter Spar
gzip -9 -n -c /tmp/spar.json > prototyper/webb/test/spar/spar.json.gz
```

## Innehåll

- `modell/` – reglerna som rena ES-moduler utan DOM:
  - `gemensamt.js`: datum, partier och par.
  - `nyhetsknuten.js` och `systemknuten.js`: portade rad för rad ur `Nyhetsknuten.swift` och `Systemknuten.swift`. Systemknutens seedade slump (SplitMix64) räknar med 64-bitars `BigInt`, så att samma seed ger samma runda som i Swift.
  - `graf.js`: bordets nätverk, med layout, moln och emojier.
- `app.js` – visningen: menyn, spelskärmen med samma zoner som `ClockScreen.swift`, klockan och bordet. Klockan pausar när fliken inte syns. Telefonen vibrerar vid knapptryck och nyheter där det stöds. Med `prefers-reduced-motion` blir hoppen korta toningar.
- `bilder/` – Fable-bilderna ur appens `Assets.xcassets`, oförändrade.

## Skillnader mot iOS-appen

- **Bakåtknapp:** varianterna har egna adresser (`#nyhetsknuten`, `#systemknuten`), så att telefonens bakåtknapp leder till menyn. Slutskärmen har dessutom knappen Till menyn.
- **Bordet:** ritytan räcker till 1,16 grafenheter i stället för 1. En emoji kan sitta upp till 0,18 vid sidan av sin linje och skulle annars klippas vid kanten. `GraphMetrics.extent` i `graf.js` förklarar beräkningen.
- **Lika värden:** där Swift-koden går igenom en `Dictionary` och flera värden är lika, är ordningen i Swift odefinierad. Webbversionen går då igenom paren i bokstavsordning. Spåren visar att det inte ändrar något i de spelade rundorna.
