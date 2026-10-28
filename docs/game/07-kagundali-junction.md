# Kagundali R3/N5: erster visueller Referenzbereich

**Stand: `kagundali-junction-1`, Licht `neutral-highland-1`.** Der Code und der
Offline-Testaufbau sind umgesetzt. Die visuelle Abnahme in Roblox Studio ist offen:
in der Ausführungsumgebung stehen weder Studio noch ein Renderer für den Place zur
Verfügung. Ein erfolgreiches Testergebnis bestätigt keinen sichtbaren Umbau in deinem
gespeicherten Place. Die übrige Karte bleibt auf der Grundlage `highland-4`.

## Warum die vorherigen Änderungen nicht ausreichten

- **Die bisherige Baumgeometrie war selbst das Problem.** Die fünf aktuellen Bilder
  zeigen große, flache Blattplatten auf einfachen Stämmen. Die bisherige Bibliothek
  erzeugt solche Platten tatsächlich; größere Kronen und mehr Exemplare ändern diese
  Bauweise kaum. Der neue Bereich verwendet eine eigene Bibliothek mit verzweigtem Holz,
  kleinen gewölbten Blättern und überlappenden, räumlichen Kronengruppen.
- **Rojo überträgt Code, baut aber die gespeicherte Welt nicht um.**
  `default.project.json` enthält kein erzeugtes `Workspace.Map` und führt keinen Builder
  aus. Die Studio-Werkzeuge müssen im Bearbeitungsmodus ausgeführt und der Place danach
  gespeichert werden. Ein separates Produktions-/Entwicklungskartensystem gibt es in
  diesem Repository nicht. Welchen lokalen Checkout dein Studio geladen hatte, lässt
  sich aus dieser Umgebung nicht feststellen; ein Synchronisationsfehler ist deshalb
  keine nachgewiesene Erklärung für deine Bilder.
- **`refreshEnvironment()` hatte bewusst begrenzten Umfang.** Es ersetzt erzeugte
  Umgebungsgeometrie, bewahrt aber Terrain, Schilder und Stadtplatzhalter. Der vollständige
  Geländepatch schützt Straßen, Orte und unbekannte/manuell veränderte Geländespalten.
  Deshalb ist die Meldung „Environment refreshed“ kein Beleg für neue Bodenformen.
- **Licht wird während Play erneut berechnet.** Der Client wendet `Environment.Model`
  laufend an. Änderungen allein an gespeicherten Lighting-Eigenschaften reichen nicht.
  Jetzt verwenden das Rojo-Preset und das Wettermodell denselben neutraleren Ausgangsstand.
- **Der Modulcache kann veraltete Funktionen liefern.** Der neue direkte Einstieg
  `UpgradeKagundali` vermeidet die fehlende Methode einer bereits geladenen `BuildMap`-Tabelle.
  Bereits geladene gemeinsame Module benötigen weiterhin einen Studio-Neustart; ein
  Versionsvergleich stoppt das Update bei einem erkennbar alten Lichtmodell.

## Was der Bereich jetzt erzeugt

Die vorhandene R3 trifft bei **X 453, Y 56, Z 3299** auf die N5. Der bearbeitete
Ausschnitt liegt bei X 64–832 und Z 2944–3648. Straßenachsen, Fahrbahnhöhen,
Wasser, Stadtpositionen und Grundstücksdefinitionen bleiben erhalten.

