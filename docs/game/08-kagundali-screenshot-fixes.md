# Korrekturen nach den Studio-Bildern vom 28. Oktober

Stand: **`kagundali-junction-2` / `kagundali-trees-2`**. Die drei Nutzeraufnahmen
zeigen den ersten angewendeten Kreuzungsstand. Werkstatt, native Grasdekoration und
neue Baumgruppen sind im Place angekommen; die visuelle Qualität reicht noch nicht aus.

## Befunde

- `083507.jpg`: Werkstatt und Vorplatz sind vorhanden. Vor der Werkstatt wächst dichtes
  Gras; eine durchgehende Kieszufahrt ist kaum erkennbar.
- `083519.jpg`: Die Kreuzung und gelben Wegweiser sind vorhanden. Rand-, Mittel- und
  Haltelinien sind nicht erkennbar. Das Bild erklärt nicht, ob sie fehlen oder unter einer
  gespeicherten Fahrbahn liegen. Die hellen Schildumrisse sind Studio-Auswahlmarkierungen.
- `083533.jpg`: Die neuen Kronen bestehen sichtbar aus kleinen Kugeln. Die deutliche
  Grenze des Grasbereichs und große Entwicklungsbeschriftungen bleiben sichtbar.

Die vollständigen Dateinamen lauten jeweils `Screenshot 2026-10-28 HHMMSS.jpg`.
Die Aufnahmen wurden geprüft, aber nicht in das öffentliche Repository aufgenommen.
Sie sind echte Nutzerbilder von junction-1, keine Abnahme der folgenden Korrekturen.

## Ursache und Korrektur

Der Baumfehler lag im Generator **und** der Offline-Vorschau: `Part.Shape = Ball`
erzeugt auch bei unterschiedlichen Größenwerten eine Kugel mit dem Durchmesser der
kleinsten Achse. Dünne Blätter wurden dadurch winzig und Kronengruppen zu kleinen
runden Büscheln. Die Vorschau skalierte ein Kugelnetz frei auf drei Achsen und zeigte
eine Fülle, die der bisherige Studio-Generator nicht erzeugte. Das ist ein
Implementierungsfehler, kein Beleg für einen fehlgeschlagenen Rojo-Sync.
Roblox beschreibt das Verhalten in der offiziellen
[Ankündigung zu Part.Shape und Size](https://devforum.roblox.com/t/improvements-to-part-shape-size/2443389/1).

`JunctionTrees.prepare()` erzeugt jetzt zunächst aus einer gleichmäßigen Kugel eine
native `PartOperation`. Ihre Kopien werden zu den vorgesehenen Blattformen gestreckt
und dann zur Krone vereinigt. Es bleiben vier sichtbare Teile je Pflanze. Die erste
Vorbereitung benötigt 61 CSG-Aufrufe einschließlich der Grundform; gespeichert werden
60 Teile in 15 Vorlagen. `Automatic` ersetzt `Performance` für die Detaildarstellung.
Die neue Assetversion erzwingt die Ersetzung der alten Kugelkronen. Der Mock berücksichtigt
nun das tatsächliche Ball-Größenverhalten.

Weitere Korrekturen:

- Unter der Kieszufahrt wird `Grass` durch `Ground` ersetzt. Der konservative Patch
  erkennt gespeichertes junction-1 und die globale highland-4-Grundlage.
- Der fokussierte Updater stellt Markierungen innerhalb des Ausschnitts wieder her.
  Raycasts messen ausschließlich gespeicherte Straßen-/Brückenflächen. Alte erzeugte
  Linien behalten ihre Abschnitte außerhalb des Ausschnitts. Eigene anders benannte
  Markierungen bleiben erhalten. Bei fehlenden Fahrbahnproben wird die neue Gruppe
  verworfen, vorhandene Markierungen bleiben erhalten und der Output meldet den Fall.
- Bereits verbesserte Schildpfosten werden beim Versionswechsel nicht erneut versetzt.
- Die schwebenden Ortsbeschriftungen unter dem erzeugten `Map.Places` werden ausgeblendet,
  einschließlich der Grenz-/Stadtnamen im Hintergrund. Physische Wegweiser behalten ihren Text.

## Anwenden

Hauptbranch **`claude/project-thread-5krwdh`** holen, Place sichern und Play stoppen.
Rojo synchronisieren, speichern, Studio neu starten und Rojo erneut verbinden.
Der Neustart leert bereits mit `require()` geladene alte Updater. In die Command Bar:

```lua
require(game.ServerStorage.StudioTools.UpgradeKagundali)()
```

Im Output muss **`kagundali-junction-2`** erscheinen. Der deterministische Testaufbau
enthält 64 Bäume, 49 Büsche, 47 Farne, 23 Felsen und 139 Markierungsstücke, insgesamt
**1.058 BaseParts** im regionalen Ordner. Zahlen können auf geschütztem Gelände oder
bei fehlenden Fahrbahnflächen abweichen. Das Limit von 1.600 Teilen umfasst jetzt auch
die Markierungen. Danach speichern und die gleichen drei Perspektiven vergleichen.

## Tests und offene Sichtprüfung

Regressionstests prüfen skalierte Festkörper statt Ball-Parts, Ersetzung alter Vorlagen,
Grasfreiheit der Zufahrt, Migration gespeicherter v1-Voxelspalten, Erhalt bemalter und
geschützter Spalten, Wiederholung ohne neue Terrainänderungen, Markierungshöhen und
äußere Linienabschnitte sowie fehlende Fahrbahnproben und den Schild-Versionswechsel.
Die vollständige Kartensuite und 86 Umgebungsprüfungen bestehen, alle 68 Luau-Quelldateien
kompilieren, StyLua und der Rojo-Build sind erfolgreich. Der Mock ersetzt weiterhin native CSG-Ausführung
und Raycasts; er ist kein Renderer.

**Die korrigierten Kronen und Markierungen sind noch nicht in einem neuen Studio-Bild
verifiziert.** Die Quellgeometrievorschau zeigt die beabsichtigte Form, keinen Nachweis
des neuen CSG-Ergebnisses. Native Verarbeitung, Speicherung, Dreiecksbudget und Leistung
mit 20–25 Spielern bleiben zu prüfen. Die scharfe regionale Grasgrenze, entfernte kahle
Bergflanken und übrigen Stadtplatzhalter sind mit diesem Fehlerbehebungsschritt nicht
fertig gestaltet. Vor der Ausweitung entlang der R3 braucht der Bereich den erneuten Sichtvergleich.
