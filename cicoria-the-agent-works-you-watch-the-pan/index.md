# Cicoria: l'agente lavora, tu guardi la padella


Certi progetti prendono il nome in una riunione. Questo l'ha preso da una padella di cicoria.

Si chiama proprio **cicoria**, e oggi esce la versione 0.0.9. Ti permette di lavorare con più coding agent insieme, nel terminale, e di sapere sempre quale ha bisogno di te.

## Un'idea alle 5:15

L'idea è arrivata senza invito alle 5:15 di domenica 11 ottobre. Nel resto della mattinata è diventata un piano che un agente potesse seguire.

Così ho passato il piano a un agente e sono andato a cucinare la cicoria.

Il nome viene da lì. Una padella dimenticata si fa sentire. Un agente che si ferma per farti una domanda resta lì, in silenzio, ad aspettare.

L'agente lavora e tu guardi la padella. Solo uno dei due ti avvisa quando ha bisogno di te.

cicoria esiste perché ti avvisino tutti e due.

## La risorsa scarsa è l'attenzione

Nella pagina della mia [dark factory](https://simonevellei.com/darkfactory/) racconto come scrivo software oggi: il codice lo scrivono gli agenti, io tengo la specifica e i gate. cicoria è il banco di lavoro da cui tutto questo parte.

Quando deleghi sul serio, il collo di bottiglia diventi tu. In quella pagina l'ho scritto così: delegare davvero significa avere più agenti al lavoro insieme, e la risorsa scarsa diventa la mia attenzione. Quale mi sta aspettando, e cosa hanno cambiato gli altri.

Le tab del terminale non rispondono a questa domanda. Una tab ha lo stesso aspetto sia che l'agente stia lavorando, sia che abbia finito, sia che sia fermo da un pezzo su una richiesta di permesso. Lo scopri solo andando a controllare, una tab alla volta.

L'idea di fondo di cicoria è semplice: non sostituisce i tuoi agenti e non li avvolge in qualcosa di nuovo. Claude Code, Copilot CLI e Codex CLI girano così come sono, ognuno con la sua interfaccia in un vero terminale. cicoria è lo spazio intorno a loro, e ha cura della tua attenzione: ti dice chi ha bisogno di te e cosa è cambiato.

E non è un orchestratore, per scelta. Non fa girare flussi di lavoro tra agenti e non li tiene in moto senza di te, e gli agenti non si contattano mai da soli. Ogni messaggio che un agente riceve l'hai scritto o messo in coda tu. cicoria è un'interfaccia per te.

## Nata dagli attriti

cicoria è stata costruita nel modo in cui va usata: gli agenti a implementare, io a tenere la specifica e la review, dall'idea di quella domenica mattina fino alla v0.0.9, nove giorni dopo. E siccome usavo agenti per costruire uno strumento per usare agenti, ogni spigolo saltava fuori subito.

Più che un changelog, la storia dei commit sembra un diario di quegli spigoli.

La primissima cosa costruita dopo il commit iniziale è stata una coda di messaggi per ogni sessione. L'attrito era evidente: la prossima cosa da dire a un agente arriva spesso mentre è ancora a metà del suo turno. Adesso aspetta in fila, e cicoria la manda quando il turno finisce.

A metà pomeriggio è arrivata la review. Gli agenti fanno commit da soli, quindi un semplice `git diff` è spesso vuoto proprio quando vuoi vedere cosa è successo. Per questo cicoria conta le modifiche dal commit da cui la sessione è partita. Poi serviva indicare righe precise durante la review, e sono arrivate le note sulle righe, rimandate all'agente in un solo messaggio.

Nei giorni dopo sono arrivati Copilot CLI e Codex CLI, WSL2, il branch git nel titolo, e un git worktree tutto suo per la sessione che condividerebbe la cartella con un'altra. Poi le modifiche di una sessione molto attiva hanno cominciato a confondersi tra loro, e adesso un pannello dei commit elenca cosa ha committato la sessione e ti fa guardare un commit alla volta. Mi perdevo un agente in attesa mentre ero in un'altra finestra, e adesso il titolo del terminale nomina le sessioni che ti aspettano.

L'ultima è arrivata dritta dalla cucina. Guardare la padella andava bene, ma per rispondere dovevo comunque tornare alla scrivania. Così la v0.0.9 porta il web cockpit: dal telefono vedi le sessioni che condividi, e rispondi da lì.

Ogni funzione è una piccola risposta a un momento in cui lo strumento si metteva in mezzo.

## Cosa c'è sul banco di lavoro

Prima dell'elenco, un minuto di una sessione vera. Claude Code scrive un piccolo server HTTP in Go mentre un README aspetta in coda, una seconda sessione nel pannello diviso conta le righe di `main.go`, e una nota sul diff chiede alla prima un nuovo endpoint.

<video controls muted playsinline preload="metadata" poster="https://henomis.github.io/cicoria/demo.jpg" style="width:100%;height:auto;">
  <source src="https://henomis.github.io/cicoria/demo.mp4" type="video/mp4">
  <a href="https://henomis.github.io/cicoria/demo.mp4">Guarda la demo di cicoria</a>
</video>

Ecco cosa porta la v0.0.9, una riga per voce. I dettagli sono nella [documentazione](https://henomis.github.io/cicoria/).

- **Sai chi ha bisogno di te senza controllare.** Ogni sessione mostra se sta lavorando, se ti aspetta, se ha finito mentre guardavi altrove, se è inattiva o è terminata, e da quanto.
- **Ci vai dritto.** Un tasto ti porta alla prossima sessione in attesa. Una notifica sul desktop ti avvisa quando una inizia ad aspettare, e il titolo della finestra nomina quelle in attesa, così te lo dice anche una tab in secondo piano.
- **Il tuo agente, così com'è.** Claude Code, Copilot CLI e Codex CLI con l'integrazione completa degli hook, dati agli agenti che cicoria avvia senza toccare le tue impostazioni. Funziona anche qualunque altro agente da riga di comando, con lo stato dedotto dall'attività del terminale.
- **Rivedi cosa ha fatto, commit compresi.** Un pannello delle modifiche e diff a schermo intero, contati dal commit da cui la sessione è partita.
- **Ripercorri i suoi commit.** Un pannello dei commit elenca cosa ha committato la sessione, e restringe le modifiche a un commit alla volta.
- **Una review come per una pull request.** Le note sulle righe tornano all'agente in un solo messaggio, con file e righe citati.
- **Prepara cosa dire dopo.** Una coda per sessione, inviata quando l'agente finisce il turno. Puoi metterla in pausa, riordinarla, modificarla.
- **Chiedi a una sessione da un'altra.** Fai tu la domanda, e la risposta torna da sola alla sessione da cui l'hai fatta (Claude Code e Codex).
- **Due agenti, un repository, alberi separati.** Un git worktree per sessione, proposto quando serve.
- **Due sessioni sotto gli occhi.** Dividi il pannello.
- **Rispondi dalla cucina.** Un tasto avvia il web cockpit e mostra un QR code. Dal telefono vedi le sessioni che condividi, cosa ha detto per ultimo ogni agente e cosa ha cambiato, e puoi rispondere, mettere in coda un messaggio o premere il tasto che una domanda aspetta.
- **Chiudi, e riprendi domani.** Sessioni, note e code vengono ricordate, e le conversazioni ripartono.

Il pannello delle sessioni è fatto così:

```
1 ● auth-refactor
2 ▲ fix-flaky-test
3 ✓ docs-pass
```

Una lavora, una mi aspetta, una ha finito mentre guardavo altrove. La domanda di prima, risolta con un'occhiata.

## Ancora un po' amara

cicoria è giovane, e preferisco dirlo chiaramente. È una release `0.0.x`, nata da nove giorni. La sviluppo su Linux, e gira su WSL2. Ci sono i binari per macOS, ma non li ho provati di persona, quindi ogni segnalazione è preziosa. Gli agenti diversi dai tre supportati hanno uno stato dedotto e una coda da mandare a mano. A Copilot, per ora, un'altra sessione non può fare domande. Il web cockpit parla HTTP semplice, quindi su una rete di cui non ti fidi mettilo dietro una VPN o Tailscale. La roadmap ha ancora parecchie voci aperte. L'ho costruita per il mio modo di lavorare: dimmi dove non si adatta al tuo.

## Provala

```sh
curl -fsSL https://henomis.github.io/cicoria/install.sh | sh
```

Oppure `go install github.com/henomis/cicoria@latest`, se preferisci. All'avvio, nel pannello dell'agente cresce un piccolo fiore di cicoria. Ti lascio il piacere di scoprirlo.

La documentazione è sul [sito di cicoria](https://henomis.github.io/cicoria/), il codice su [GitHub](https://github.com/henomis/cicoria).

Come gli altri miei progetti, cicoria è fatta da una persona sola, a una scrivania in Italia, ed è un inizio. Se la provi, mi piacerebbe sapere quale agente vuoi dopo. Gemini CLI è il primo della roadmap: dimmi quale viene dopo, e aprimi una issue quando qualcosa si rompe.

Adesso, quando un agente ha bisogno di me, cicoria me lo dice. Proprio come la padella. E posso rispondergli senza allontanarmi dai fornelli.

