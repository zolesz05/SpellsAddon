# Moteve Spells

**Moteve Spells** egy World of Warcraft addon a WoW Forever klienshez. A varázskönyv mellett megmutatja, mely képességeket tanulhatod meg most a trénernél, és mi válik elérhetővé későbbi szinteken, tanulási költséggel és összesített árakkal.

**Aktuális verzió: 0.1.1**

[Legfrissebb addon letöltése (ZIP)](downloads/MoteveSpells.zip?raw=true)

A `downloads` mappában csak a legfrissebb telepíthető `MoteveSpells.zip` szerepel. Frissítéskor ugyanaz a letöltési link használható.

## Telepítés

1. Töltsd le és csomagold ki a fenti ZIP-et.
2. Másold a `MoteveSpells` mappát a játék `Interface/AddOns/` könyvtárába.
3. A karakterválasztón engedélyezd a **Moteve Spells** addont, majd lépj be.
4. Nyisd meg a varázskönyvet, alap billentyűkiosztással **P**, és kattints a mellette megjelenő könyvikonra. A lista a `/msp` paranccsal is megnyitható.

```text
Interface/
└── AddOns/
    └── MoteveSpells/
        ├── MoteveSpells.toc
        ├── Spells.lua
        ├── Data.lua
        ├── Fonts/
        └── Textures/
```

A mappanevet tartsd meg: a `MoteveSpells.toc` közvetlenül a `MoteveSpells` mappában legyen. Ha egy új addon nem jelenik meg a listában, indítsd újra a klienst. Meglévő addon frissítése után `/reload` használható. A `WTF` könyvtárat tartsd meg, mert abban vannak a mentett beállítások.

## Funkciók

- Könyvikonos gomb a varázskönyv mellett, arany számmal: hány képesség tanulható most.
- **Most tanulható** lista a karakter szintjének megfelelő, még meg nem tanult trénerképességekkel.
- Képességenkénti tanulási költség és összesített ár.
- Későbbi képességek szintenként csoportosítva, külön összesített árakkal.
- Alapból a következő **10 szint**, opcionálisan a teljes lista **60-as szintig**.
- Piros jelzés, ha egy képességhez előbb a korábbi rangot kell megtanulnod.
- A már megtanult képességek és az elavult alacsonyabb rangok kiszűrése a varázskönyv alapján.
- Frakció- és fajfüggő képességek szűrése; talentből származó képességek magasabb rangjai a meglévő talent alapján.
- Rámutatáskor a játék saját képesség-súgóbuboréka.
- Frissülő lista szintlépéskor és a képességek változásakor.

## Használat

A varázskönyv jobb szélén megjelenő nagy könyvikonra kattintva megnyílik a lista. Ha ott nincs elegendő hely, a panel a másik oldalra kerül.

Elöl a jelenleg tanulható képességek szerepelnek. Alattuk szintenként láthatod, mit érdemes a következő trénerlátogatásokra tervezni, és mennyi pénz szükséges az adott szint képességeihez.

Az addon tájékoztató lista: a képességek megtanulásához továbbra is a megfelelő trénerhez kell menned.

## Parancsok

| Parancs | Művelet |
| --- | --- |
| `/msp` | Lista megnyitása / bezárása |
| `/msp all` | Váltás a következő 10 szint és az összes későbbi szint között, 60-ig |
| `/motevespells` | A `/msp` alternatívája |

A választást a játék a `MoteveSpellsDB` változóban menti.

## Adatok és kompatibilitás

A célkliens **WoW Forever**, a TOC Interface-értéke **16001**.

A képességadatok az eredeti **Classic 1–60** tréneradataiból származnak, a **What's Training?** nyílt forrású adatainak felhasználásával. Ha a Forever módosított egy képesség tanulási szintjén vagy árán, a listában még az eredeti Classic érték szerepelhet. A kizárólag Foreverben létező új képességek nincsenek ebben az adatcsomagban.

A csomag a jelenleg telepített **0.1.1-es verzió** változatlan másolata. Feltöltés előtt a fájlok azonosságát, a Lua-szintaxist és a ZIP tartalmát ellenőriztük. Élő játékbeli tréneradatokat és megjelenítést a feltöltéskor nem teszteltünk újra.

## Források és licencek

- [Teljes addonforrás](MoteveSpells/)
- [Részletes használati leírás](MoteveSpells/README.txt)
- [Képességadatok](MoteveSpells/Data.lua)
- What's Training? adatok: Sveng / fusionpit, [mellékelt MIT-licenc](MoteveSpells/LICENSE-WhatsTraining.txt).
- Marcellus és Barlow betűtípusok: SIL Open Font License, licencfájlok a `MoteveSpells/Fonts/` könyvtárban.

## Hibajelentés

Hibát az [Issues oldalon](https://github.com/zolesz05/SpellsAddon/issues) jelezhetsz. Add meg a kliens és az addon verzióját, a karakter kasztját, faját, frakcióját és szintjét, valamint az érintett képesség nevét és rangját. Hibás ár vagy tanulási szint esetén a trénernél látható érték is segíthet.

## Csomag frissítése

A repository gyökeréből:

```sh
python tools/package_addon.py
```

A csomagoló ellenőrzi a TOC bejegyzéseit és a ZIP tartalmát, lecseréli a `downloads/MoteveSpells.zip` fájlt, és eltávolítja a korábbi verziószámos addoncsomagokat ebből a mappából. A forrást, a ZIP-et és a README-t együtt kell feltölteni.
