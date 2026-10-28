# Roblox Spiel

Dieses Projekt benutzt **Rojo**. Damit liegt der Code hier im GitHub-Repo als normale Dateien, und Rojo überträgt ihn live nach Roblox Studio.

## Wie funktioniert Rojo?

Normalerweise schreibst du Skripte direkt in Roblox Studio. Mit Rojo ist es so:

1. Der Code liegt als Dateien auf deinem Computer (im Ordner `src`).
2. Rojo läuft im Hintergrund und "beobachtet" diese Dateien.
3. Das Rojo-Plugin in Studio ist mit Rojo verbunden. Sobald sich eine Datei ändert, landet die Änderung sofort in Studio.
4. Weil die Dateien in Git/GitHub liegen, kann auch Claude Code schreiben. Du holst dir die Änderungen, und sie erscheinen in Studio.

Wichtig: **Rojo schickt nur in eine Richtung, von den Dateien nach Studio.** Skripte, die du direkt in Studio änderst, werden nicht zurück in die Dateien gespeichert. Skripte also immer in den Dateien bearbeiten. Bauen (Teile, Modelle, Map) machst du ganz normal in Studio.

## Welche Datei landet wo?

| Ordner im Repo | Wo in Roblox Studio | Wofür |
|---|---|---|
| `src/server` | ServerScriptService > Server | Code für den Server |
| `src/client` | StarterPlayer > StarterPlayerScripts > Client | Code für den Spieler |
| `src/shared` | ReplicatedStorage > Shared | Code, den beide benutzen |
| `src/studio` | ServerStorage > StudioTools | Werkzeuge, die du in Studio über die Command Bar startest |

Die Dateiendung bestimmt die Art des Skripts:

- `Name.server.luau` wird ein **Script**
- `Name.client.luau` wird ein **LocalScript**
- `Name.luau` wird ein **ModuleScript**

## Einrichtung (einmalig)

### 1. Repo auf deinen Computer holen

Am einfachsten mit **GitHub Desktop**:

