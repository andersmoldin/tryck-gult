# Brytare – prototyp för ärende #4

En grov prototyp att provspela på telefonen. Varje parti har en brytare med sitt krav. Slår du på ett parti slås de som krockar med det av. Riktiga rubriker ändrar kraven så fort du närmar dig 175. Efter fyra fallna statsministeromröstningar blir det extraval.

Frågan provspelningen ska besvara: **förstår spelaren varför regeringen föll, och är det kul att förlora?**

## Innehåll

- `BrytareModell/` – spelmodellen som ett rent Swift-paket utan SwiftUI och utan timers. Det innehåller mandat, krav, krockar, rubriker, 175-regeln och extraval. Metoderna returnerar en `FollowUp` när något ska hända senare, och appen väntar ut den.
- `Brytare/` – SwiftUI-appen. `GameController` animerar modellens ändringar och sköter väntetiderna.
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
