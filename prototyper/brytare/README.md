# Provbänk – prototyper för ärende #4

En grov app att provspela på telefonen. Startmenyn har fyra mycket små spel om samma höst, vart och ett ur ett eget perspektiv. Alla följer de sex verkliga rubrikerna från valnatten till 18 nov:

1. **Statsministerkandidaten** – du leder S och behöver både V och C, men deras krav utesluter varandra.
2. **Talmannen** – du väljer vem som får försöka och när det blir omröstning. Att vänta kostar tålamod.
3. **Vågmästarpartiet** – du leder C. Extraval går att undvika, men bara genom att bryta ett löfte.
4. **Kommentatorn** – du gissar nästa rubrik bland tre. Rätt gissning ger poäng, och tre fel ger sparken.

Alla spelen har samma upplägg. Du gör en sak i taget och väljer mellan 2–3 alternativ, och varje knapp visar vad valet kostar. Ett starttips visas första gången (`?` visar det igen). En kraftriktad graf visar partierna som noder: ljusa linjer drar ihop dem, och röda linjer är konflikter. Grafen ändras när rubrikerna slår ner.

Längst ner i menyn ligger **Brytare** från omgång 1 som jämförelse.

Frågan provspelningen ska besvara: **förstår spelaren varför regeringen föll, och är det kul att förlora?** Den nya frågan är också vilket perspektiv som fungerar bäst.

## Innehåll

- `BrytareModell/` – spelmodellen som ett rent Swift-paket utan SwiftUI. Det innehåller mandat, krav, rubriker, 175-regeln och extraval (`Historia.swift`), de fyra spelen (`*Game.swift`, gemensamt protokoll i `Perspektiv.swift`) och grafens linjer och kraftlayout (`Graf.swift`). Brytarvarianten ligger i `Game.swift`.
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
