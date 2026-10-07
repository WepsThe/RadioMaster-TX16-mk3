# BattLED – accuspanning op de RGB-ringen

[English](README.md) | **Nederlands**

Lua-scripts voor de **RadioMaster TX16S MK3** met **EdgeTX**. De RGB-ringen rond de sticks laten de spanning van de vliegaccu en van de zenderaccu zien als een "brandstofmeter".

- **Volle accu:** de hele ring is groen.
- **Accu loopt leeg:** de kleur gaat via geel naar rood. Afhankelijk van de weergavestijl loopt de ring ook leeg (zie hieronder).
- **Waarschuwingsspanning bereikt:** de hele ring knippert rood. Het knipperen stopt weer als de spanning 0,10 V per cel boven de waarschuwingsgrens komt.
- **Geen telemetrie:** de modelring brandt zwak blauw.

## Weergavestijlen

| Stijl | Wat je ziet |
|---|---|
| **Gauge (12 o'clock)** | De ring wordt korter, tegen de klok in, terug naar 12 uur. Leeg: alleen de led op 12 uur brandt nog. |
| **Full ring** | Alle leds blijven branden; alleen de kleur verandert. |
| **Bottle** | De ring loopt leeg als een fles: het niveau zakt van boven aan beide kanten tegelijk. Leeg: alleen de onderste led brandt nog. |

Bij de stijl **Gauge**:

| Niveau | Verlicht deel van de ring |
|---|---|
| 100 % | hele ring |
| 75 % | 12 → 9 uur |
| 50 % | 12 → 6 uur |
| 25 % | 12 → 3 uur |
| leeg | alleen de led op 12 uur |

## Vereisten

- RadioMaster TX16S MK3 (800×480 kleurenscherm, RGB-ringen rond de sticks)
- EdgeTX met de speciale functie **RGB leds**
- Een telemetriesensor voor de accuspanning van het model, bijvoorbeeld `RxBt`, `A1`, `VFAS` of `Cels`

## Inhoud

| Bestand | Functie |
|---|---|
| `SCRIPTS/TOOLS/BattLED.lua` | Instelscherm **BattLED Setup** (SYS → Tools) |
| `SCRIPTS/RGBLED/BatLed.lua` | Stuurt de RGB-ringen aan tijdens het vliegen |
| `SCRIPTS/RGBLED/BatTst.lua` | Testpatroon om de ringen te controleren |
| `SCRIPTS/BATTLED/lib.lua` | Gedeelde code; in deze map worden ook de instellingen per model opgeslagen |

## Installatie

1. Sluit de zender met USB aan op de computer en kies op de zender **USB Storage (SD)**.
2. Kopieer de map `SCRIPTS` uit dit zip-bestand naar de hoofdmap van de SD-kaart. Bestaande mappen worden aangevuld.
3. Werp de schijf veilig uit en koppel de zender los.

## Instellen

1. Zet het model aan en kies op de pagina **Telemetry** voor **Discover new sensors**.
2. Open **SYS → Tools → BattLED Setup** terwijl het juiste model geselecteerd is.
3. Stel in (wordt direct opgeslagen):

| Instelling | Betekenis |
|---|---|
| **Sensor** | De telemetriesensor met de accuspanning van het model |
| **Battery type** | **LiPo** of **Li-Ion** (zie hieronder) |
| **Cell count** | **Auto** of een vast aantal cellen (1S–14S) |
| **Blink below** | Spanning per cel waarop de ring rood gaat knipperen |
| **LED rings** | Welke ring wat laat zien (zie hieronder) |
| **Display** | Weergavestijl: **Gauge (12 o'clock)**, **Full ring** of **Bottle** (zie hierboven) |

4. Ga naar **Model → Special Functions** en voeg toe:
   - Schakelaar: **ON**
   - Functie: **RGB leds**
   - Waarde: **BatLed**
   - Herhalen: **ON**

De instellingen gelden **per model**. Ze worden opgeslagen in `SCRIPTS/BATTLED/<modelnaam>.cfg`. Hernoem je een model, stel het dan opnieuw in. Twee modellen met dezelfde naam delen hun instellingen.

## Accutypen

De ring volgt een ontlaadcurve per accutype, niet een rechte lijn. Daardoor neemt de ring gelijkmatiger af tijdens de vlucht.

| Type | Hele ring groen vanaf | Leeg | Standaard knipperen onder |
|---|---|---|---|
| LiPo | 3,95 V/cel | 3,50 V/cel | 3,50 V/cel |
| Li-Ion | 3,95 V/cel | 2,70 V/cel | 2,70 V/cel |

Bij het wisselen van accutype wordt **Blink below** automatisch op de standaardwaarde gezet. Daarna kun je die zelf aanpassen in stappen van 0,05 V.

**Let op bij Li-Ion:** 2,70 V is de absolute ondergrens van de cel. Regelmatig zo diep ontladen verkort de levensduur. Veel piloten kiezen 3,0 V.

## Celaantal

- **Auto:** het aantal cellen wordt bepaald uit de spanning bij het aansluiten van de accu. Dit werkt betrouwbaar met een redelijk geladen accu (boven ongeveer 3,6 V per cel). Bij een bijna lege accu van 5S of meer kan het één cel te weinig worden.
- **Vast aantal:** altijd juist, ook met een lege accu.
- **Cels-sensor** (bijvoorbeeld FrSky FLVSS): het aantal cellen komt direct uit de sensor.

Na een accuwissel (3 seconden zonder telemetrie) wordt het celaantal opnieuw bepaald.

## LED-ringen

EdgeTX laat Lua-scripts de stickmode niet uitlezen, daarom is dit een instelling. Bij mode 1 en 3 zit het gas rechts.

| Instelling | Rechterring | Linkerring |
|---|---|---|
| R: model L: radio | model | zender |
| L: model R: radio | zender | model |
| Both: model | model | model |
| R: model L: off | model | uit |
| L: model R: off | uit | model |

De **zenderring** gebruikt het accubereik uit **Radio Setup → Battery range** (min en max) en knippert op de accuwaarschuwing van de zender. Controleer dat dit bereik bij de accu in je zender past, bijvoorbeeld 6,6–8,4 V voor een 2S Li-Ion-pack.

## Testscript

Met **BatTst** kun je de ringen controleren zonder model of accu:

1. Zet in **Special Functions** de waarde van **RGB leds** op **BatTst**.
2. Elke 3 seconden zakt het niveau één stap, in 10 stappen van vol naar leeg, in de weergavestijl die voor het model is ingesteld. Daarna knippert de ring 3 seconden rood en begint het opnieuw.
3. Zet de waarde daarna terug op **BatLed**.

Er staat geen led precies op 12 uur. De "12-uur-led" zit ongeveer 8° ernaast: op de rechterring iets met de klok mee, op de linkerring iets tegen de klok in. Daardoor lijken de ringen een iets andere stand te hebben.

## Goed om te weten

- **Spanning onder belasting:** bij vol gas zakt de spanning in. Tijdens de vlucht laat de ring daardoor iets minder zien dan de werkelijke lading. De spanning wordt afgevlakt, zodat korte dipjes niet direct zichtbaar zijn.
- **Schakelaar-leds:** de leds van de schakelaars SW1–SW6 worden niet aangestuurd.
- **Wijzigingen tijdens het vliegen:** het ledscript leest de instellingen elke 5 seconden opnieuw in.