| Bestandteil | Umsetzung |
| --- | --- |
| Bäume | Drei Arten: Laubbaum, Akazie, Eukalyptus; jeweils drei Varianten, unterschiedliche Größen und Drehungen; gebogene, verjüngte Stämme mit verbundenen Ästen |
| Unterwuchs | Eigene Busch- und Farnvorlagen, Waldgruppen, freie Sicht an der Kreuzung und Abstand zu Stromleitungen; teilweise eingegrabene Felsen |
| Terrain | Begrenzte, weich auslaufende Bodenfalten, Mulden und Böschungen; zusammenhängende Grasflächen, Schlamm entlang der Entwässerung und Fels an steilen Schnitten; befestigter Werkstatthof |
| Straße | Zusätzliche Kiesbankette, sichtbare U-Entwässerung, Abbiegepfeil auf der R3-Zufahrt und eine Kieszufahrt zum Werkstatthof; vorhandene Asphaltvariation, Markierungen und Leitplanken bleiben bestehen |
| Schilder | Vorhandene gelbe Wegweiser behalten Text, Pfeile und Boardpositionen; Pfosten rücken hinter die lesbare Fläche, mit Betonfüßen und rückseitigen Verstärkungen |
| Bebauung | Kleine Transportwerkstatt mit Servicebucht, Bürofront, geneigtem Metalldach, Dachnähten, Regenwassertank, Transportkisten, physischem Schild und Nachtlampe; der schwebende Kagundali-Entwicklungsname wird ausgeblendet |
| Licht | Weniger blauer Dunst, neutralere Streuung, geringeres Tages-Ambientlicht und definiertere Schatten; gemeinsames Preset für Bearbeitungsmodus und Laufzeit |
| Wetter | Bestehende Übergänge, Wolken, Regenstärken, Gewitter, Tag/Nacht und qualitätsabhängige Effekte bleiben an das aktualisierte Lichtmodell angeschlossen |

Der deterministische Testaufbau auf generiertem Boden erzeugt **64 Bäume, 49 Büsche,
47 Farne, 23 Felsen und insgesamt 919 BaseParts** im neuen Bereich. Die zusätzlichen
Verstärkungen der bestehenden Schilder werden separat gezählt. Auf gespeichertem,
abweichendem Boden können Objekte entfallen. Bei weniger als 20 geeigneten Baumpositionen
wird die Ersetzung abgebrochen; bei ungeeignetem Werkstattboden meldet der Bericht
`Workshop: false`. Diese Fälle benötigen eine Prüfung vor Ort.

Die 15 Pflanzenvorlagen werden einmalig als insgesamt 60 native CSG-Teile vorbereitet
und in `ServerStorage.RoNationJunctionTrees` gespeichert. Ein Baum verwendet vier sichtbare
CSG-Teile und eine schmale Stammkollision; Busch und Farn je vier nicht kollidierende
Teile. Modelle streamen atomar. Das regionale Limit beträgt 1.600 BaseParts. Das ist
eine Instanzgrenze, **kein Nachweis eines GPU-, Dreiecks- oder Mehrspielerbudgets**.
Es werden eigene Quellformen und Roblox-Materialien verwendet, keine erfundenen Asset-IDs.

## Update in deinem bestehenden Place anwenden

1. In GitHub Desktop auf **`claude/project-thread-5krwdh`** wechseln und **Fetch origin** /
   **Pull origin** ausführen. Den lokalen Ordner verwenden, aus dem `rojo serve` läuft.
2. Den Place mit **File > Save to File As…** sichern. Play stoppen, Rojo verbinden und
   die neuen Module synchronisieren. Danach speichern, Studio neu starten und Rojo
   wieder verbinden, damit bereits geladene Module nicht im Cache bleiben.
3. In Studio **View/Ansicht > Command Bar/Befehlsleiste** öffnen und ausführen:

```lua
require(game.ServerStorage.StudioTools.UpgradeKagundali)()
```

Die erste native CSG-Vorbereitung und die lokale Terrainprüfung können dauern. Im
Output erscheint anschließend `kagundali-junction-1` mit Baum-/Busch-/Farnzahlen,
Teilebudget und Werkstattstatus. Die Studio-Kamera springt an die R3/N5-Kreuzung.
Es ist kein vollständiger `BuildMap.run()`-Neubau erforderlich.

4. Im **Explorer** (Studio: **View/Ansicht > Explorer**) unter **Workspace > Terrain**
   in **Properties/Eigenschaften** `Decoration` aktivieren. Nur das Material `Grass`
   zeigt das native animierte Gras. Der Code versucht nicht, diese gesperrte Eigenschaft
   zu lesen oder zu setzen.
5. Den gespeicherten Stand diagnostizieren:

```lua
require(game.ServerStorage.StudioTools.CheckEnvironment)()
```

