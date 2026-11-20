# Provbänk – prototyper för ärende #4

En grov app att provspela på telefonen. Startmenyn har fyra mycket små spel om samma höst, vart och ett ur ett eget perspektiv. Alla följer de sex verkliga rubrikerna från valnatten till 18 nov:

1. **Statsministerkandidaten** – du leder S och behöver både V och C, men deras krav utesluter varandra.
2. **Talmannen** – varje vecka är en situation med 2–3 val: sondera, ge förhandlingsuppdrag, sätt en deadline eller låt någon försöka. Stödet är okänt tills du sonderat; att ta reda på kostar riksdagens tålamod, att gissa kostar försök. Poängen är hur många gånger samtalen fortsatte (omgång 3).
3. **Vågmästarpartiet** – du leder C. Extraval går att undvika, men bara genom att bryta ett löfte.
4. **Kommentatorn** – du gissar nästa rubrik bland tre. Rätt gissning ger poäng, och tre fel ger sparken.

Alla spelen har samma upplägg. Du gör en sak i taget och väljer mellan 2–3 alternativ, och varje knapp visar vad valet kostar. Ett starttips visas första gången (`?` visar det igen). En kraftriktad graf visar partierna som noder och bara några få nyckelrelationer: vita linjer drar ihop, gula förhandlar och röda är konflikter. Linjer som senaste rubriken ändrade är tjockare. Tryck på grafen för en helskärmsvy med etiketter och en lista där det nya är märkt.

Talmannen bygger dessutom in fem ingredienser från genomgången av kortspelet Swärje (namn och bilder är inte lånade): den verkliga rubriken i ett eget kort och kvickheten på valkortet, en torr spelledarröst, poäng som är själva satiren, en omvänd brasklapp ("Alla rubriker i spelet är verkliga. Vi hittade inte på dem. Vi hade inte behövt.") och skrivregeln att reta alla lika mycket.

**Omgång 5 (bara talmannen):** relationerna visas i ett stort nätverk där partierna står långt isär (`GraphLayout(style: .wide)` och `WideGraphMetrics`; testat rubrik för rubrik som appen kör grafen, så att noder och emojier varken krockar eller hamnar utanför ramen) och varje linje har en emoji i mitten: 🤝 samarbete, 💬 förhandlar, ✋ röd linje. Noderna hoppar till när en rubrik ändrar linjerna. Knapparna säger vad som händer i kammaren ("Låt kammaren rösta om Andersson") med högst en kort rad till; följderna syns först i effektrutan efter valet. Menyn har knappen "Visa starthjälpen igen".

Längst ner i menyn ligger **Brytare** från omgång 1 som jämförelse.

Frågan provspelningen ska besvara: **förstår spelaren varför regeringen föll, och är det kul att förlora?** Den nya frågan är också vilket perspektiv som fungerar bäst.

## Innehåll

- `BrytareModell/` – spelmodellen som ett rent Swift-paket utan SwiftUI. Det innehåller mandat, krav och rubriker, hur partierna röstade längs tidslinjen (`Historia.swift`), de fyra spelen med 175-regeln och extraval (`*Game.swift`, gemensamt protokoll i `Perspektiv.swift`) och grafens linjer och kraftlayout (`Graf.swift`). Brytarvarianten ligger i `Game.swift`.
- `Brytare/` – SwiftUI-appen. `PerspectiveScreen` visar alla fyra spelen, och `GraphView` ritar grafen.
- `Brytare.xcodeproj` – Xcode-projektet. Det signeras automatiskt med team `MT5TUADUWK` (Anders Moldin, Personal Team).

## Testa reglerna (ingen simulator)

```sh
cd prototyper/brytare/BrytareModell
swift test
```

## Bygga och installera på telefonen

Telefonen måste vara parkopplad med datorn och ha utvecklarläget på. Hitta dess UDID med `xcrun devicectl list devices`.

```sh
cd prototyper/brytare
xcodebuild -project Brytare.xcodeproj -scheme Brytare -configuration Debug \
  -destination 'platform=iOS,id=<UDID>' -derivedDataPath build \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> build/Build/Products/Debug-iphoneos/Brytare.app
xcrun devicectl device process launch --device <UDID> prototyp.tryckgult.brytare
```

Du kan också öppna `Brytare.xcodeproj` i Xcode, välja telefonen och trycka Run (⌘R).

Första gången vägrar telefonen starta appen. Gör då så här på telefonen: **Inställningar > Allmänt > VPN och enhetshantering**, tryck på utvecklarprofilen och sedan **Lita på**.

Med ett gratis Personal Team slutar signeringen gälla efter 7 dagar. Bygg och installera då igen.
