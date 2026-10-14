# Town Zoning (Transport Fever 3)

Replaces the three estate mods (Residential, Commercial, Industrial Estate Towns). A flag in the town name decides which zones a town keeps.

## Flags

| Name starts with | Keeps |
|---|---|
| `[c]` | commercial |
| `[r]` | residential |
| `[i]` | industrial |
| `[cr]` or `[rc]` | commercial and residential |
| `[ci]` or `[ic]` | commercial and industrial |
| `[ri]` or `[ir]` | residential and industrial |

The order of the letters does not matter.

Old words still work: `[res]`, `#res`, `residen`, `housing`, `wohn…` (residential); `[c]`, `commerc`, `gewerbe` (commercial); `[ind]`, `#ind`, `indus`, `fabrik`, `factory` (industrial).

## Parameter "Removed zones"

- **Split among the kept zones** (default): the space of the removed zones is shared among the kept zones, in proportion to their size. The town stays about as big.
- **Keep as they are**: the kept zones keep their own space, the removed zones are left empty.

## How it works

- `content/mod.script.tl`: the parameter and the tutorial flag are handed to the game script through `baseConfig.locations.town.populationDensity` (1000, plus 1 for split, plus 2 for tutorial on).
- `content/town_zoning.script.tl`: a game script that checks every 5 seconds. It saves the original zones of a town before it converts, and restores them when the flag is removed or changed.
- **Tutorial**: while the tutorial is on, the game script changes nothing. It reads the flag again on every round.

## Notes

- Renaming applies within about 30 seconds. Renaming back restores the original zones.
- Savegames saved without this mod lose the saved originals, like the former estate mods.
- Not yet tested in game.

---

# Town Zoning (Transport Fever 3), Deutsch

Ersetzt die drei Estate-Mods (Residential, Commercial, Industrial Estate Towns). Ein Flag im Stadtnamen bestimmt, welche Zonen eine Stadt behält.

## Flags

| Name beginnt mit | Behält |
|---|---|
| `[c]` | Gewerbe |
| `[r]` | Wohnen |
| `[i]` | Industrie |
| `[cr]` oder `[rc]` | Gewerbe und Wohnen |
| `[ci]` oder `[ic]` | Gewerbe und Industrie |
| `[ri]` oder `[ir]` | Wohnen und Industrie |

Die Reihenfolge der Buchstaben ist egal.

Die alten Wörter funktionieren weiter: `[res]`, `#res`, `residen`, `housing`, `wohn…` (Wohnen); `[c]`, `commerc`, `gewerbe` (Gewerbe); `[ind]`, `#ind`, `indus`, `fabrik`, `factory` (Industrie).

## Parameter „Entfernte Zonen“

- **Aufteilen** (Standard): der Platz der entfernten Zonen wird auf die behaltenen Zonen verteilt, im Verhältnis zu deren Größe. Die Stadt bleibt ungefähr gleich groß.
- **Verbleiben**: die behaltenen Zonen behalten ihren eigenen Platz, die entfernten Zonen bleiben leer.

## Funktionsweise

- `content/mod.script.tl`: Parameter und Tutorial-Flag gehen über `baseConfig.locations.town.populationDensity` an das Game-Script (1000, plus 1 für Aufteilen, plus 2 für Tutorial an).
- `content/town_zoning.script.tl`: ein Game-Script, das alle 5 Sekunden prüft. Es speichert die ursprünglichen Zonen einer Stadt, bevor es umbaut, und stellt sie wieder her, wenn das Flag entfernt oder geändert wird.
- **Tutorial**: solange das Tutorial läuft, ändert das Game-Script nichts. Es liest das Flag bei jeder Runde neu.

## Hinweise

- Die Änderung greift etwa 30 Sekunden nach dem Umbenennen. Zurückbenennen stellt die ursprünglichen Zonen wieder her.
- Spielstände, die ohne diesen Mod gespeichert wurden, verlieren die gespeicherten Originale, wie bei den alten Estate-Mods.
- Noch nicht im Spiel getestet.
