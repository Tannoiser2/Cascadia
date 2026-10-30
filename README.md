# Cascadia — versione digitale (Godot 4)

Versione digitale di **Cascadia** (Randy Flynn, illustrazioni di Beth Sobel, Flatout Games / AEG) con
l'espansione **Landmarks**. Tessere, carte e animali vengono dal modulo di Tabletop Simulator
«Cascadia & Cascadia: Landmarks [Scripted]». Per uso personale, nella ludoteca digitale.

**Gioca nel browser:** https://cascadia.ludoteca-digitale.com/ (ludoteca privata) · https://tannoiser2.github.io/Cascadia/

La pubblicazione non parte da sola: Actions → **Pubblica** → *Run workflow*.

## Avvio
1. Apri Godot 4 (testato su 4.7) → *Importa* → seleziona `project.godot`.
2. Premi **F5**. F11 alterna schermo intero e finestra.

## Cosa c'è
- **Da 1 a 6 giocatori** (5 e 6 con le tessere Landmarks), ognuno persona o IA (facile, normale, difficile);
  solitario con le sue regole e i punteggi di riferimento.
- **Tutte le regole**: offerta di 4 coppie, sovrappopolazione (4 uguali automatica, 3 uguali a scelta),
  segnalini Natura (scelta libera o rimescolamento degli animali), piazzamento e rotazione delle tessere,
  chiavi di volta, 20 turni a testa, corridoi di habitat con i premi di maggioranza da 1 a 6 giocatori.
- **Tutte le 35 carte fauna** (A–D base, E–G Landmarks): a caso A–D, a caso A–G, tutte A, oppure scelte a mano.
- **Landmarks**: 45 tessere e 35 animali in più (anche chiavi di volta a più habitat); modulo facoltativo
  dei segnalini e delle 60 carte Landmark (chiave di volta in più nella preparazione, Landmark sui corridoi
  di 5+ tessere, carte I e J che entrano nel punteggio degli habitat).
- **IA** che valuta ogni coppia e ogni piazzamento: corridoi (anche contro gli avversari, per le
  maggioranze), carte fauna, chiavi di volta, uso dei segnalini Natura e dei Landmark.
- **Gioco online** con gli amici (stanze con codice di 4 lettere, Firebase).
- Regole in italiano dal menu e in partita, diario, punteggio provvisorio e riepilogo finale.

## Vista 2D e 3D
Nel menu (e in partita col pulsante VISTA) si sceglie la vista:
- **2D**: le tessere originali del gioco, ruotate come le hai posate, con i gettoni degli animali.
- **3D**: diorami e miniature fatti con **Meshy**. Le tessere non sono 200 modelli: ci sono solo **cinque
  diorami di habitat** (`assets/models/foresta|montagna|prateria|zona_umida|fiume.glb`). Ogni tessera è
  divisa in sei spicchi, uno per lato; i lati consecutivi dello stesso habitat diventano una sola copia del
  diorama, ritagliata da uno shader (`scripts/ui/terrain_clip.gdshader`) sull'esagono e sull'arco giusto.
  Una tessera foresta/fiume è mezzo diorama di foresta e mezzo di fiume, ruotati come la tessera; una
  chiave di volta è un diorama intero; le tessere Landmarks a tre habitat sono tre spicchi. Gli animali
  (`orso, alce, salmone, falco, volpe`) e i cinque Landmark (`lm_*.glb`) sono miniature Meshy.
  Trascina col sinistro per ruotare, col destro per spostare, rotella per lo zoom.

## Comandi
- Offerta: clic su una coppia. Sotto, i due pulsanti che spendono un segnalino Natura.
- Tessera: clic su uno spazio libero accanto all'ambiente; ruota con clic destro, R/E, Q o i pulsanti;
  conferma con *Conferma*, Invio o un secondo clic sullo stesso spazio.
- Animale: clic su una tessera bordata d'oro, oppure *Rimetti nel sacchetto*.
- A destra: clic su un giocatore per vedere il suo ambiente, clic su una carta per ingrandirla.

## Gioco online
Dal menu, **Gioca online** (anche dalla versione web). Usa lo stesso progetto Firebase degli altri giochi
(Realtime Database), con le stanze sotto `cascadia/rooms`: la sezione generica `$game` di
`firebase/database.rules.json` lo copre, non serve toccare le regole.
- **Chi crea la stanza** sceglie nel menu giocatori e opzioni: i posti su PERSONA diventano i posti per gli
  amici (il primo è il suo). Scrive il nome, preme *Crea una stanza* e comunica il codice.
- **Gli amici** scrivono nome e codice e premono *Entra*. Quando ci sono tutti, chi ha creato la stanza
  preme *Inizia online*: i posti liberi li gioca l'IA.
- Ogni decisione è una mossa numerata nel database; tutti i dispositivi fanno girare lo stesso motore con lo
  stesso seme. Se cade la linea si rientra con lo stesso codice; chi tace per un minuto viene sostituito
  dall'IA finché non rientra.

## Scelte di questa versione (da verificare)
- **Dati delle tessere** (`data/tiles.json`): l'habitat di ogni lato e gli animali di ogni tessera sono
  stati ricavati dai colori delle immagini del modulo TTS e poi controllati e corretti a mano (49 simboli
  per animale sulle 130 tessere, come nella scatola). Le tessere Landmarks a più habitat hanno l'habitat
  lato per lato; due regioni dello stesso habitat sulla stessa tessera contano come una sola.
- **Falco F** «Amici predatori»: la tabella è quella stampata sulla carta del modulo (2, 5, 8, 10, 16, 18, 25).
  **Volpe F**: 4 punti come sulla carta (il regolamento di Landmarks dice 3).
- **Linea di vista dei falchi**: passa sopra tessere e spazi vuoti, la interrompe solo un altro falco
  (per la carta F anche una volpe vicina).
- **Alci D «Cerchi»**: archi di alci consecutivi attorno a uno stesso spazio (pieno o vuoto), da 1 a 6.
- **Carte Landmark**: in partita normale ogni carta la prende un solo giocatore.
- Non ci sono le varianti «Famiglia» e «Intermedia» (le loro carte non sono nel modulo), né le carte promo.

## Struttura
```
data/tiles.json              tessere: habitat per lato (0 = est, senso orario), animali, chiave di volta, Landmarks
scripts/data/cs_data.gd      habitat, animali, testi delle carte fauna e Landmark
scripts/core/engine.gd       motore delle regole (nessuna dipendenza dalla UI)
scripts/core/scoring.gd      punteggio: carte fauna A–G, corridoi e maggioranze, carte Landmark
scripts/core/ai.gd           IA
scripts/net/                 Firebase (REST) e partita online in lockstep
scripts/ui/                  menu, vista 2D (map_view), vista 3D (board3d + terrain_clip.gdshader), partita, regole
tests/score_test.gd          godot --headless --path . -s tests/score_test.gd   (carte punteggio)
tests/sim.gd                 godot --headless --path . -s tests/sim.gd -- 5 3 2 1 ABCDEFG   (partite IA contro IA)
tests/shot.gd                xvfb-run godot --path . -s res://tests/shot.gd -- gioco 8   (screenshot; CS_3D=1, CS_LM=1)
tests/online_play.gd         due dispositivi online sul finto Firebase (tests/firebase_mock.py)
tools/estrai_tts.py          estrae immagini di tessere, carte e gettoni dal modulo TTS
assets/models/               diorami di habitat, animali e Landmark (Meshy, texture webp 1024)
```

Caratteri: Jost (Owen Earl) e Lora (Cyreal), licenza SIL Open Font (`assets/fonts`).