1. [GitHub Desktop](https://desktop.github.com/) herunterladen und mit deinem GitHub-Konto anmelden.
2. *File > Clone repository* wählen, `literallymern/robloxgame` aussuchen und auf *Clone* klicken.
3. Merk dir den Ordner, in dem das Repo gespeichert wird (z. B. `Dokumente\GitHub\robloxgame`).

### 2. Rojo installieren

Es gibt zwei Wege. Nimm den, der dir lieber ist.

**Weg A: VS Code (am einfachsten)**

1. [Visual Studio Code](https://code.visualstudio.com/) installieren.
2. In VS Code links auf *Extensions* klicken und **Rojo** (von evaera) installieren.
3. Mit *File > Open Folder* den Repo-Ordner öffnen.
4. Unten in der Leiste auf **Rojo** klicken. Die Extension installiert Rojo selbst und bietet an, das Studio-Plugin zu installieren. Dort `default.project.json` auswählen, dann startet Rojo.

Tipp: Installier in VS Code auch die Extension **Luau Language Server**. Dann bekommst du Vorschläge und Fehler direkt beim Tippen.

**Weg B: Rokit (über die Kommandozeile)**

1. [Rokit](https://github.com/rojo-rbx/rokit) installieren (Anleitung auf der Seite).
2. Ein Terminal im Repo-Ordner öffnen und eingeben:
   ```
   rokit install
   ```
   Das installiert genau die Rojo-Version aus `rokit.toml`.
3. Das Studio-Plugin installieren:
   ```
   rojo plugin install
   ```

### 3. Rojo-Plugin in Studio prüfen

Studio neu starten. Oben im Tab **Plugins** sollte jetzt ein **Rojo**-Knopf sein. Falls nicht, das Plugin "Rojo" im Roblox Creator Store suchen und installieren.

## Jeden Tag: Arbeiten mit Rojo

1. **Neueste Änderungen holen:** In GitHub Desktop den Hauptbranch `claude/project-thread-5krwdh` wählen, dann auf *Fetch origin* und *Pull origin* klicken.
2. **Rojo starten:**
   - VS Code: unten auf *Rojo* klicken und `default.project.json` starten, oder
   - Terminal im Repo-Ordner: `rojo serve`
3. **In Studio verbinden:** Deinen Ort (Place) öffnen, im Tab *Plugins* auf **Rojo** klicken, dann auf **Connect**.
4. Fertig. Jetzt erscheinen die Skripte in Studio, und jede Änderung an den Dateien kommt sofort an.

## Testen, ob alles klappt

Nach dem Verbinden auf **Play** drücken und das **Output**-Fenster öffnen (*View > Output*). Dort sollte stehen:

```
[Ro-Nation:Server] Ro-Nation 0.1.0 (Milestone 1) server started (5/5 services).
[Ro-Nation:Client] Ro-Nation 0.1.0 (Milestone 1) client started for DeinName (5/5 controllers).
```

Damit sind die Dienste und Controller gestartet. Oben links erscheinen **Account** und **Weather**; unter Weather lässt sich die Wetterdarstellung für diese Sitzung einstellen.

Einstellungen prüfen: Im Studio-Menü *View > Command Bar* öffnen und eingeben:

```
require(game.ServerStorage.StudioTools.CheckSetup)()
```

Im Output steht dann für jede Einstellung `OK` oder `FIX`.

Landkarte bauen (Meilenstein 2): Vorher den Place sichern (*File > Save to File As…*). Dann im Bearbeitungsmodus (Play gestoppt) in die Command Bar:

```
require(game.ServerStorage.StudioTools.BuildMap).run()
```

Das ersetzt das ganze Gelände und baut Straßen, Brücken, Flughafen, Grenzübergänge, Grundstücke, den Spawn und die Landschaft (Bäume, Büsche, Felsen, Felder, Zäune, Markierungen, Schilder, Laternen, Strommasten) neu. Es ist der vollständige Neubau für einen neuen Place. Danach speichern. Genaue Schritte: [`docs/game/testing/m2-map-checklist.md`](docs/game/testing/m2-map-checklist.md).

## Aktuelles Update: Kagundali-Kreuzung R3/N5

Neue Baumvorlagen, dichterer Unterwuchs, lokale Geländeformen, Kiesbankette,
Entwässerung, überarbeitete Schildkonstruktionen und eine Transportwerkstatt bilden
den ersten zusammenhängend überarbeiteten Bereich. Die Beleuchtung wird sowohl im
gespeicherten Preset als auch im laufenden Wettersystem neutraler eingestellt.

Den Hauptbranch **`claude/project-thread-5krwdh`** holen und über Rojo synchronisieren.
Den Place sichern, Play stoppen, nach dem Sync speichern und Studio neu starten;
anschließend Rojo wieder verbinden. In **View > Command Bar**:

```lua
require(game.ServerStorage.StudioTools.UseCreatorStoreAssets)()
```

Das lädt die offiziellen Roblox-Pakete **Forest Pack** und **City Props Pack**, übernimmt
geeignete Mesh-Modelle ohne Demo-Skripte und aktualisiert den vorhandenen Bereich.
Importierte Bäume, Unterwuchs und Felsen ersetzen dort die bisherigen Vorlagen;
an vorhandenen Laternenstandorten werden passende importierte Modelle eingesetzt.
Die Kamera richtet sich anschließend auf die Kreuzung.
Anschließend speichern und in Play prüfen. Ein vollständiger Kartenneubau ist dafür
nicht erforderlich. **Die visuelle Studio-Abnahme ist noch offen.** Anleitung,
Ursachendiagnose, Testgrenzen und Quellgeometrievorschau:
[`Kagundali R3/N5`](docs/game/07-kagundali-junction.md).

**Aktueller Stand: `kagundali-junction-3`.** Gültige Markierungsabschnitte werden auch bei
einzelnen fehlgeschlagenen Bodenproben gesetzt. Die Kieszufahrt folgt dem Boden in kürzeren
Abschnitten, und die gelben Richtungstafeln werden größer, wobei ihre Texte erhalten bleiben.
Nach einem erfolgreichen Import verwendet auch `UpgradeKagundali()` die gespeicherte
Assetbibliothek ohne erneuten Download. Ohne diese Bibliothek bleiben die eigenen
Baumvorlagen der Ersatz. Details: [Screenshot-Korrekturen](docs/game/08-kagundali-screenshot-fixes.md)
und [Creator-Store-Import mit Quellen und Prüfgrenzen](docs/game/09-creator-store-assets.md).

## Globale Grundlage highland-4

Die vier Referenzbilder sind in dieses Update eingeflossen: weniger kahle Flecken auf sanften Hängen, größere Laub- und Eukalyptuskronen sowie Fundamente, Laternen und Strommasten, die dem gespeicherten Boden folgen. Das vorhandene natürliche Licht bleibt erhalten.

Den Hauptbranch `claude/project-thread-5krwdh` aktualisieren und per Rojo mit Studio synchronisieren. Den Place sichern und Play stoppen. Falls du `BuildMap` vorher schon in der Command Bar geladen hast, nach dem Sync speichern, Studio neu starten und Rojo erneut verbinden, damit kein alter Modulstand im Cache bleibt.

Für das Gelände-, Vegetations- und Infrastruktur-Update in die Command Bar:

```lua
require(game.ServerStorage.StudioTools.BuildMap).upgradeEnvironment()
```

Das erzeugt wiederverwendbare Blattkronen, aktualisiert erkennbares generiertes Gelände einschließlich highland-3 und ersetzt die erzeugten Straßen-, Brücken- und Vegetationsgruppen. Eigene Geländeänderungen und geschützte Bauwerksflächen bleiben bei abweichenden oder unbekannten Geländespalten erhalten. Pflanzen, Brückenfundamente und Straßenobjekte richten sich nach dem tatsächlich gespeicherten Boden. Orte, Grundstücke, Spawn und vorhandene Schilder bleiben erhalten. Den Fortschritt im Output verfolgen und danach speichern. Ein abgebrochener Geländelauf kann bereits einige Abschnitte geändert haben; deshalb vorher eine Place-Sicherung anlegen.

Anschließend den gespeicherten Stand prüfen:

```lua
require(game.ServerStorage.StudioTools.CheckEnvironment)()
```

Die Prüfung zeigt Versionsstände, vorhandene Geometrie, Lichtkonflikte und fehlende Audio-IDs an, ohne etwas zu verändern. Sie ersetzt keine Sicht- oder Leistungskontrolle in Play.

Optional zuerst nur die Geländeänderungen prüfen, ohne etwas zu schreiben:

```lua
require(game.ServerStorage.StudioTools.BuildMap).upgradeEnvironment({ DryRun = true })
```

Weitere Varianten für die Command Bar:

- Nur erzeugte Umgebungsgeometrie und Licht aktualisieren, ohne Geländespalten zu ändern: `require(game.ServerStorage.StudioTools.BuildMap).refreshEnvironment()`
- Nur die Teile neu bauen, Gelände bleibt: `require(game.ServerStorage.StudioTools.BuildMap).run({ Terrain = false })`
- Ohne Bäume, Büsche und Felsen (schneller, zum Testen): `require(game.ServerStorage.StudioTools.BuildMap).run({ Vegetation = false })`
- Weniger Bäume: in `src/shared/Config/MapLayout.luau` bei `Vegetation` den Wert `Density = 1` kleiner machen (z. B. `0.6`) und neu bauen.

Natürliches Licht mit dezentem Morgendunst, fünf dynamische Wetterlagen, Tag/Nacht und automatische Straßenlaternen starten beim Spielen. Regen- und Donner-Audio bleibt stumm, bis die mitgelieferten WAV-Dateien auf Roblox hochgeladen und ihre freigegebenen IDs konfiguriert sind. Anleitung, Geometrievorschau, Testumfang und ausstehende Studio-Prüfungen: [`Environment overhaul`](docs/game/06-environment-overhaul.md).

## Häufige Probleme

- **"Connect" geht nicht:** Läuft `rojo serve` noch? Das Fenster (Terminal oder VS Code) muss offen bleiben.
- **Plugin und Rojo passen nicht zusammen:** Rojo-Plugin in Studio aktualisieren, oder `rojo plugin install` noch einmal ausführen.
- **Meine Änderung in Studio ist weg:** Skripte nur in den Dateien ändern, nicht in Studio (siehe oben).
- **`upgradeEnvironment()` oder `refreshEnvironment()` meldet `attempt to call a nil value`:** Zuerst die neuen Dateien in den lokalen Projektordner übernehmen und Rojo neu starten/verbinden. Falls `BuildMap` in Studio bereits geladen wurde, den Place speichern und Studio neu starten, um den `require()`-Cache zu leeren. Diagnose: [Environment overhaul](docs/game/06-environment-overhaul.md#other-entry-points-and-stale-modules).
- **„Could not switch on animated grass“:** Der bisherige Code versuchte eine von Roblox gesperrte Skript-Zuweisung. In Studio im Explorer **Workspace > Terrain** auswählen, im Fenster **Properties/Eigenschaften** nach **Decoration** suchen, das Häkchen setzen und den Place speichern. Dafür ist kein erneuter Kartenaufbau nötig. Der korrigierte Code lässt diese gespeicherte Einstellung unverändert.
- **Verbindung wird blockiert:** Manchmal fragt Windows beim ersten Start nach der Firewall. Rojo dann erlauben.

## Projekt-Dateien

- `default.project.json` sagt Rojo, welcher Ordner wohin in Studio kommt.
- `rokit.toml` legt die Versionen der Werkzeuge fest (Rojo, selene, StyLua).
- `selene.toml`, `stylua.toml`: Einstellungen für die Prüf- und Formatierwerkzeuge (`selene src`, `stylua src`).
- `tests/map/` enthält Tests für die Karten-Berechnung, die Claude ohne Studio ausführt (du brauchst sie nicht).
- `src/` enthält den ganzen Code: `shared` (Server und Spieler), `server`, `client` und `studio` (Werkzeuge für Studio, landen in ServerStorage > StudioTools).
- `docs/game/` enthält den Bauplan für Ro-Nation (Architektur, Kartenplan, Meilensteine). Start: [`docs/game/MILESTONES.md`](docs/game/MILESTONES.md).
- `discord/` enthält den Discord-Server-Plan und den Wirtschafts-Bot.
