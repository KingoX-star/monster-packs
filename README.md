# Monster Packs (Prototyp)

Ein 3D-Incremental-Spiel aus der Ego-Perspektive: Du reißt Booster-Packs auf, ziehst zufällig gebaute Monster, gibst sie im Laden für Münzen ab und kaufst Gadgets, die das Öffnen immer schneller machen.

## Starten

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) herunterladen (Standard-Version, nicht .NET).
2. Godot öffnen → **Importieren** → die Datei `project.godot` aus diesem Ordner wählen.
3. Oben rechts auf **Play** (F5) klicken.

## Steuerung

| Taste | Aktion |
| --- | --- |
| WASD / Maus | Laufen / Umsehen |
| Shift / Leertaste | Rennen / Springen |
| Linksklick (auf den Pack-Berg schauen) | Pack aufreißen |
| E (am Laden) | Monster abgeben und Laden öffnen |
| Tab | Album ansehen |
| Esc | Maus freigeben |

## Was drin ist

- Waldlichtung mit Himmel, Tannen, Laubbäumen, Wiese und Felsen
- Pack Store als Holzhütte mit Tresen und Regal
- 100.000 Packs liegen von Anfang an als begehbarer Berg bereit und werden beim Öffnen weniger (es kommen keine neuen dazu)
- Packs als Folienbeutel mit gewölbter Mitte und gezackten Rändern
- Monster-Baukasten: 4 Körperformen (Bestie, Schlange, Koloss, Phantom), 4 Elemente, leuchtende Augen, Kiefer, Hörner, Flügel, Schwanz, Stacheln, Krallen, Namen aus Silben
- Karten im dunklen Sammelkarten-Stil mit Element-Symbol, LP und Angriff
- Effekte je Seltenheit: Gewöhnlich ohne, ab Ungewöhnlich Leuchten und Glitzern, ab Episch Holo-Schimmer, Legendär zusätzlich Lichtstrahlen
- 5 Seltenheiten plus 1 % Glanz-Chance (zehnfacher Wert)
- Album mit 16 Plätzen: neue Monster kommen automatisch ins Album, jedes gibt +3 % Verkaufswert
- 5 Gadgets: Schnelle Finger, Reißmesser, Größerer Rucksack, Pack-Schaufel, Glückslupe
- Flow-Balken: wer ohne Pause öffnet, reißt bis zu 50 % schneller
- Spielstand wird automatisch gespeichert (`user://save.cfg`)

## Aufbau

- `scripts/main.gd`: Welt, HUD, Laden, Album und der Kern-Loop
- `scripts/player.gd`: Ego-Steuerung
- `scripts/pack_pile.gd`: der Berg aus 100.000 Packs
- `scripts/pack_mesh.gd`: die Form eines Packs
- `scripts/monster_gen.gd`: erzeugt Monster und Seltenheiten
- `scripts/monster_card.gd`: zeichnet die Monster-Karten