Die Prüfung zählt tatsächlich vorhandene neue Baummodelle und prüft regionale Terrain-
und Lichtrevisionen zusätzlich zu den bisherigen globalen Prüfungen. Eine `FIX`-Meldung
für andere Bereiche oder fehlende Audio-IDs bedeutet nicht automatisch, dass die
Kreuzung fehlgeschlagen ist. Die jeweilige Meldung im Output lesen.

6. Speichern, dann Play starten. Den Ort auch auf Straßenhöhe ansehen und prüfen,
   ob die Beleuchtung nach dem Start konsistent bleibt. Danach erneut speichern,
   falls du Einstellungen im Bearbeitungsmodus angepasst hast.

Optional nur die Terrainänderungen zählen, ohne Assets, Geometrie oder Kamera zu ändern:

```lua
require(game.ServerStorage.StudioTools.UpgradeKagundali)({ DryRun = true })
```

Der Patch schreibt ausschließlich erkannte generierte Geländespalten innerhalb des
Ausschnitts. Unbekannte, bemalte oder geschützte Spalten bleiben erhalten. Die regionale
Migration erkennt insbesondere `highland-4`; bei älteren/unbekannten Ständen die
Erkennungszähler beachten und gegebenenfalls zuerst den dokumentierten
[`highland-4`-Upgradepfad](06-environment-overhaul.md#apply-to-an-existing-place) verwenden.
**Terrain wird abschnittsweise geschrieben:** ein späterer Fehler kann bereits geänderte
Abschnitte hinterlassen. Neue Baumvorlagen werden vor Terrainänderungen vorbereitet,
neue Geometrie vor dem Austausch vollständig aufgebaut. Ein erneuter Lauf erkennt schon
aktualisierte Spalten und ersetzt den eigenen Bereich ohne Duplikate.

`BuildMap.run()` und `BuildMap.upgradeEnvironment()` sind mit dem neuen Bereich verbunden.
Ein späteres `refreshEnvironment()` baut eine bereits angewendete Kreuzung wieder mit
den neuen Vorlagen auf, statt dort dauerhaft die alten Baumformen zurückzubringen.
Eigene Handarbeit außerhalb der erzeugten Ordner behalten; erzeugte Ordner sind ersetzbar.

## Vorher/Nachher und Abnahme

**VORHER:** die fünf zuletzt gelieferten Bilder, besonders
`Ro-Nation_neuer_Screenshot.jpg` (N5/R3-Wegweiser),
`Ro-Nation_2026-10-27_223933.jpg` (Blattplatten), sowie `224001`, `224005` und `224100`.
Sie wurden als Problemdokumentation ausgewertet, nicht als gewünschter Stil.

**NACHHER: noch nicht vorhanden.** Kein Zugriff auf Roblox Studio, den laufenden Place,
native CSG-Ausführung oder einen Spielrenderer. Es wurden daher keine tatsächlichen
Spielbilder nach dem Update aufgenommen und keine sichtbaren Ergebnisse behauptet.

![Softwarevorschau der Baum-Quellgeometrie, kein Roblox-Render und kein Nachherbild](kagundali-tree-sources.png)

Diese Vorschau wird mit `tools/preview-junction-trees.py` direkt aus den Pflanzenvorlagen
erzeugt. Sie half, zu offene Kronen und die Blattverteilung zu korrigieren. Sie bildet
weder Roblox-CSG noch Materialtexturen, Spielbeleuchtung oder Terrain ab.

Für die tatsächliche Abnahme im selben Place:

- Dieselbe R3/N5-Perspektive wie im Vorherbild aufnehmen; zusätzlich auf Straßenhöhe
  die kleinen Blätter, Astanschlüsse, Baumfüße, Kiesbankette und Schilder ansehen.
- Werkstatt und ihre R3-Zufahrt prüfen; keine schwebenden Fundamente oder Pflanzen,
  keine Pfosten vor der Beschriftung, keine Straße durch Unterwuchs.
- Klare Mittagsbeleuchtung und bedeckten Himmel vergleichen, dann Morgen, Abend und
  Nacht; im Play-Modus Regen, Gewitter, Lampen, Unterstände und das Wettermenü testen.
- Speichern und neu öffnen; anschließend den Updater erneut ausführen und auf
  unveränderte Objektzahlen beziehungsweise fehlende Duplikate achten.
- Native CSG-Kompilierung, Dreiecke, Streaming und Bildrate auf einem schwächeren Gerät
  sowie Synchronisation und Verhalten mit mehreren Clients prüfen.

**Der visuelle Meilenstein bleibt bis zu diesem Vergleich offen.** Erst nach erfolgreicher
Abnahme soll dieselbe Gestaltung auf die übrige Landschaft übertragen werden.

## Dateien und Prüfgrenzen

Abschlussprüfung am 28. Oktober 2026: vollständige Karten-Testsuite bestanden,
86 Umgebungs-/Wetterprüfungen und 90 Bot-Tests bestanden. Alle 67 Luau-Quelldateien
kompilieren, die 18 geänderten Luau-Dateien bestehen StyLua und der Rojo-Build ist
erfolgreich. Die 13 entsprechenden Lichtwerte des gespeicherten Presets stimmen mit
dem anfänglichen Laufzeitmodell überein. Der vollständige Offline-Aufbau enthält
39.361 BaseParts unter `Workspace.Map`; diese Zahl beschreibt die ganze Karte,
nicht den regionalen Zuwachs und nicht die Zahl gleichzeitig gerenderter Teile.

| Dateien | Verantwortung |
| --- | --- |
| `src/studio/UpgradeKagundali.luau`, `BuildMap.luau` | Direkter Aufruf, Kamerafokus, Einbindung in bestehende Builder |
| `src/studio/Map/JunctionLandscape.luau`, `KagundaliUpdate.luau` | Lokale Bodenformen, konservative Migration, vorbereiteter Geometrieaustausch und Versionsstände |
| `src/studio/Map/Builders/JunctionTrees.luau`, `Kagundali.luau` | Originalpflanzen, Platzierung, Bankette, Entwässerung, Wegweiser und Werkstatt |
| `src/shared/Environment/Model.luau`, `Presentation.luau`, `src/shared/Config/Environment.luau`, `default.project.json` | Laufzeitlicht, Wetterbezug und identisches gespeichertes Anfangspreset |
| `src/studio/CheckEnvironment.luau` | Prüfung tatsächlich gespeicherter regionaler Geometrie und Revisionen |
| `tests/map/`, `tests/environment/model.spec.luau` | Gelände-/Builderintegration, Wiederholung, Fehlerfälle, Modelllicht und bestehende Regressionen |
| `tools/preview-junction-trees.py`, `tests/map/preview-junction.luau` | Reproduzierbare Quellgeometrievorschau |

Die automatisierten Tests prüfen echte Builder gegen ein strenges Roblox-Objektmodell,
aber simulieren native CSG-Operationen und Terrain-Raycasts. Die Terrainmigration wird
zusätzlich mit tatsächlichen Vier-Stud-Voxelarrays des bisherigen Generators geprüft:
DryRun schreibt nichts, bemalte/geschützte Spalten bleiben erhalten und der zweite
Patch schreibt bereits aktuelle Spalten nicht erneut. Straßenhöhen, Wasser und Gelände
außerhalb des Ausschnitts werden auf Unverändertheit geprüft.

Offen bleiben die echte Sichtprüfung, native CSG-Ausführung, Fahr-/Kollisionstest,
Speichern/Neuladen und Leistung mit 20–25 Spielern. Die mitgelieferten Regen-/Donner-WAVs
müssen weiterhin auf Roblox hochgeladen und für die Experience freigegeben werden;
die leeren IDs bleiben stumm. Die übrigen Stadtplatzhalter, Agrargebiete, Berge und
weiteren Straßen erhalten in diesem Schritt keinen vorzeitig behaupteten Komplettumbau.

**Nächster Bereich nach Abnahme:** die R3 westwärts Richtung Kagundali, mit dem
Übergang von der Transportwerkstatt zur Bergbau-/Industriezufahrt.
