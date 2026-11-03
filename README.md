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

- Pack-Berg mit Rutsche, Laden-Tresen, Halle
- Monster-Baukasten: 4 Körperformen, 4 Elemente, Augen, Maul, Hörner, Flügel, Schwanz, Stacheln, Namen aus Silben
- 5 Seltenheiten plus 1 % Glanz-Chance (zehnfacher Wert)
- Album mit 16 Plätzen: neue Monster kommen automatisch ins Album, jedes gibt +3 % Verkaufswert
- 5 Gadgets: Schnelle Finger, Reißmesser, Größerer Rucksack, Pack-Schaufel, Glückslupe
- Flow-Balken: wer ohne Pause öffnet, reißt bis zu 50 % schneller
- Spielstand wird automatisch gespeichert (`user://save.cfg`)

## Aufbau

- `scripts/main.gd`: Welt, HUD, Laden, Album und der Kern-Loop
- `scripts/player.gd`: Ego-Steuerung
- `scripts/monster_gen.gd`: erzeugt Monster und Seltenheiten
- `scripts/monster_card.gd`: zeichnet die Monster-Karten
