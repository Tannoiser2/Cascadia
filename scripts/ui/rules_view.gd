extends Control
## Regole di Cascadia e dell'espansione Landmarks, in breve, in italiano.

const RULES := """[font_size=34][b]Cascadia[/b][/font_size]
[i]Gioco di Randy Flynn, illustrazioni di Beth Sobel (Flatout Games / AEG). Da 1 a 4 giocatori, fino a 6 con le tessere Landmarks.[/i]

[font_size=26][b]Lo scopo[/b][/font_size]
Ognuno costruisce il proprio ambiente del Pacifico nord-occidentale con tessere esagonali di habitat (foresta, montagna, prateria, zona umida, fiume) e lo popola di animali (orso, alce, salmone, falco, volpe). A fine partita si contano i punti delle cinque [b]carte fauna[/b], dei [b]corridoi di habitat[/b] e dei segnalini Natura avanzati.

[font_size=26][b]Preparazione[/b][/font_size]
• Ognuno parte da una tessera iniziale di tre esagoni (una chiave di volta e due tessere doppie).
• Si usano 20 tessere per giocatore più 3 (in solitario come in due): ognuno gioca esattamente [b]20 turni[/b].
• Per ogni animale si scopre una carta punteggio (A per la prima partita; A–D nel gioco base; E–G sono quelle di Landmarks).
• Al centro si formano 4 coppie: una tessera e un animale pescato dal sacchetto.

[font_size=26][b]Il turno[/b][/font_size]
[b]1. Sovrappopolazione.[/b] Se i 4 animali dell'offerta sono uguali si rimescolano da soli. Se 3 sono uguali, chi è di turno può rimetterli nel sacchetto e pescarne altri tre (una volta per turno).
[b]2. Scelta.[/b] Si prende una coppia tessera + animale. Spendendo un [b]segnalino Natura[/b] (pigna) si può invece:
   – prendere una tessera qualunque e un animale qualunque dell'offerta, anche di coppie diverse;
   – rimettere nel sacchetto gli animali che si vuole e pescarne di nuovi (poi si sceglie normalmente).
   Si possono spendere quanti segnalini si vuole.
[b]3. La tessera[/b] va posata accanto ad almeno una tessera del proprio ambiente, ruotata come si preferisce. Non serve che gli habitat combacino, ma solo i lati che combaciano formano i corridoi.
[b]4. L'animale[/b] va su una tessera senza animali che mostri il suo simbolo (ogni tessera ne mostra da 1 a 3), anche quella appena posata. Su una [b]chiave di volta[/b] (tessera con un solo simbolo e la pigna) si guadagna un segnalino Natura. Se non c'è posto, o non si vuole, l'animale torna nel sacchetto.
[b]5. Rifornimento.[/b] Si rimpiazzano tessera e animale presi. Quando non ci sono più tessere da pescare la partita finisce.

[font_size=26][b]Punteggio finale[/b][/font_size]
[b]Fauna:[/b] ogni carta dice come segnano gli animali di quel tipo (gruppi di orsi, linee e formazioni di alci, corse di salmoni, falchi isolati o in linea di vista, volpi circondate da animali…). In gioco basta passare il mouse sulla carta o cliccarla per leggerla.
[b]Corridoi:[/b] per ogni habitat, 1 punto per ogni tessera del [b]corridoio più grande[/b] (tessere collegate da lati con lo stesso habitat). Premi di maggioranza per ogni habitat:
   – in solitario: +2 se il corridoio è di almeno 7 tessere;
   – in due: +2 a chi ha il corridoio più grande (pareggio: +1 a testa);
   – da tre in su: +3 al più grande e +1 al secondo; se due pareggiano per il primo posto +2 a testa e niente al secondo; se pareggiano in tre o più +1 a testa; pari al secondo posto: niente.
[b]Segnalini Natura:[/b] 1 punto ciascuno. In caso di parità vince chi ne ha di più.

[font_size=26][b]Solitario[/b][/font_size]
Dopo ogni turno si scartano la tessera e l'animale più lontani dal mazzo, le altre coppie scorrono e se ne pescano due nuove. Punteggi di riferimento: 60+ buon inizio, 70+ ci stai prendendo la mano, 80+ molto bene, 90+ eccellente, 100+ élite, 110+ ascesa.

[font_size=26][b]Landmarks (espansione)[/b][/font_size]
[b]Tessere Landmarks:[/b] 45 tessere nuove (con 15 chiavi di volta a più habitat) e 35 animali in più: si mescolano alle altre e permettono di giocare in 5 o 6.
[b]Segnalini e carte Landmark[/b] (modulo facoltativo):
• Nella preparazione ognuno, in ordine inverso, sceglie una chiave di volta in più fra quelle scoperte e la aggiunge al proprio ambiente.
• Per ogni habitat si scoprono tante carte Landmark quanti sono i giocatori (2 in solitario).
• Quando una tessera appena posata porta un corridoio a [b]5 o più tessere[/b], si può posare su di essa il Landmark di quell'habitat e prendere una delle sue carte. Un solo Landmark per habitat; la tessera col Landmark non potrà più ospitare animali.
• Le carte A–F contano animali e chiavi di volta, G–H e K i corridoi; I e J non danno punti da sole ma ingrandiscono il corridoio nel punteggio degli habitat (anche per le maggioranze); L vale 3 punti.

[font_size=26][b]Comandi[/b][/font_size]
• Offerta: clic su una coppia per prenderla. I pulsanti sotto l'offerta spendono un segnalino Natura.
• Tessera: clic su uno spazio verde accanto al tuo ambiente, poi ruota con clic destro, R/E (orario), Q (antiorario) o i pulsanti; conferma con Conferma, Invio o un secondo clic sullo stesso spazio.
• Animale: clic su una tessera bordata d'oro.
• Mappa 2D: trascina per spostare, rotella per lo zoom. Vista 3D: trascina col sinistro per ruotare, col destro per spostare, rotella per lo zoom.
• A destra: clic su un giocatore per vedere il suo ambiente; clic su una carta per ingrandirla. «Punti» mostra il punteggio provvisorio.
"""

var main


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.PAPER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.offset_left = 160
	pc.offset_right = -160
	pc.offset_top = 40
	pc.offset_bottom = -120
	add_child(pc)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = RULES
	pc.add_child(rt)
	var b := UI.primary(UI.button("Torna al menu", 300, 60, 24))
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -150
	b.offset_right = 150
	b.offset_top = -96
	b.offset_bottom = -36
	b.pressed.connect(func(): main.show_menu())
	add_child(b)
