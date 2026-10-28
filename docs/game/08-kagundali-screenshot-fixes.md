# Korrekturen nach den Studio-Bildern vom 28. Oktober

Aktuell: **`kagundali-junction-3`**. Der vom Nutzer kopierte Studio-Output bestätigt,
dass zuvor **junction-2** angewendet wurde: 64 Bäume, 49 Büsche, 47 Farne,
799 Teile und vorhandene Werkstatt. 70 Geländespalten wurden geändert, 30.661
waren bereits aktuell. Die vom Nutzer als neu bezeichneten Bilder und die zusätzliche
Luftaufnahme `Screenshot 2026-10-28 091306.jpg` dienen als Ausgangspunkt.
Sie werden nicht in das öffentliche Repository aufgenommen.

## Befunde und Änderungen

**Straßenmarkierungen:** Der Output enthielt `Road marking probes incomplete` und
`restored 0 marking parts`. In junction-2 verwarf eine einzige fehlgeschlagene Probe
die gesamte neue Markierungsgruppe. Das erklärt, warum das Update erfolgreich enden
konnte, ohne sichtbare Linien wiederherzustellen.

Junction-3 übernimmt jeden erfolgreich geprüften Abschnitt separat. Fehlende Abschnitte
behalten vorhandene Linien; der Output nennt Anzahl und bis zu vier Beispielkoordinaten.
Die Höhenabfrage reicht weiter über und unter die erwartete Fahrbahn. Sichtbarer
Terrain-Asphalt darf bemalt werden, Gras nicht. Die genaue Ursache der ursprünglichen
fehlgeschlagenen Raycasts lässt sich aus dem bisherigen Output allein nicht bestimmen.
Erzeugte Linien außerhalb des Bereichs und anders benannte eigene Markierungen bleiben
erhalten. Wiederholte und globale Updates erzeugen keine zusätzlichen Linien unter
beibehaltenen regionalen Abschnitten.

**Werkstattzufahrt:** Statt zwölf langen Stücken folgen höchstens drei Studs lange
Abschnitte dem Boden. Pro Station wird die neun Studs breite Zufahrt an drei Punkten
geprüft. Kiesoberseiten liegen darüber, Unterkanten reichen in den Boden.
Die bereits eingeführte Grasfreiheit unter der Zufahrt bleibt erhalten. Kiesbankette
folgen ebenfalls der gespeicherten Bodenhöhe; geschützte Flächen werden ausgespart.

**Gelbe Wegweiser:** Richtungstafeln werden mindestens 10,8 × 1,95 Studs groß,
Pfeilspitzen und rückseitige Konstruktion passen sich an. Bestehende Texte und
TextLabel-Instanzen bleiben erhalten. Bereits versetzte Pfosten werden nicht erneut
verschoben; wiederholte Updates vergrößern die Tafeln nicht weiter.

**Bäume und Laternen:** Der neue [Creator-Store-Import](09-creator-store-assets.md)
übernimmt Modelle aus zwei offiziellen Roblox-Paketen und bindet sie direkt in den
Updater ein. Die Bibliothek enthält nur visuelle Geometrie und Texturen. Importierte
Bäume erhalten schmale Stammkollisionen, Laternen die bekannte Nachtlichtsteuerung.
Nur erfolgreich ersetzte alte generierte Laternen werden entfernt.

## Frühere Korrektur an eigenen Baumvorlagen

Bei `Part.Shape = Ball` bestimmt die kleinste Größenachse den Kugeldurchmesser.
Die frühere Offline-Vorschau hatte dagegen frei gestreckte Kugelnetze dargestellt.
Der native Generator konnte deshalb seine dargestellten Blattformen nicht erzeugen.
Roblox beschreibt das Verhalten in der offiziellen
[Ankündigung zu Part.Shape und Size](https://devforum.roblox.com/t/improvements-to-part-shape-size/2443389/1).
Seit `kagundali-trees-2` wird eine gleichmäßige Kugel zunächst als PartOperation gebacken;
erst deren Kopien werden gestreckt und vereinigt. Diese eigenen Vorlagen bleiben für
Installationen ohne Creator-Store-Bibliothek und fehlende optionale Pflanzenkategorien
verfügbar. Ein erfolgreicher Import hat Vorrang.

## Anwenden und prüfen

Hauptbranch **`claude/project-thread-5krwdh`** holen, Place sichern und Play stoppen.
Rojo synchronisieren, speichern, Studio neu starten und Rojo erneut verbinden.
Der Neustart leert bereits mit `require()` geladene alte Module. In die Command Bar:

```lua
require(game.ServerStorage.StudioTools.UseCreatorStoreAssets)()
```

Nach dem Import erscheinen die Vorlagenzahlen je Kategorie; nach dem Kartenupdate
**`kagundali-junction-3`**, Baumversion **`creator-store-1`** und die Anzahl importierter
Laternen. Danach speichern. Für Wiederholungen mit derselben gespeicherten Bibliothek:

```lua
require(game.ServerStorage.StudioTools.UpgradeKagundali)()
```

Der Bericht unterscheidet neue, beibehaltene und übersprungene Markierungsstücke.
`CheckEnvironment()` zählt tatsächliche Bäume und Linien und meldet veraltete Baumversionen.
Die normale Testszene ohne Import enthält 64 Bäume, 49 Büsche, 47 Farne, 23 Felsen und
139 Markierungsstücke, insgesamt **1.248 BaseParts**. Die Import-Testszene mit künstlichen
Packmodellen enthält **835 BaseParts und eine importierte Laterne**. Letztere Zahl ist
keine Messung der echten Roblox-Pakete. Das regionale Limit bleibt 1.600 Teile;
eine Überschreitung stoppt vor dem Austausch der bisherigen regionalen Geometrie.

## Grenzen der Prüfung

Regressionstests prüfen Teilfehler bei Markierungen, deren Höhen und Erhalt,
Importfehler, Skriptentfernung, erhaltene Mesh-/Texturdaten, Bodenplatzierung,
Laternentausch und wiederholte Updates. Der Test-Mock führt weder natives CSG noch
Roblox-Rendering aus. **Ein neues Studio-Bild von junction-3 und den echten importierten
Modellen liegt noch nicht vor.** Packstruktur, sichtbare Texturen, Dreiecksbudget,
Speicherung und Leistung mit 20–25 Spielern müssen dort geprüft werden.

Die regionale Grasgrenze, entfernte kahle Bergflanken und übrigen Stadtplatzhalter
sind mit diesem Schritt noch nicht fertig gestaltet. Vor der Ausweitung entlang der R3
bleibt der Sichtvergleich des zusammenhängenden Kreuzungsbereichs erforderlich.
