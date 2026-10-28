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

## Current environment update: highland-5

This map-wide rework addresses the six latest screenshots: broader weathered mountain
ridges, slope-based rock exposure, lower woodland cover, mixed meadow grass, embedded
roots, compatible saved Creator Store vegetation across the map, thinner road markings,
less continuous concrete drainage, and balanced daylight beneath trees. The existing
workshop is retained as the same instance. Buildings and interiors are not rebuilt.

Pull the updated project, stop Play and back up the place. Sync Rojo, save, restart
Studio and reconnect Rojo, then run in the edit-mode Command Bar:

```lua
require(game.ServerStorage.StudioTools.BuildMap).upgradeEnvironment()
```

This conservatively patches recognized saved terrain and regenerates environment
geometry across the map, including **kagundali-junction-6** at R3/N5. Custom terrain,
construction footprints, road elevations, signs, city locations and crop fields are
preserved. An optional preview performs no terrain writes:

```lua
require(game.ServerStorage.StudioTools.BuildMap).upgradeEnvironment({ DryRun = true })
```

In **Workspace → Terrain → Properties**, set **GrassLength = 0.25** and keep
**Decoration** enabled, then save. Roblox marks both settings `NotScriptable`;
the code changes where native grass grows, but cannot shorten its blades itself.

Check saved geometry and revisions with:

```lua
require(game.ServerStorage.StudioTools.CheckEnvironment)()
```

The saved official Forest Pack / City Props Pack library is reused where compatible.
No new asset IDs or paid resources are required. `UpgradeKagundali()` updates only
the regional benchmark; **use `upgradeEnvironment()` for the complete rework**.
`BuildMap.run()` is the initial full rebuild and clears generated terrain.

The offline tests and generator profile plots do not establish rendered appearance.
The six locations still require visual comparison in Roblox Studio, plus Play tests
for driving, streaming, weather and performance. See the [implementation, changed systems,
preservation rules and Studio checklist](docs/game/10-terrain-realism-rework.md).

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
