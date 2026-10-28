# Offizielle Creator-Store-Modelle für Kagundali

Stand: 28. Oktober 2026. Die Kartenintegration verwendet zwei kostenlose Modellpakete
des Roblox-Kontos **@Roblox (Creator-ID 1)**:

| Paket | Asset-ID | Verwendung |
|---|---:|---|
| [Forest Pack](https://create.roblox.com/store/asset/6432306802) | 6432306802 | Bäume, Büsche, Farne und Felsen, soweit vollständige Modelle erkannt werden |
| [City Props Pack](https://create.roblox.com/store/asset/6370681139) | 6370681139 | Straßenlaternen an den bestehenden generierten Standorten im Kreuzungsbereich |

Roblox stellt die Pakete in der offiziellen
[Ankündigung zu Endorsed Models](https://devforum.roblox.com/t/new-endorsed-models-in-toolbox/1068480)
vor. Quelle und Asset-ID bleiben als Attribute an übernommenen Vorlagen und platzierten
Modellen gespeichert. Das Repository enthält Importcode und IDs; die importierten
Modelle werden im Place gespeichert.

## Ein Befehl für Import und Anwendung

Nach Pull des Hauptbranches `claude/project-thread-5krwdh`, Rojo-Sync und Studio-Neustart,
bei gestopptem Play und gesichertem Place:

```lua
require(game.ServerStorage.StudioTools.UseCreatorStoreAssets)()
```

Der Befehl prüft Creator-ID und Assettyp der fest eingetragenen Pakete, lädt sie
über `InsertService:LoadAsset()` und baut eine Bibliothek unter
`ServerStorage.RoNationCreatorAssets`. Danach folgt automatisch `UpgradeKagundali()`.
Die Kamera bewegt sich zum Bereich R3/N5. Anschließend den Place speichern.

[InsertService](https://create.roblox.com/docs/reference/engine/classes/InsertService)
unterstützt Roblox-eigene Assets; der Import benötigt deshalb keine allgemeine
Freigabe für beliebige Drittanbieter-Assets. Die tatsächliche Verfügbarkeit der Pakete
für diesen Place muss beim ersten Laden in Studio bestätigt werden.

Für weitere Geometrie-Updates genügt `UpgradeKagundali()`; es verwendet die gespeicherte
Bibliothek ohne Download. Auch die vorhandenen BuildMap-Pfade verwenden sie für den
Kreuzungsbereich. Der Import ersetzt bislang keine Vegetation in den anderen Städten.
Die gelben Wegweiser behalten ihre projektspezifischen Beschriftungen und werden vom
Schilder-Builder verbessert.

## Übernommene Bestandteile

- Auswahl vollständiger Modelle nach Namen, Hierarchie, Maßen und Teilezahl.
  Sammlungsordner und verschachtelte Bestandteile werden nicht doppelt übernommen.
- MeshParts und Texturen einschließlich SurfaceAppearance und DoubleSided bleiben
  erhalten. Demo-Bodenplatten und Partikelgeometrie werden ausgelassen.
- Nur visuelle Kinder vom Typ SurfaceAppearance, SpecialMesh, Texture und Decal bleiben.
  Skripte, Sounds, Demo-Steuerungen und sonstige Kinder werden entfernt, bevor die
  Bibliothek in ServerStorage oder die Geometrie in Workspace eingesetzt wird.
- Bäume werden am Boden ausgerichtet, skaliert und erhalten schmale Stammkollisionen.
  Das Laub blockiert weder Spieler noch Kamera-Raycasts.
- Laternen erhalten einen nach unten gerichteten Lichtgeber mit den vorhandenen
  Attributen für Nachtlicht und Entfernungsabschaltung. Originaltexturen bleiben erhalten.
  Alte generierte Laternen verschwinden nur an erfolgreich ersetzten Standorten;
  eigene anders benannte Objekte und entfernte Laternen bleiben.

Der Import braucht mindestens eine vollständige Baum- und eine Laternenvorlage.
Fehlende optionale Busch-, Farn- oder Felskategorien verwenden die vorhandenen eigenen
Vorlagen. Der Output nennt tatsächlich importierte Vorlagen je Kategorie.
Demo-Animationen werden nicht übernommen; importierte Mesh-Bäume sind hier statisch.
Native Terrain-Grasbewegung und das vorhandene Wetter laufen weiter.

## Fehler und Testgrenzen

Downloadfehler, abweichender Creator/Assettyp oder fehlende vollständige Baum- und
Laternenmodelle erhalten die bisherige Bibliothek. Bei unbekannter Struktur enthält die
Fehlermeldung Modellnamen zur Diagnose. Eigene Inhalte im Bibliotheksordner blockieren
einen Austausch. Ein Geometrie- oder Budgetfehler im anschließenden Updater erhält die
alte regionale Geometrie; der zuvor erfolgreiche Bibliotheksimport bleibt gespeichert.
Der Terrain-Updater kann vor einem späteren Geometriefehler bereits Geländespalten
geschrieben haben. Eine Place-Sicherung bleibt deshalb sinnvoll.

Der direkte Asset-Dateidownload war in der Cloud durch die Netzwerkverbindung blockiert
(Proxy-Tunnel HTTP 403). Hier steht kein Roblox Studio zur Verfügung. **Die echten
Pakethierarchien und ihr sichtbares Ergebnis konnten deshalb noch nicht ausgeführt
oder abgenommen werden.** Die 16 Importregressionen verwenden künstliche Modelle und
prüfen Auswahl, Skriptentfernung, Texturerhalt, Fehlerfälle, Bodenplatzierung,
Nachtlichtattribute und die Integration in den echten Karten-Updater. Sie sind kein
Nachweis für den erfolgreichen Live-Download oder die Darstellung der Originalpakete.

Nach dem ersten Import die drei bisherigen Kreuzungsperspektiven und die Luftansicht
vergleichen: Kronenform und Texturen, zusammenhängende Zufahrt, sichtbare Linien,
lesbare Wegweiser sowie Laternen bei Tag und Nacht. Das 1.600-Teile-Limit ist keine
Dreiecks- oder Bildratenmessung; beides bleibt an den echten Modellen zu prüfen.

Abgeschlossene lokale Prüfungen: vollständige Kartensuite einschließlich Kartenaufbau,
16 Importregressionen, 12 Markierungsregressionen und 86 Umgebungschecks. Alle 70
Luau-Quelldateien kompilieren; StyLua, Git-Whitespace-Prüfung und Rojo-Build bestehen.
