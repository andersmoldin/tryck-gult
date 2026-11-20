# Provbänk – prototyper för ärende #4

En grov app att provspela på telefonen. Startmenyn väljer variant.

## Omgång 7: klockan går (efter `tg-plague`-genomgången)

Dagarna rullar från valdagen 13 sep till 18 nov (1,5 s per dag, paus i verktygsfältet). När en **nyhet** kommer stannar tiden tills du trycker Fortsätt. Nyheterna är **I VERKLIGHETEN** (verkliga händelser ur researchen i ärende #2, med källa) eller **RYKTE** (spelets påhitt, lila). Inget sprids – nyheterna och dina drag ändrar relationerna i nätverket. Bara genrens mekanik är lånad: inga namn, termer, layout eller bilder från förlagan.

- **Knuten:** du är låsningen och vinner om det blir extraval. Förhandlarnas mätare **Uppgörelsen** fylls varje dag, snabbare ju fler broar som finns mellan blocken. Låsande verkliga nyheter är gåvor (Prestige), öppnande ger förhandlarna fart. Korten: röd linje, utspel, sega.
- **Hamna i regering:** välj parti vid start och försök sitta i en regering som klarar omröstningen. Ring, erbjud ministerposter (kostar röda linjer), släpp krav, be om omröstning. Fallna omröstningar och verkliga fall släcker talmannens lampor.
- **Inställning för rykten** i menyn: bara om dina egna drag, eller även påhittade möten mellan verkliga partier.
- I båda varianterna kan ett påhittat utfall nås (en regering bildas); det märks "Tänk om" och "det hände inte i verkligheten".

## Från omgång 6: Talmannen

- Varje vecka har en **verklig rubrik som ankare** (I VERKLIGHETEN, datum, citat, källa) och en **situation** med 2–3 val. Knapparna säger vad som händer i kammaren ("Låt kammaren rösta om Andersson"); vad valet kostar syns först i effektrutan efteråt.
- Valen **förgrenar handlingen**: lutar du åt Andersson, Kristersson eller processen blir nästa veckas situation och val olika.
- Mellan dragen kommer **rykten** från förhandlingar i det fördolda ("C och S har setts äta lunch"). De är spelets påhitt, märkta RYKTE, och ändrar relationerna i nätverket.
- **Nätverket**: partier som samarbetar dras ihop av grafens fysik och samlas i ett moln; röda linjer knuffar isär. Varje linje har en emoji (🤝 samarbete, 💬 förhandlar, ✋ röd linje). Noderna hoppar till och molnen puffar när något ändras.
- Rösterna följer historien – ingen får ihop 175. Poängen är satiren: hur många gånger "samtalen fortsätter", och en torr dom på slutskärmen. Brasklappen: "Alla rubriker i spelet är verkliga. Vi hittade inte på dem. Vi hade inte behövt. Ryktena hittade vi på."

Frågan provspelningen ska besvara: **förstår spelaren varför regeringen föll, och är det kul att förlora?**

Omgång 1–5 prövade brytare, fyra perspektiv och andra sätt att visa relationerna; kaptenen valde talmannen (omgång 6). Historiken finns i git.

## Innehåll

- `BrytareModell/` – spelmodellen som ett rent Swift-paket utan SwiftUI: klockan, nyheterna och ryktena (`World.swift`), Knuten och Hamna i regering (`Varianter.swift`), partier och rubriker, hur partierna röstade längs tidslinjen (`Historia.swift`), talmannens manus, rykten och regler (`SpeakerGame.swift`), och nätverkets linjer, block, kraftlayout och emojiplacering (`Graf.swift`).
- `Brytare/` – SwiftUI-appen: `MenuView` (variantväljare och inställningar), `ClockScreen` (omgång 7), `SpeakerScreen` (talmannen) och `GraphView` (nätverket).
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
